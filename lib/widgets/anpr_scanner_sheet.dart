import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/anpr_service.dart';

/// Pemindai plat nomor layar penuh dengan latar gelap.
///
/// Kamera memindai otomatis setiap 450 ms. Saat plat terdeteksi, perangkat
/// memberi haptic lalu hasil dikirim ke pemanggil. Tombol "Ketik Manual"
/// menutup pemindai tanpa mengubah isian.
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

class _AnprScannerSheetState extends State<AnprScannerSheet>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  late final AnimationController _scanLineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _torchAvailable = true;
  String? _detectedPlate;
  double _confidence = 0;
  String? _statusText;
  bool _statusIsError = false;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartCamera) {
      _initCamera();
    } else {
      _statusText = 'Arahkan kamera ke plat nomor kendaraan.';
    }
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
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraReady = true;
        _statusIsError = false;
        _statusText = 'Arahkan kamera ke plat nomor kendaraan.';
      });

      _scanTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
        _captureAndDetect();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusText =
            'Kamera tidak dapat digunakan. Ketik nomor polisi secara manual.';
        _statusIsError = true;
      });
    }
  }

  Future<void> _captureAndDetect() async {
    final controller = _controller;
    if (!_isCameraReady ||
        _isProcessing ||
        controller == null ||
        _detectedPlate != null) {
      return;
    }
    if (!controller.value.isInitialized || controller.value.isTakingPicture) {
      return;
    }

    _isProcessing = true;
    if (mounted) setState(() {});

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      final result = await AnprService.detectFromBase64(base64Encode(bytes));

      if (!mounted) return;
      if (result.success && result.plate != null && result.plate!.isNotEmpty) {
        _scanTimer?.cancel();
        unawaited(_fireDetectionHaptic());
        setState(() {
          _detectedPlate = result.plate;
          _confidence = result.confidence;
          _statusIsError = false;
          _statusText = 'Plat terdeteksi (${(_confidence * 100).round()}%).';
        });

        Future<void>.delayed(const Duration(milliseconds: 550), () {
          if (!mounted || _detectedPlate == null) return;
          widget.onPlateDetected(_detectedPlate!);
          Navigator.of(context).pop();
        });
      }
    } catch (_) {
      // Deteksi gagal diabaikan agar loop tetap berjalan mulus.
    } finally {
      _isProcessing = false;
      if (mounted) setState(() {});
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
    _scanTimer?.cancel();
    _scanLineController.dispose();
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
        child: SafeArea(
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
                            'Posisikan plat di dalam bingkai',
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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final frameWidth = math.min(
                      constraints.maxWidth * 0.84,
                      520.0,
                    );
                    final frameHeight = math.min(
                      frameWidth * 0.42,
                      constraints.maxHeight * 0.42,
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCameraPreview(texts),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.navyDark.withValues(alpha: 0.55),
                                  AppTheme.navyDark.withValues(alpha: 0),
                                  AppTheme.navyDark.withValues(alpha: 0.72),
                                ],
                                stops: const [0, 0.35, 1],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0, -0.06),
                          child: _ScannerFrame(
                            width: frameWidth,
                            height: frameHeight,
                            detected: _detectedPlate != null,
                            processing: _isProcessing,
                            scanAnimation: _scanLineController,
                          ),
                        ),
                        if (_torchAvailable)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.md,
                            child: _TorchButton(
                              isOn: _isTorchOn,
                              onPressed: _toggleTorch,
                            ),
                          ),
                        if (_detectedPlate != null)
                          Positioned(
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                            child: _DetectionBanner(
                              plate: _detectedPlate!,
                              confidence: _confidence,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    Text(
                      _statusText ?? 'Arahkan kamera ke plat nomor kendaraan.',
                      textAlign: TextAlign.center,
                      style: texts.bodySmall?.copyWith(
                        color: _statusIsError
                            ? AppTheme.errorLight
                            : AppTheme.surfaceWhite.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
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
      ),
    );
  }

  Widget _buildCameraPreview(TextTheme texts) {
    final controller = _controller;
    if (_isCameraReady && controller != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
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

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({
    required this.width,
    required this.height,
    required this.detected,
    required this.processing,
    required this.scanAnimation,
  });

  final double width;
  final double height;
  final bool detected;
  final bool processing;
  final Animation<double> scanAnimation;

  @override
  Widget build(BuildContext context) {
    final color = detected ? AppTheme.successGreen : AppTheme.amberGold;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navyDark.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppTheme.surfaceWhite.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: AnimatedBuilder(
                animation: scanAnimation,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, -1 + 2 * scanAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0),
                        color,
                        color.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Corner(top: true, left: true, color: color),
          _Corner(top: true, left: false, color: color),
          _Corner(top: false, left: true, color: color),
          _Corner(top: false, left: false, color: color),
          if (processing)
            Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.top, required this.left, required this.color});

  final bool top;
  final bool left;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final borderSide = BorderSide(color: color, width: 4);
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            top: top ? borderSide : BorderSide.none,
            bottom: top ? BorderSide.none : borderSide,
            left: left ? borderSide : BorderSide.none,
            right: left ? BorderSide.none : borderSide,
          ),
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
