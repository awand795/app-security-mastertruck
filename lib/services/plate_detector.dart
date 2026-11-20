import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Kotak plat dalam koordinat piksel gambar asli.
class PlateDetection {
  const PlateDetection({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double score;

  double get width => right - left;
  double get height => bottom - top;

  ui.Rect get rect => ui.Rect.fromLTRB(left, top, right, bottom);

  @override
  String toString() =>
      'PlateDetection(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)} '
      'score=${score.toStringAsFixed(3)})';
}

/// Transformasi letterbox gambar asli ke input model persegi.
class LetterboxTransform {
  const LetterboxTransform({
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final double scale;
  final double padX;
  final double padY;
}

/// Hasil crop area plat yang siap di-OCR.
class PlateCropResult {
  const PlateCropResult({
    required this.path,
    required this.box,
    required this.score,
  });

  final String path;
  final PlateDetection box;
  final double score;
}

/// Detektor plat on-device (YOLOv8n hasil konversi TFLite).
///
/// Model masukan 1x416x416x3 (NHWC, RGB, skala 0..1) dan keluaran 1x5x3549
/// (cx, cy, w, h, skor untuk satu kelas "plat"). Alur deteksi:
/// letterbox -> inferensi -> decode -> NMS -> crop area plat, lalu crop
/// diperbesar agar OCR ML Kit mudah membaca plat yang jauh.
///
/// Semua metode murni (letterbox, decode, NMS, mapping kotak) dipisah agar
/// bisa diuji tanpa model maupun kamera.
class PlateDetector {
  PlateDetector._();

  static final PlateDetector instance = PlateDetector._();

  static const String assetPath = 'assets/models/plate_det.tflite';
  static const int inputSize = 416;
  static const int numAnchors = 3549;
  static const int valuesPerAnchor = 5;
  static const double defaultScoreThreshold = 0.25;
  static const double defaultIouThreshold = 0.45;

  Interpreter? _interpreter;
  Future<void>? _loading;
  bool _failed = false;

  bool get isReady => _interpreter != null;

  /// True bila model gagal dimuat (asset hilang/rusak). Pemanggil harus
  /// kembali memakai OCR frame penuh.
  bool get isUnavailable => _failed;

  Future<void> ensureLoaded() {
    if (_interpreter != null || _failed) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final interpreter = await Interpreter.fromAsset(
        assetPath,
        options: InterpreterOptions()..threads = 2,
      );
      final shape = interpreter.getOutputTensor(0).shape;
      final validShape =
          shape.length == 3 &&
          shape[1] == valuesPerAnchor &&
          shape[2] == numAnchors;
      if (validShape) {
        _interpreter = interpreter;
      } else {
        interpreter.close();
        _failed = true;
      }
    } catch (_) {
      _failed = true;
    }
  }

  /// Deteksi plat pada file gambar dan hasilkan crop PNG yang sudah
  /// diperbesar. Mengembalikan null bila model tidak tersedia atau tidak ada
  /// plat yang cukup yakin.
  Future<PlateCropResult?> detectAndCrop(String imagePath) async {
    await ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    ui.Image? image;
    ui.Codec? codec;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;

      final detections = await _detectImage(interpreter, image);
      if (detections.isEmpty) return null;

      final best = detections.first;
      final cropPath = await _cropToPng(image, best);
      if (cropPath == null) return null;

      return PlateCropResult(path: cropPath, box: best, score: best.score);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<List<PlateDetection>> _detectImage(
    Interpreter interpreter,
    ui.Image image,
  ) async {
    final transform = letterboxTransform(image.width, image.height);
    final inputImage = await _letterboxImage(image, transform);
    try {
      final byteData = await inputImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return const [];

      final rgba = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      const pixelCount = inputSize * inputSize;
      // Model TFLite hasil konversi memakai layout NHWC (piksel berurutan RGB).
      final input = Float32List(3 * pixelCount);
      for (var i = 0; i < pixelCount; i++) {
        input[i * 3] = rgba[i * 4] / 255.0;
        input[i * 3 + 1] = rgba[i * 4 + 1] / 255.0;
        input[i * 3 + 2] = rgba[i * 4 + 2] / 255.0;
      }

      final output = Float32List(valuesPerAnchor * numAnchors)
          .reshape<double>([1, valuesPerAnchor, numAnchors]);
      interpreter.run(
        input.reshape<double>([1, inputSize, inputSize, 3]),
        output,
      );

      final channels = (output[0] as List).cast<List<double>>();
      final decoded = decodeOutput(channels);
      final kept = nonMaxSuppression(decoded);
      return kept
          .map(
            (detection) =>
                mapToImage(detection, transform, image.width, image.height),
          )
          .toList();
    } finally {
      inputImage.dispose();
    }
  }

  Future<ui.Image> _letterboxImage(
    ui.Image image,
    LetterboxTransform transform,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF727272), ui.BlendMode.src);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(
        transform.padX,
        transform.padY,
        image.width * transform.scale,
        image.height * transform.scale,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(inputSize, inputSize);
    } finally {
      picture.dispose();
    }
  }

  /// Potong area tengah frame (rasio 0..1 terhadap ukuran frame) lalu
  /// perbesar. Dipakai sebagai upaya OCR cadangan saat detektor tidak
  /// menemukan kotak plat: plat di gerbang umumnya berada di tengah frame.
  Future<String?> cropCenterRegion(
    String imagePath, {
    double widthRatio = 0.9,
    double heightRatio = 0.6,
  }) async {
    ui.Image? image;
    ui.Codec? codec;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();
      final source = ui.Rect.fromCenter(
        center: ui.Offset(width / 2, height / 2),
        width: width * widthRatio.clamp(0.1, 1.0),
        height: height * heightRatio.clamp(0.1, 1.0),
      );
      return await _cropImageToPng(image, source);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<String?> _cropToPng(ui.Image image, PlateDetection box) async {
    final marginX = box.width * 0.10;
    final marginY = box.height * 0.18;
    final left = (box.left - marginX).clamp(0.0, image.width.toDouble());
    final top = (box.top - marginY).clamp(0.0, image.height.toDouble());
    final right = (box.right + marginX).clamp(0.0, image.width.toDouble());
    final bottom = (box.bottom + marginY).clamp(0.0, image.height.toDouble());
    return _cropImageToPng(image, ui.Rect.fromLTRB(left, top, right, bottom));
  }

  Future<String?> _cropImageToPng(ui.Image image, ui.Rect source) async {
    if (source.width < 8 || source.height < 4) return null;

    // Perbesar crop: plat kecil (jauh) butuh glyph yang lebih besar untuk OCR.
    final targetWidth = math.min(1280.0, math.max(640.0, source.width * 2.4));
    final targetHeight = targetWidth * source.height / source.width;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      source,
      ui.Rect.fromLTWH(0, 0, targetWidth, targetHeight),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true,
    );
    final picture = recorder.endRecording();
    ui.Image? cropped;
    try {
      cropped = await picture.toImage(
        targetWidth.round(),
        targetHeight.round(),
      );
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'anpr_plate_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return file.path;
    } catch (_) {
      return null;
    } finally {
      cropped?.dispose();
      picture.dispose();
    }
  }

  /// Letterbox: jaga rasio aspek, sisipkan padding abu-abu di tengah.
  static LetterboxTransform letterboxTransform(
    int imageWidth,
    int imageHeight,
  ) {
    final scale = math.min(inputSize / imageWidth, inputSize / imageHeight);
    return LetterboxTransform(
      scale: scale,
      padX: (inputSize - imageWidth * scale) / 2,
      padY: (inputSize - imageHeight * scale) / 2,
    );
  }

  /// Decode keluaran YOLOv8 ([5][3549] = cx, cy, w, h, skor).
  static List<PlateDetection> decodeOutput(
    List<List<double>> channels, {
    double scoreThreshold = defaultScoreThreshold,
  }) {
    if (channels.length < valuesPerAnchor) return const [];
    final cxRow = channels[0];
    final cyRow = channels[1];
    final widthRow = channels[2];
    final heightRow = channels[3];
    final scoreRow = channels[4];

    final count = math.min(
      numAnchors,
      math.min(
        math.min(cxRow.length, cyRow.length),
        math.min(widthRow.length, math.min(heightRow.length, scoreRow.length)),
      ),
    );

    final detections = <PlateDetection>[];
    for (var i = 0; i < count; i++) {
      final score = scoreRow[i];
      if (score < scoreThreshold) continue;
      final rawCx = cxRow[i];
      final rawCy = cyRow[i];
      final rawW = widthRow[i];
      final rawH = heightRow[i];
      if (rawW <= 0 || rawH <= 0) continue;

      // Model TFLite Ultralytics kadang mengeluarkan koordinat ternormalisasi
      // (0..1) atau piksel input (0..416); dukung keduanya.
      final isNormalized =
          rawCx <= 1.5 && rawCy <= 1.5 && rawW <= 1.5 && rawH <= 1.5;
      final scaleFactor = isNormalized ? inputSize.toDouble() : 1.0;
      final cx = rawCx * scaleFactor;
      final cy = rawCy * scaleFactor;
      final width = rawW * scaleFactor;
      final height = rawH * scaleFactor;

      detections.add(
        PlateDetection(
          left: cx - width / 2,
          top: cy - height / 2,
          right: cx + width / 2,
          bottom: cy + height / 2,
          score: score,
        ),
      );
    }
    return detections;
  }

  static double iou(PlateDetection a, PlateDetection b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    if (intersection <= 0) return 0;
    final union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  static List<PlateDetection> nonMaxSuppression(
    List<PlateDetection> detections, {
    double iouThreshold = defaultIouThreshold,
  }) {
    final sorted = [...detections]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <PlateDetection>[];
    for (final candidate in sorted) {
      final overlaps = kept.any(
        (other) => iou(other, candidate) >= iouThreshold,
      );
      if (!overlaps) kept.add(candidate);
    }
    return kept;
  }

  /// Kembalikan kotak dari koordinat input model ke koordinat gambar asli.
  static PlateDetection mapToImage(
    PlateDetection detection,
    LetterboxTransform transform,
    int imageWidth,
    int imageHeight,
  ) {
    final maxX = imageWidth.toDouble();
    final maxY = imageHeight.toDouble();
    return PlateDetection(
      left: ((detection.left - transform.padX) / transform.scale).clamp(
        0.0,
        maxX,
      ),
      top: ((detection.top - transform.padY) / transform.scale).clamp(
        0.0,
        maxY,
      ),
      right: ((detection.right - transform.padX) / transform.scale).clamp(
        0.0,
        maxX,
      ),
      bottom: ((detection.bottom - transform.padY) / transform.scale).clamp(
        0.0,
        maxY,
      ),
      score: detection.score,
    );
  }
}
