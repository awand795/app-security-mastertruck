import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/anpr_service.dart';

class AnprScannerSheet extends StatefulWidget {
  final Function(String plate) onPlateDetected;

  const AnprScannerSheet({Key? key, required this.onPlateDetected}) : super(key: key);

  @override
  State<AnprScannerSheet> createState() => _AnprScannerSheetState();
}

class _AnprScannerSheetState extends State<AnprScannerSheet> {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String? _detectedPlate;
  double _confidence = 0.0;
  String? _statusText;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusText = 'Kamera tidak ditemukan pada perangkat.');
        return;
      }

      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isCameraReady = true;
        _statusText = 'Arahkan kotak ke plat nomor kendaraan...';
      });

      // Scan loop every 450ms
      _scanTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
        _captureAndDetect();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Gagal menyalakan kamera: $e');
      }
    }
  }

  Future<void> _captureAndDetect() async {
    if (!_isCameraReady || _isProcessing || _controller == null || _detectedPlate != null) return;
    if (!_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;

    _isProcessing = true;
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);

      final res = await AnprService.detectFromBase64(b64);
      if (res.success && res.plate != null && res.plate!.isNotEmpty) {
        setState(() {
          _detectedPlate = res.plate;
          _confidence = res.confidence;
          _statusText = 'Plat Terdeteksi (${(_confidence * 100).toStringAsFixed(0)}%)!';
        });

        // Auto accept after 400ms preview
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _detectedPlate != null) {
            widget.onPlateDetected(_detectedPlate!);
            Navigator.pop(context);
          }
        });
      }
    } catch (_) {
      // Ignored for smooth loop
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.navyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amberGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.document_scanner, color: AppTheme.amberGold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Plat Scanner',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Dual YOLO11 + SVTR Server',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Camera Viewport
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isCameraReady && _controller != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator(color: AppTheme.amberGold)),

                // Bounding Box Guide Overlay
                Container(
                  width: 310,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _detectedPlate != null ? AppTheme.successGreen : AppTheme.amberGold,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_detectedPlate != null ? AppTheme.successGreen : AppTheme.amberGold)
                            .withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Corner brackets
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Text(
                          'KOTAK PLAT',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isProcessing)
                        const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Detection Banner Popup
                if (_detectedPlate != null)
                  Positioned(
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _detectedPlate!,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Hint & Manual Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _statusText ?? 'Arahkan kamera ke plat nomor',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.keyboard, color: AppTheme.amberGold, size: 18),
                  label: Text(
                    'Ketik Manual',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.amberGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
