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
  Timer? _initialFocusTimer;
  int _frameCount = 0;

  /// Berapa kali OCR mengembalikan teks (walau belum berbentuk plat). Bila
  /// angkanya tetap 0 sementara frame terus bertambah, gambar dari kamera yang
  /// tidak terbaca — bukan pencocokan polanya.
  int _ocrTextHits = 0;
  DateTime? _processingSince;
  Uint8List? _lastCropPreview;
  String? _lastCropSize;
  String? _lastOcrError;
  String _stageLabel = 'Menyiapkan kamera…';
  Offset? _focusIndicator;
  double _zoom = 1.0;
  double _maxZoom = 1.0;
  final List<({String plate, DateTime time})> _recentCandidates = [];

  /// Tampilkan thumbnail kecil hasil crop YOLO di layar untuk diagnosa.
  /// Ubah ke `false` bila sudah tidak diperlukan.
  static const bool _showCropDebugPreview = true;

  /// Skor minimum deteksi YOLO agar 1x bacaan OCR valid langsung dikunci
  /// dan otomatis kembali ke halaman pemanggil.
  static const double _directConfirmYoloScore = 0.60;

  /// Bacaan lebih lama dari ini dibuang agar tidak menahan konsensus.
  static const Duration _consensusWindow = Duration(seconds: 12);

  /// Batas zoom digital yang masih wajar untuk OCR.
  static const double _maxUserZoom = 4.0;

  /// Jeda antar frame pemindaian otomatis. Frame berikutnya dijadwalkan
  /// segera setelah frame sebelumnya selesai diproses. Jeda ini tidak terlalu
  /// rapat supaya autofokus & eksposur kamera punya waktu menstabilkan gambar
  /// (frame yang blur membuat deteksi & OCR selalu gagal) sekaligus memberi
  /// waktu proses OCR menyelesaikan frame sebelumnya.
  static const Duration _frameInterval = Duration(milliseconds: 150);

  /// Jeda singkat sebelum plat hasil konsensus dipakai otomatis, agar
  /// petugas sempat melihat bacaan dan membatalkannya bila keliru.
  static const Duration _autoConfirmDelay = Duration(milliseconds: 550);

  /// Setiap berapa frame autofokus diarahkan ke tengah bila belum ada bacaan.
  static const int _focusEveryFrames = 10;

  /// Area panduan plat (koordinat ternormalisasi pada foto yang diambil).
  ///
  /// Petugas mengarahkan plat ke kotak panduan di layar; hanya area ini yang
  /// dideteksi & di-OCR. Area sempit membuat plat menempati porsi jauh lebih
  /// besar pada input model 416x416 sehingga deteksi & OCR jauh lebih andal
  /// dibanding memindai seluruh frame.
  static const Rect _scanRoi = Rect.fromLTRB(0.02, 0.32, 0.98, 0.68);

  /// Kotak panduan di layar. Selalu berada di dalam [_scanRoi] agar plat yang
  /// terlihat di dalam kotak pasti ikut terpotong saat pemindaian.
  static const double _guideWidthFactor = 0.90;
  static const double _guideHeightFactor = 0.28;

  /// Batas panggilan OCR per frame supaya pemindaian tetap responsif.
  static const int _maxOcrPerFrame = 4;

  static const String _idleHint =
      'Posisikan plat di dalam kotak. Ketuk layar untuk fokus, plat terbaca otomatis.';

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
    // Utamakan resolusi 1080p: plat di gerbang sering hanya menempati sebagian
    // kecil frame, dan teks plat perlu cukup piksel agar ML Kit bisa membacanya.
    // Bila perangkat tidak mendukung, turun bertahap sampai kamera menyala.
    // `high` (720p) didahulukan karena cukup tajam untuk OCR tetapi jauh
    // lebih cepat diambil berulang dibanding foto 1080p/4K; pengambilan foto
    // resolusi penuh tiap 200 ms membuat kamera lambat atau gagal di HP murah.
    const presets = [
      ResolutionPreset.high,
      ResolutionPreset.veryHigh,
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
      // Autofokus awal ke tengah frame setelah kamera benar-benar siap.
      _initialFocusTimer?.cancel();
      _initialFocusTimer = Timer(
        const Duration(milliseconds: 600),
        () => unawaited(_focusCenter(announce: false)),
      );
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
    _setStage('Memindai plat…');
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 80), _captureAndDetect);
  }

  void _setStage(String label) {
    if (!mounted || _stageLabel == label) return;
    setState(() => _stageLabel = label);
  }

  void _scheduleNextScan() {
    if (!_scanning || !mounted) return;
    _scanTimer?.cancel();
    _scanTimer = Timer(_frameInterval, _captureAndDetect);
  }

  void _restartScan() {
    _autoConfirmTimer?.cancel();
    _recentCandidates.clear();
    _frameCount = 0;
    _ocrTextHits = 0;
    _lastCropPreview = null;
    _lastCropSize = null;
    _lastOcrError = null;
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
    if (!_scanning) return;
    // Pengaman: bila satu frame menggantung (mis. takePicture tidak pernah
    // selesai), jangan biarkan pemindaian diam selamanya.
    if (_isProcessing) {
      final since = _processingSince;
      if (since != null &&
          DateTime.now().difference(since) > const Duration(seconds: 8)) {
        _isProcessing = false;
        _processingSince = null;
        if (mounted) {
          setState(() {
            _statusIsError = true;
            _statusText = 'Kamera tidak merespons, pemindaian dimulai ulang…';
          });
        }
      }
    }
    if (!_isCameraReady ||
        _isProcessing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      _scheduleNextScan();
      return;
    }

    _isProcessing = true;
    _processingSince = DateTime.now();
    _frameCount++;
    _setStage('Mengambil frame…');

    // Arahkan autofokus ke tengah secara berkala selama plat belum terkunci,
    // supaya frame tidak terus-menerus blur karena fokus berburu.
    if (_detectedPlate == null && _frameCount % _focusEveryFrames == 0) {
      unawaited(_focusCenter(announce: false));
    }

    try {
      final image = await controller.takePicture();
      ({AnprResult result, double bestYoloScore}) read;
      try {
        read = await _readPlate(image.path, _scanRoi);
      } finally {
        // Semua file sementara (crop & foto asli) dibersihkan di sini.
        try {
          final file = File(image.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      if (!mounted || !_scanning) return;

      final result = read.result;
      if (result.success && result.plate != null && result.plate!.isNotEmpty) {
        if (read.bestYoloScore >= _directConfirmYoloScore) {
          _scanning = false;
          _scanTimer?.cancel();
          unawaited(_fireDetectionHaptic());
          setState(() {
            _detectedPlate = result.plate;
            _confidence = result.confidence;
            _stageLabel = 'Plat terkunci';
            _statusIsError = false;
            _statusText = 'Plat terdeteksi. Melanjutkan otomatis…';
          });
          _autoConfirmTimer?.cancel();
          _autoConfirmTimer = Timer(_autoConfirmDelay, _useDetectedPlate);
          return;
        }

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
            _stageLabel = 'Plat terkunci';
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

        // Baru satu bacaan dengan skor deteksi rendah: tampilkan plat dan
        // tunggu konsensus 2x bacaan.
        setState(() {
          _detectedPlate = result.plate;
          _confidence = result.confidence;
          _stageLabel = 'Mengonfirmasi bacaan…';
          _statusIsError = false;
          _statusText =
              'Membaca: ${result.plate} · tahan kamera sampai terbaca 2x, '
              'atau tekan "Gunakan Plat Ini".';
        });
      } else {
        _setStage('Memindai plat…');
        // Tampilkan apa yang sebenarnya dibaca OCR supaya petugas tahu apakah
        // kamera terlalu jauh/blur atau teksnya memang tidak menyerupai plat.
        final raw = _ocrSnippet(result.rawText ?? '');
        final issues = <String>[];
        if (PlateDetector.instance.isUnavailable) {
          issues.add('model deteksi gagal dimuat');
        }
        if (result.error != null) issues.add('OCR error');
        final suffix = issues.isEmpty ? '' : ' (${issues.join(', ')})';
        setState(() {
          _statusIsError = false;
          _statusText = raw.isEmpty
              ? 'Belum ada teks terbaca$suffix · dekatkan kamera, ketuk layar '
                    'untuk fokus, atau tambah zoom.'
              : 'Teks terbaca: "$raw"$suffix · belum cocok dengan pola plat.';
        });
      }
    } catch (e) {
      // Frame gagal diambil/diproses: tampilkan penyebabnya, jangan diam saja,
      // agar kamera yang macet (mis. takePicture ditolak perangkat) terlihat.
      if (mounted && _scanning) {
        setState(() {
          _statusIsError = true;
          _statusText = 'Gagal memproses frame: ${_ocrSnippet(e.toString())}';
        });
      }
    } finally {
      _isProcessing = false;
      _processingSince = null;
      if (_scanning) {
        _scheduleNextScan();
      }
    }
  }

  /// Baris diagnosa kecil di bawah status: memastikan model benar-benar
  /// termuat, memperlihatkan skor deteksi tertinggi, dan jumlah frame yang
  /// sudah diproses. Bila frame terus bertambah tetapi skor 0.00 sementara
  /// plat jelas terlihat, berarti model tidak mengenali gambar (bukan kamera
  /// macet).
  String _diagnostics() {
    final detector = PlateDetector.instance;
    if (detector.isUnavailable) {
      final reason = detector.lastLoadError ?? 'tanpa pesan';
      return 'Model: GAGAL · ${_ocrSnippet(reason)}';
    }
    final cropInfo = _lastCropSize == null ? '' : ' · crop $_lastCropSize';
    final ocrErr = _lastOcrError == null ? '' : ' · err $_lastOcrError';
    return 'Model: OK · kotak '
        '${detector.lastRawCount} · skor '
        '${detector.lastBestScore.toStringAsFixed(2)}$cropInfo · '
        'OCR $_ocrTextHits · frame $_frameCount$ocrErr';
  }

  static String _ocrSnippet(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 42) return compact;
    return '${compact.substring(0, 42)}…';
  }

  /// Baca plat dari satu frame di dalam area panduan [roi].
  ///
  /// Urutan upaya (dibatasi [_maxOcrPerFrame] panggilan agar tetap responsif):
  /// 1. kotak hasil model detektor pada area panduan (normal & inversi),
  /// 2. OCR langsung area panduan yang diperbesar,
  /// 3. foto asli dari kamera sebagai cadangan bila semua crop PNG gagal.
  Future<({AnprResult result, double bestYoloScore})> _readPlate(
    String imagePath,
    Rect roi,
  ) async {
    var ocrCalls = 0;
    var bestYoloScore = 0.0;
    final seenText = <String>[];
    String? lastError;

    Future<AnprResult?> tryOcr(String path) async {
      if (ocrCalls >= _maxOcrPerFrame) return null;
      ocrCalls++;
      final result = await AnprService.detectFromImageFile(path);
      _noteOcrText(result);
      if (result.error != null) lastError = result.error;
      final raw = result.rawText?.trim() ?? '';
      if (raw.isNotEmpty) seenText.add(raw);
      return result.success ? result : null;
    }

    Future<AnprResult?> tryInverted(String path) async {
      if (ocrCalls >= _maxOcrPerFrame) return null;
      final inverted = await PlateDetector.instance.invertToPng(path);
      if (inverted == null) return null;
      try {
        return await tryOcr(inverted);
      } finally {
        await _deleteQuietly(inverted);
      }
    }

    final decodedImage = await PlateDetector.instance.decodeFile(imagePath);
    try {
      // 1) Kotak dari model detektor. Ambang 0.35 karena model ini juga memberi
      //    skor ~0.3 pada tulisan/logo yang bukan plat.
      _setStage('Mendeteksi posisi plat…');
      final crops = decodedImage == null
          ? const <PlateCropResult>[]
          : await PlateDetector.instance.detectAndCropImage(
              decodedImage,
              minScore: 0.35,
              maxCrops: 1,
              roi: roi,
            );
      if (crops.isNotEmpty) {
        final first = crops.first;
        bestYoloScore = first.score;
        _lastCropPreview = first.previewBytes;
        _lastCropSize = '${first.width}x${first.height}';
        _setStage('Plat terdeteksi, membaca huruf…');
      } else {
        _setStage('Memindai area kotak…');
      }
      try {
        for (final crop in crops) {
          final hit = await tryOcr(crop.path);
          if (hit != null) {
            _lastOcrError = null;
            return (result: hit, bestYoloScore: bestYoloScore);
          }
          final invertedHit = await tryInverted(crop.path);
          if (invertedHit != null) {
            _lastOcrError = null;
            return (result: invertedHit, bestYoloScore: bestYoloScore);
          }
        }
      } finally {
        for (final crop in crops) {
          await _deleteQuietly(crop.path);
        }
      }

      // 2) OCR area panduan (diperbesar), memakai image yang sudah di-decode.
      final roiPath = decodedImage == null
          ? null
          : await PlateDetector.instance.cropRegionFromImage(
              decodedImage,
              left: roi.left,
              top: roi.top,
              right: roi.right,
              bottom: roi.bottom,
            );
      if (roiPath != null) {
        try {
          final hit = await tryOcr(roiPath);
          if (hit != null) {
            _lastOcrError = null;
            return (result: hit, bestYoloScore: bestYoloScore);
          }
          if (_ocrTextHits == 0 || _frameCount.isEven) {
            final invertedHit = await tryInverted(roiPath);
            if (invertedHit != null) {
              _lastOcrError = null;
              return (result: invertedHit, bestYoloScore: bestYoloScore);
            }
          }
        } finally {
          await _deleteQuietly(roiPath);
        }
      }
    } finally {
      decodedImage?.dispose();
    }

    // 3) Cadangan: JPEG asli dari kamera bila semua PNG tidak menghasilkan teks.
    if (seenText.isEmpty) {
      final rawHit = await AnprService.detectFromImageFile(imagePath);
      _noteOcrText(rawHit);
      if (rawHit.error != null) lastError = rawHit.error;
      final raw = rawHit.rawText?.trim() ?? '';
      if (raw.isNotEmpty) seenText.add(raw);
      if (rawHit.success) {
        _lastOcrError = null;
        return (result: rawHit, bestYoloScore: bestYoloScore);
      }
    }

    _lastOcrError = lastError;
    return (
      result: AnprResult(
        success: false,
        rawText: seenText.isEmpty ? null : seenText.join(' '),
        error: lastError,
      ),
      bestYoloScore: bestYoloScore,
    );
  }

  void _noteOcrText(AnprResult result) {
    final text = result.rawText?.trim() ?? '';
    if (text.isNotEmpty) _ocrTextHits++;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Arahkan autofokus ke tengah frame (tempat plat biasanya dibidik).
  Future<void> _focusCenter({bool announce = true}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(const Offset(0.5, 0.5));
      if (!mounted || !announce) return;
      setState(() {
        _statusIsError = false;
        _statusText = 'Fokus ke tengah · arahkan tepat ke plat nomor.';
      });
    } catch (_) {
      // Perangkat yang tidak mendukung titik fokus tetap memakai autofokus.
    }
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
    _initialFocusTimer?.cancel();
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
                  if (_showCropDebugPreview && _lastCropPreview != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 148,
                          height: 54,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppTheme.navyDark.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppTheme.amberGold.withValues(alpha: 0.85),
                              width: 1.5,
                            ),
                          ),
                          child: Image.memory(
                            _lastCropPreview!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
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
                        const SizedBox(height: 2),
                        Text(
                          _diagnostics(),
                          textAlign: TextAlign.center,
                          style: texts.labelSmall?.copyWith(
                            color: AppTheme.surfaceWhite.withValues(alpha: 0.5),
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
                IgnorePointer(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: _guideWidthFactor,
                      heightFactor: _guideHeightFactor,
                      child: _ScanGuideBox(
                        active: _detectedPlate != null,
                        isScanning: _scanning,
                        stageLabel: _stageLabel,
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

class _ScanGuideBox extends StatefulWidget {
  const _ScanGuideBox({
    required this.active,
    required this.isScanning,
    required this.stageLabel,
  });

  final bool active;
  final bool isScanning;
  final String stageLabel;

  @override
  State<_ScanGuideBox> createState() => _ScanGuideBoxState();
}

class _ScanGuideBoxState extends State<_ScanGuideBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isScanning && !widget.active) {
      _scanAnim.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ScanGuideBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.isScanning && !widget.active;
    if (shouldAnimate && !_scanAnim.isAnimating) {
      _scanAnim.repeat(reverse: true);
    } else if (!shouldAnimate && _scanAnim.isAnimating) {
      _scanAnim.stop();
    }
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final color = widget.active ? context.semantic.success : AppTheme.amberGold;
    final side = BorderSide(color: color.withValues(alpha: 0.9), width: 3);

    Widget corner({
      double? top,
      double? bottom,
      double? left,
      double? right,
      required Border border,
    }) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: SizedBox(
          width: 30,
          height: 30,
          child: DecoratedBox(decoration: BoxDecoration(border: border)),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.22)),
              color: color.withValues(alpha: 0.04),
            ),
          ),
        ),
        if (widget.isScanning && !widget.active)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedBuilder(
                animation: _scanAnim,
                builder: (context, child) => Align(
                  alignment: Alignment(0, -0.85 + _scanAnim.value * 1.7),
                  child: child,
                ),
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.0),
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        corner(
          top: 0,
          left: 0,
          border: Border(top: side, left: side),
        ),
        corner(
          top: 0,
          right: 0,
          border: Border(top: side, right: side),
        ),
        corner(
          bottom: 0,
          left: 0,
          border: Border(bottom: side, left: side),
        ),
        corner(
          bottom: 0,
          right: 0,
          border: Border(bottom: side, right: side),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navyDark.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isScanning && !widget.active) ...[
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.active ? 'Plat terkunci' : widget.stageLabel,
                      style: texts.labelSmall?.copyWith(
                        color: AppTheme.surfaceWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
