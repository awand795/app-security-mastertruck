import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/anpr_service.dart';
import '../services/plate_detector.dart';

/// Pemindai plat nomor layar penuh dengan latar gelap.
///
/// Kamera tampil penuh (menutupi seluruh layar tanpa bingkai/garis pindai) dan
/// memindai berulang tanpa henti: setiap frame diambil, area plat dideteksi,
/// lalu di-OCR. Begitu dua bacaan sama (atau tiga bacaan mirip) terkumpul,
/// plat ditampilkan sebentar dan otomatis dikirim ke pemanggil, sehingga
/// petugas tidak perlu menekan tombol jepret. Tersedia zoom untuk plat yang
/// jauh serta senter untuk kondisi gelap. Semua proses OCR berjalan offline di
/// perangkat.
class AnprScannerSheet extends StatefulWidget {
  const AnprScannerSheet({
    super.key,
    required this.onPlateDetected,
    this.autoStartCamera = true,
  });

  final ValueChanged<String> onPlateDetected;

  /// Dimatikan pada preview/test agar kamera perangkat tidak diakses.
  final bool autoStartCamera;

  @override
  State<AnprScannerSheet> createState() => _AnprScannerSheetState();
}

class _AnprScannerSheetState extends State<AnprScannerSheet> {
  CameraController? _controller;

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _scanning = false;
  bool _isTorchOn = false;
  bool _torchAvailable = true;
  String? _detectedPlate;
  double _confidence = 0;
  String? _statusText;
  bool _statusIsError = false;
  Timer? _scanTimer;
  Timer? _autoConfirmTimer;
  Timer? _focusIndicatorTimer;
  Offset? _focusIndicator;
  double _zoom = 1.0;
  double _maxZoom = 1.0;
  final List<({String plate, DateTime time})> _recentCandidates = [];

  /// Bacaan lebih lama dari ini dibuang agar tidak menahan konsensus.
  static const Duration _consensusWindow = Duration(seconds: 12);

  /// Batas zoom digital yang masih wajar untuk OCR.
  static const double _maxUserZoom = 4.0;

  /// Jeda kecil antar frame pemindaian otomatis. Frame berikutnya dijadwalkan
  /// segera setelah frame sebelumnya selesai diproses agar pembacaan cepat,
  /// tanpa membuat pratinjau kamera tersendat.
  static const Duration _frameInterval = Duration(milliseconds: 120);

  /// Jeda singkat sebelum plat hasil konsensus dipakai otomatis, agar
  /// petugas sempat melihat bacaan dan membatalkannya bila keliru.
  static const Duration _autoConfirmDelay = Duration(milliseconds: 1000);

  static const String _idleHint =
      'Arahkan ke plat nomor. Ketuk layar untuk fokus, plat terbaca otomatis.';

  @override
  void initState() {
    super.initState();
    // Muat model detektor di awal agar frame pertama sudah bisa dideteksi.
    unawaited(PlateDetector.instance.ensureLoaded());
    if (widget.autoStartCamera) {
      _initCamera();
    } else {
      _statusText = _idleHint;
    }
  }

  Future<CameraController?> _createController(CameraDescription camera) async {
    // Resolusi 720p cukup untuk plat di gerbang dan jauh lebih cepat dijepret
    // daripada veryHigh (foto besar membuat OCR lambat & pratinjau tersendat).
    // Bila perangkat tidak mendukung, turun bertahap sampai kamera menyala.
    const presets = [
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.low,
    ];
    for (final preset in presets) {
      final controller = CameraController(
        camera,
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await controller.initialize();
        return controller;
      } catch (_) {
        await controller.dispose();
      }
    }
    return null;
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _statusText = 'Kamera tidak ditemukan. Gunakan input manual.';
          _statusIsError = true;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = await _createController(backCamera);
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      if (controller == null) {
        setState(() {
          _statusText =
              'Kamera tidak dapat digunakan. Ketik nomor polisi secara manual.';
          _statusIsError = true;
        });
        return;
      }

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        _maxZoom = 1.0;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraReady = true;
        _statusIsError = false;
        _statusText = _idleHint;
      });

      _startScanning();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusText =
            'Kamera tidak dapat digunakan. Ketik nomor polisi secara manual.';
        _statusIsError = true;
      });
    }
  }

  void _startScanning() {
    _scanning = true;
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 120), _captureAndDetect);
  }

  void _scheduleNextScan() {
    if (!_scanning || !mounted) return;
    _scanTimer?.cancel();
    _scanTimer = Timer(_frameInterval, _captureAndDetect);
  }

  void _restartScan() {
    _autoConfirmTimer?.cancel();
    _recentCandidates.clear();
    setState(() {
      _detectedPlate = null;
      _confidence = 0;
      _statusIsError = false;
      _statusText = _idleHint;
    });
    _startScanning();
  }

  void _useDetectedPlate() {
    _autoConfirmTimer?.cancel();
    final plate = _detectedPlate;
    if (!mounted || plate == null) return;

    _scanning = false;
    _scanTimer?.cancel();
    // Tutup dialog lebih dulu agar callback pemanggil tidak bertabrakan
    // dengan rute pemindai yang masih terbuka.
    Navigator.of(context).pop();
    widget.onPlateDetected(plate);
  }

  /// Ambil satu frame, deteksi area plat, lalu OCR. Berjalan terus-menerus
  /// selama pemindaian aktif.
  Future<void> _captureAndDetect() async {
    final controller = _controller;
    if (!_scanning || _detectedPlate != null) return;
    if (!_isCameraReady ||
        _isProcessing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      _scheduleNextScan();
      return;
    }

    _isProcessing = true;

    try {
      final image = await controller.takePicture();
      AnprResult result;
      try {
        result = await _readPlate(image.path);
      } finally {
        // Semua file sementara (crop & foto asli) dibersihkan di sini.
        try {
          final file = File(image.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      if (!mounted || !_scanning) return;

      if (result.success && result.plate != null && result.plate!.isNotEmpty) {
        final now = DateTime.now();
        _recentCandidates.removeWhere(
          (candidate) => now.difference(candidate.time) > _consensusWindow,
        );
        _recentCandidates.add((plate: result.plate!, time: now));

        final consensus = AnprService.consensusPlate(
          _recentCandidates.map((candidate) => candidate.plate).toList(),
        );

        if (consensus != null) {
          _scanning = false;
          _scanTimer?.cancel();
          unawaited(_fireDetectionHaptic());
          setState(() {
            _detectedPlate = consensus.plate;
            _confidence = consensus.confidence;
            _statusIsError = false;
            _statusText = consensus.exactMatch
                ? 'Plat sama terbaca ${consensus.votes}x. Melanjutkan otomatis…'
                : 'Plat terkonfirmasi dari ${consensus.votes} bacaan. '
                      'Melanjutkan otomatis…';
          });
          _autoConfirmTimer?.cancel();
          _autoConfirmTimer = Timer(_autoConfirmDelay, _useDetectedPlate);
          return;
        }

        setState(() {
          _statusIsError = false;
          _statusText =
              'Membaca: ${result.plate} · tahan kamera stabil '
              '(${_recentCandidates.length}/2)';
        });
      } else {
        // Tampilkan apa yang sebenarnya dibaca OCR supaya petugas tahu apakah
        // kamera terlalu jauh/blur atau teksnya memang tidak menyerupai plat.
        final raw = _ocrSnippet(result.rawText ?? '');
        setState(() {
          _statusIsError = false;
          _statusText = raw.isEmpty
              ? 'Belum ada teks terbaca · dekatkan kamera, ketuk layar untuk '
                    'fokus, atau tambah zoom.'
              : 'Teks terbaca: "$raw" · belum cocok dengan pola plat.';
        });
      }
    } catch (_) {
      // Frame gagal diproses diabaikan agar pemindaian tetap berjalan.
    } finally {
      _isProcessing = false;
      if (_scanning && _detectedPlate == null) {
        _scheduleNextScan();
      }
    }
  }

  static String _ocrSnippet(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 42) return compact;
    return '${compact.substring(0, 42)}…';
  }

  /// Baca plat dari satu frame dengan tiga tingkat upaya: kotak hasil
  /// detektor (paling tajam untuk plat kecil/jauh), area tengah frame yang
  /// diperbesar, lalu frame penuh sebagai upaya terakhir.
  Future<AnprResult> _readPlate(String imagePath) async {
    final crop = await PlateDetector.instance.detectAndCrop(imagePath);
    // Kotak detektor hanya dipakai bila model cukup yakin; bila ragu, crop
    // yang salah justru membuang satu kesempatan OCR.
    if (crop != null) {
      if (crop.score >= 0.5) {
        final result = await AnprService.detectFromImageFile(crop.path);
        if (result.success) return result;
      } else {
        try {
          final file = File(crop.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }

    final centerPath = await PlateDetector.instance.cropCenterRegion(imagePath);
    if (centerPath != null) {
      final result = await AnprService.detectFromImageFile(centerPath);
      if (result.success) return result;
    }

    return AnprService.detectFromImageFile(imagePath);
  }

  /// Fokus ke titik yang diketuk. Layar menampilkan pratinjau penuh
  /// (BoxFit.cover), jadi titik ketuk dipetakan dulu ke koordinat pratinjau
  /// kamera yang utuh sebelum dinormalisasi ke rentang 0..1.
  Future<void> _focusAt(
    Offset localPosition,
    BoxConstraints constraints,
    double previewWidth,
    double previewHeight,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (previewWidth <= 0 || previewHeight <= 0) return;

    final scale = math.max(
      constraints.maxWidth / previewWidth,
      constraints.maxHeight / previewHeight,
    );
    final left = (constraints.maxWidth - previewWidth * scale) / 2;
    final top = (constraints.maxHeight - previewHeight * scale) / 2;
    final x = ((localPosition.dx - left) / scale / previewWidth).clamp(
      0.0,
      1.0,
    );
    final y = ((localPosition.dy - top) / scale / previewHeight).clamp(
      0.0,
      1.0,
    );

    setState(() => _focusIndicator = localPosition);
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _focusIndicator = null);
    });

    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(Offset(x, y));
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _statusText = 'Fokus di area yang diketuk · plat terbaca otomatis.';
      });
    } catch (_) {
      // Perangkat yang tidak mendukung titik fokus tetap memakai autofokus.
    }
  }

  Future<void> _applyZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final maxZoom = math.min(_maxZoom, _maxUserZoom);
    final next = value.clamp(1.0, maxZoom <= 1.0 ? 1.0 : maxZoom);
    try {
      await controller.setZoomLevel(next);
      if (!mounted) return;
      setState(() {
        _zoom = next;
        _statusIsError = false;
        _statusText = next <= 1.0
            ? _idleHint
            : 'Zoom ${next.toStringAsFixed(1)}x · arahkan tepat ke plat nomor.';
      });
    } catch (_) {
      // Perangkat tanpa dukungan zoom diabaikan.
    }
  }

  Future<void> _fireDetectionHaptic() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Perangkat tanpa dukungan haptic diabaikan.
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _statusText = 'Senter belum siap.';
        _statusIsError = true;
      });
      return;
    }

    try {
      final nextValue = !_isTorchOn;
      await controller.setFlashMode(
        nextValue ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() {
        _isTorchOn = nextValue;
        _statusIsError = false;
        _statusText = nextValue ? 'Senter aktif.' : 'Senter dimatikan.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTorchOn = false;
        _torchAvailable = false;
        _statusIsError = true;
        _statusText = 'Senter tidak tersedia di perangkat ini.';
      });
    }
  }

  @override
  void dispose() {
    _scanning = false;
    _scanTimer?.cancel();
    _autoConfirmTimer?.cancel();
    _focusIndicatorTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Dialog.fullscreen(
      backgroundColor: AppTheme.navyDark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPreview(texts),
            // Gradien tipis hanya agar teks & tombol tetap terbaca di atas
            // gambar kamera; tidak menutupi area pemindaian.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.navyDark.withValues(alpha: 0.72),
                      AppTheme.navyDark.withValues(alpha: 0),
                      AppTheme.navyDark.withValues(alpha: 0.82),
                    ],
                    stops: const [0, 0.3, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.amberGold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.document_scanner_rounded,
                            color: AppTheme.amberGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Pemindai Plat Otomatis',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: texts.titleMedium?.copyWith(
                                  color: AppTheme.surfaceWhite,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Plat terbaca tanpa perlu menekan tombol',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: texts.bodySmall?.copyWith(
                                  color: AppTheme.surfaceWhite.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isCameraReady && _torchAvailable)
                          _TorchButton(
                            isOn: _isTorchOn,
                            onPressed: _toggleTorch,
                          ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.surfaceWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        if (_detectedPlate != null)
                          _DetectionBanner(
                            plate: _detectedPlate!,
                            confidence: _confidence,
                          )
                        else if (_isCameraReady && _maxZoom > 1.01)
                          _ZoomControl(
                            zoom: _zoom,
                            maxZoom: math.min(_maxZoom, _maxUserZoom),
                            onChanged: _applyZoom,
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _statusText ?? _idleHint,
                          textAlign: TextAlign.center,
                          style: texts.bodySmall?.copyWith(
                            color: _statusIsError
                                ? AppTheme.errorLight
                                : AppTheme.surfaceWhite.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _detectedPlate != null
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 52,
                                          child: OutlinedButton.icon(
                                            onPressed: _restartScan,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              color: AppTheme.amberGold,
                                            ),
                                            label: Text(
                                              'Scan Ulang',
                                              style: texts.labelLarge?.copyWith(
                                                color: AppTheme.amberGold,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: AppTheme.amberGold
                                                    .withValues(alpha: 0.72),
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.md,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 52,
                                          child: ElevatedButton.icon(
                                            onPressed: _useDetectedPlate,
                                            icon: const Icon(
                                              Icons.check_circle_rounded,
                                            ),
                                            label: const Text(
                                              'Gunakan Plat Ini',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  context.semantic.success,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.md,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : SizedBox(
                                    height: 52,
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.keyboard_alt_outlined,
                                        color: AppTheme.amberGold,
                                      ),
                                      label: Text(
                                        'Ketik Manual',
                                        style: texts.labelLarge?.copyWith(
                                          color: AppTheme.amberGold,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.amberGold,
                                        side: BorderSide(
                                          color: AppTheme.amberGold.withValues(
                                            alpha: 0.72,
                                          ),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.md,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kamera tampil penuh menutupi layar (BoxFit.cover) tanpa bingkai hitam
  /// maupun distorsi gambar.
  Widget _buildCameraPreview(TextTheme texts) {
    final controller = _controller;
    if (_isCameraReady && controller != null) {
      final previewSize = controller.value.previewSize;
      return LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait =
              MediaQuery.orientationOf(context) == Orientation.portrait;
          final width = previewSize == null
              ? constraints.maxWidth
              : (isPortrait ? previewSize.height : previewSize.width);
          final height = previewSize == null
              ? constraints.maxHeight
              : (isPortrait ? previewSize.width : previewSize.height);

          final previewWidth = width <= 0 ? constraints.maxWidth : width;
          final previewHeight = height <= 0 ? constraints.maxHeight : height;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _focusAt(
              details.localPosition,
              constraints,
              previewWidth,
              previewHeight,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
                if (_focusIndicator != null)
                  Positioned(
                    left: _focusIndicator!.dx - 30,
                    top: _focusIndicator!.dy - 30,
                    child: const IgnorePointer(child: _FocusIndicator()),
                  ),
              ],
            ),
          );
        },
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navyDark, AppTheme.corporateNavy],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_back_outlined,
              size: 52,
              color: AppTheme.surfaceWhite.withValues(alpha: 0.24),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Kamera belum aktif',
              style: texts.bodySmall?.copyWith(
                color: AppTheme.surfaceWhite.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.4, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.amberGold, width: 2),
          color: AppTheme.amberGold.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.zoom,
    required this.maxZoom,
    required this.onChanged,
  });

  final double zoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final canZoomOut = zoom > 1.0;
    final canZoomIn = zoom < maxZoom;
    final disabled = AppTheme.surfaceWhite.withValues(alpha: 0.32);

    return Material(
      color: AppTheme.navyDark.withValues(alpha: 0.68),
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Perkecil zoom',
              visualDensity: VisualDensity.compact,
              onPressed: canZoomOut ? () => onChanged(zoom - 0.5) : null,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                size: 22,
                color: canZoomOut ? AppTheme.surfaceWhite : disabled,
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${zoom.toStringAsFixed(1)}x',
                textAlign: TextAlign.center,
                style: texts.labelMedium?.copyWith(
                  color: AppTheme.surfaceWhite,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Perbesar zoom',
              visualDensity: VisualDensity.compact,
              onPressed: canZoomIn ? () => onChanged(zoom + 0.5) : null,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: 22,
                color: canZoomIn ? AppTheme.surfaceWhite : disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.navyDark.withValues(alpha: 0.68),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isOn ? 'Matikan senter' : 'Nyalakan senter',
        onPressed: onPressed,
        icon: Icon(
          isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          color: isOn ? AppTheme.amberGold : AppTheme.surfaceWhite,
        ),
      ),
    );
  }
}

class _DetectionBanner extends StatelessWidget {
  const _DetectionBanner({required this.plate, required this.confidence});

  final String plate;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.successGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.navyDark,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Plat terdeteksi',
                  style: texts.bodySmall?.copyWith(
                    color: AppTheme.navyDark.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  plate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.plateStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ).copyWith(color: AppTheme.navyDark),
                ),
                Text(
                  '${(confidence * 100).round()}% keyakinan',
                  style: texts.bodySmall?.copyWith(
                    color: AppTheme.navyDark.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
