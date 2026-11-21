import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
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

/// Satu pass deteksi: sebagian gambar asli (koordinat piksel) yang di-resize
/// penuh menjadi input model persegi 416x416.
///
/// Model ini **tidak** cocok dengan letterbox (padding abu-abu). Diukur pada
/// foto plat asli: letterbox memberi skor 0.00, sedangkan resize penuh
/// (stretch, rasio aspek diabaikan) memberi 0.72. Karena itu setiap pass
/// me-resize area sumber tepat ke 416x416 tanpa padding.
class DetectionPass {
  const DetectionPass({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  /// Satu pass untuk satu frame.
  ///
  /// Bila [roi] diberikan (koordinat ternormalisasi 0..1), pass hanya memuat
  /// area panduan tersebut. Area panduan yang sempit membuat plat menempati
  /// porsi jauh lebih besar pada input 416x416 sehingga skor deteksi naik
  /// (diukur: plat 140 px pada frame 720x1280 memberi 0.41 untuk frame penuh,
  /// tetapi 0.62 pada area panduan 96% x 40%). Satu pass juga memangkas biaya
  /// inferensi menjadi separuh.
  static List<DetectionPass> plan(
    int imageWidth,
    int imageHeight, {
    ui.Rect? roi,
  }) {
    final w = imageWidth.toDouble();
    final h = imageHeight.toDouble();
    if (w <= 0 || h <= 0) return const [];

    if (roi != null) {
      final left = roi.left.clamp(0.0, 1.0) * w;
      final top = roi.top.clamp(0.0, 1.0) * h;
      final right = roi.right.clamp(0.0, 1.0) * w;
      final bottom = roi.bottom.clamp(0.0, 1.0) * h;
      if (right - left >= 16 && bottom - top >= 16) {
        return [
          DetectionPass(
            left: left,
            top: top,
            width: right - left,
            height: bottom - top,
          ),
        ];
      }
    }

    return [DetectionPass(left: 0, top: 0, width: w, height: h)];
  }

  /// Kembalikan kotak dari koordinat input model 416x416 ke koordinat gambar
  /// asli, dibatasi pada area pass ini.
  PlateDetection toImage(PlateDetection detection) {
    final scaleX = width / PlateDetector.inputSize;
    final scaleY = height / PlateDetector.inputSize;
    final maxX = left + width;
    final maxY = top + height;
    return PlateDetection(
      left: (left + detection.left * scaleX).clamp(left, maxX),
      top: (top + detection.top * scaleY).clamp(top, maxY),
      right: (left + detection.right * scaleX).clamp(left, maxX),
      bottom: (top + detection.bottom * scaleY).clamp(top, maxY),
      score: detection.score,
    );
  }
}

/// Hasil crop area plat yang siap di-OCR.
class PlateCropResult {
  const PlateCropResult({
    required this.path,
    required this.box,
    required this.score,
    this.previewBytes,
    this.width = 0,
    this.height = 0,
  });

  final String path;
  final PlateDetection box;
  final double score;
  final Uint8List? previewBytes;
  final int width;
  final int height;
}

/// Detektor plat on-device (YOLOv8n hasil konversi TFLite).
///
/// Model masukan 1x416x416x3 (NHWC, RGB, skala 0..1) dan keluaran 1x5x3549
/// (cx, cy, w, h, skor untuk satu kelas "plat"). Alur deteksi:
/// resize stretch area panduan -> inferensi -> decode -> NMS -> crop area
/// plat, lalu crop diperbesar agar OCR ML Kit mudah membaca plat yang jauh.
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

  /// Pesan terakhir saat model gagal dimuat. Ditampilkan di layar scanner
  /// supaya penyebabnya (asset hilang, library native tidak ada, bentuk
  /// keluaran tidak cocok) bisa dibaca langsung tanpa logcat.
  String? lastLoadError;

  /// Skor deteksi tertinggi dari frame terakhir yang diproses.
  double lastBestScore = 0;

  /// Jumlah kotak yang lolos ambang sebelum NMS pada frame terakhir.
  int lastRawCount = 0;

  bool get isReady => _interpreter != null;

  /// True bila model gagal dimuat (asset hilang/rusak). Pemanggil harus
  /// kembali memakai OCR frame penuh.
  bool get isUnavailable => _failed;

  Future<void> ensureLoaded() {
    if (_interpreter != null || _failed) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    Interpreter? interpreter;
    InterpreterOptions? options;
    try {
      // LiteRT sudah mengaktifkan akselerasi CPU bawaan; jangan pasang
      // XNNPackDelegate manual lewat FFI karena berisiko crash native
      // (SIGSEGV/SIGABRT) saat pembuatan interpreter di beberapa perangkat.
      options = InterpreterOptions()..threads = 4;
      interpreter = await Interpreter.fromAsset(assetPath, options: options);
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      final validInput =
          inputShape.length == 4 &&
          inputShape[1] == inputSize &&
          inputShape[2] == inputSize &&
          inputShape[3] == 3;
      final validOutput =
          outputShape.length == 3 &&
          outputShape[1] == valuesPerAnchor &&
          outputShape[2] == numAnchors;
      if (validInput && validOutput) {
        _interpreter = interpreter;
      } else {
        interpreter.close();
        interpreter = null;
        _failed = true;
        lastLoadError =
            'bentuk tensor tidak cocok: in=$inputShape out=$outputShape';
      }
    } catch (e) {
      interpreter?.close();
      _failed = true;
      lastLoadError = e.toString();
    } finally {
      options?.delete();
    }
  }

  /// Deteksi semua kotak plat pada sebuah file gambar tanpa memotongnya.
  /// Dipakai untuk diagnostik (menampilkan skor terbaik di layar scanner)
  /// dan untuk pengujian pipeline inferensi yang sebenarnya.
  Future<List<PlateDetection>> detect(
    String imagePath, {
    double minScore = defaultScoreThreshold,
    ui.Rect? roi,
  }) async {
    await ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) return const [];

    ui.Image? image;
    ui.Codec? codec;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
      final detections = await _detectImage(interpreter, image, roi: roi);
      return detections
          .where((detection) => detection.score >= minScore)
          .toList();
    } catch (_) {
      return const [];
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// Deteksi plat pada file gambar dan hasilkan crop PNG yang sudah
  /// diperbesar. Mengembalikan null bila model tidak tersedia atau tidak ada
  /// plat yang cukup yakin.
  Future<PlateCropResult?> detectAndCrop(
    String imagePath, {
    ui.Rect? roi,
  }) async {
    final results = await detectAndCropAll(imagePath, maxCrops: 1, roi: roi);
    return results.isEmpty ? null : results.first;
  }

  /// Decode file gambar menjadi [ui.Image] sekali saja untuk dipakai ulang di
  /// beberapa langkah dalam satu frame. Pemanggil wajib memanggil `dispose()`.
  Future<ui.Image?> decodeFile(String imagePath) async {
    ui.Codec? codec;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
    }
  }

  /// Deteksi sampai [maxCrops] area plat terbaik pada [image] yang sudah
  /// di-decode, lalu potong & perbesar masing-masing untuk OCR.
  Future<List<PlateCropResult>> detectAndCropImage(
    ui.Image image, {
    double minScore = 0.35,
    int maxCrops = 1,
    ui.Rect? roi,
  }) async {
    await ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) return const [];

    try {
      final detections = await _detectImage(interpreter, image, roi: roi);
      final results = <PlateCropResult>[];
      for (final detection in detections) {
        if (results.length >= maxCrops) break;
        // Deteksi sudah terurut skor menurun; sisanya pasti di bawah ambang.
        if (detection.score < minScore) break;
        // Kotak yang terlalu kecil tidak mungkin memuat 5+ karakter plat.
        if (detection.width < 24 || detection.height < 10) continue;
        final crop = await _cropToPngWithInfo(image, detection);
        if (crop == null) continue;
        results.add(
          PlateCropResult(
            path: crop.path,
            box: detection,
            score: detection.score,
            previewBytes: crop.bytes,
            width: crop.width,
            height: crop.height,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  /// Deteksi sampai [maxCrops] area plat terbaik (skor tertinggi lebih dulu)
  /// lalu potong & perbesar masing-masing untuk OCR.
  ///
  /// Beberapa kandidat dipakai karena OCR kadang gagal pada satu crop (plat
  /// miring, terpotong, atau bayangan) tetapi berhasil pada kandidat lain.
  Future<List<PlateCropResult>> detectAndCropAll(
    String imagePath, {
    double minScore = 0.35,
    int maxCrops = 1,
    ui.Rect? roi,
  }) async {
    final image = await decodeFile(imagePath);
    if (image == null) return const [];
    try {
      return await detectAndCropImage(
        image,
        minScore: minScore,
        maxCrops: maxCrops,
        roi: roi,
      );
    } finally {
      image.dispose();
    }
  }

  /// Deteksi pada satu area panduan, lalu kembalikan kotak dalam koordinat
  /// gambar asli dan buang kotak yang bertumpuk.
  Future<List<PlateDetection>> _detectImage(
    Interpreter interpreter,
    ui.Image image, {
    ui.Rect? roi,
  }) async {
    final passes = DetectionPass.plan(image.width, image.height, roi: roi);
    if (passes.isEmpty) return const [];

    // Ambang rendah di sini: pemanggil yang menentukan ambang akhir, supaya
    // kotak berskor sedang masih bisa dipakai sebagai kandidat crop OCR.
    const internalThreshold = 0.15;
    var best = 0.0;
    var rawCount = 0;
    final collected = <PlateDetection>[];

    for (final pass in passes) {
      final inputImage = await renderPass(image, pass);
      try {
        final decoded = await _runInference(interpreter, inputImage);
        rawCount += decoded.length;
        for (final detection in decoded) {
          if (detection.score > best) best = detection.score;
          if (detection.score < internalThreshold) continue;
          collected.add(pass.toImage(detection));
        }
      } finally {
        inputImage.dispose();
      }
    }

    lastBestScore = best;
    lastRawCount = rawCount;

    final kept = nonMaxSuppression(collected)
      ..sort((a, b) => b.score.compareTo(a.score));
    return kept;
  }

  Future<List<PlateDetection>> _runInference(
    Interpreter interpreter,
    ui.Image inputImage,
  ) async {
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
      final src = i * 4;
      final dst = i * 3;
      input[dst] = rgba[src] / 255.0;
      input[dst + 1] = rgba[src + 1] / 255.0;
      input[dst + 2] = rgba[src + 2] / 255.0;
    }

    // Kirim buffer mentah (Uint8List untuk input, ByteBuffer untuk output),
    // bukan list bersarang: menghindari jutaan alokasi dan pemindaian shape
    // per frame.
    final outputBytes = Uint8List(valuesPerAnchor * numAnchors * 4);
    interpreter.run(input.buffer.asUint8List(), outputBytes.buffer);

    final flat = Float32List.view(
      outputBytes.buffer,
      outputBytes.offsetInBytes,
      outputBytes.length ~/ 4,
    );
    return decodeFlatOutput(flat, scoreThreshold: 0.01);
  }

  /// Decode keluaran datar [5 x 3549] (cx, cy, w, h, skor).
  @visibleForTesting
  static List<PlateDetection> decodeFlatOutput(
    Float32List flat, {
    double scoreThreshold = defaultScoreThreshold,
  }) {
    if (flat.length < valuesPerAnchor * numAnchors) return const [];
    final channels = <List<double>>[
      for (var c = 0; c < valuesPerAnchor; c++)
        Float32List.sublistView(flat, c * numAnchors, (c + 1) * numAnchors),
    ];
    return decodeOutput(channels, scoreThreshold: scoreThreshold);
  }

  /// Render area [pass] dari gambar asli tepat ke 416x416 (stretch, tanpa
  /// padding) — preprocessing yang cocok dengan model ini.
  @visibleForTesting
  Future<ui.Image> renderPass(ui.Image image, DetectionPass pass) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(pass.left, pass.top, pass.width, pass.height),
      ui.Rect.fromLTWH(0, 0, inputSize.toDouble(), inputSize.toDouble()),
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
    final halfW = widthRatio.clamp(0.1, 1.0) / 2;
    final halfH = heightRatio.clamp(0.1, 1.0) / 2;
    return cropRegion(
      imagePath,
      left: 0.5 - halfW,
      top: 0.5 - halfH,
      right: 0.5 + halfW,
      bottom: 0.5 + halfH,
    );
  }

  /// Potong sebagian [image] yang sudah di-decode berdasarkan koordinat
  /// ternormalisasi 0..1, lalu perbesar hasilnya.
  Future<String?> cropRegionFromImage(
    ui.Image image, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    try {
      final width = image.width.toDouble();
      final height = image.height.toDouble();
      final x1 = (left.clamp(0.0, 1.0) * width);
      final y1 = (top.clamp(0.0, 1.0) * height);
      final x2 = (right.clamp(0.0, 1.0) * width);
      final y2 = (bottom.clamp(0.0, 1.0) * height);
      final source = ui.Rect.fromLTRB(
        math.min(x1, x2),
        math.min(y1, y2),
        math.max(x1, x2),
        math.max(y1, y2),
      );
      return await _cropImageToPng(image, source);
    } catch (_) {
      return null;
    }
  }

  /// Potong sebagian frame berdasarkan koordinat ternormalisasi 0..1, lalu
  /// perbesar hasilnya. Dipakai untuk menyapu beberapa area (tengah, bawah,
  /// atas) agar plat yang tidak tepat di tengah tetap terbaca OCR.
  Future<String?> cropRegion(
    String imagePath, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    final image = await decodeFile(imagePath);
    if (image == null) return null;
    try {
      return await cropRegionFromImage(
        image,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
    } finally {
      image.dispose();
    }
  }

  /// Potong beberapa area (koordinat ternormalisasi 0..1) dari satu frame,
  /// hanya sekali decode JPEG. Dipakai saat menyapu OCR beberapa area per
  /// frame; decode ulang untuk tiap area terlalu mahal.
  Future<List<String?>> cropRegions(
    String imagePath,
    List<(double, double, double, double)> regions,
  ) async {
    if (regions.isEmpty) return const [];
    ui.Image? image;
    ui.Codec? codec;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
      final width = image.width.toDouble();
      final height = image.height.toDouble();

      final paths = <String?>[];
      for (final region in regions) {
        final x1 = region.$1.clamp(0.0, 1.0) * width;
        final y1 = region.$2.clamp(0.0, 1.0) * height;
        final x2 = region.$3.clamp(0.0, 1.0) * width;
        final y2 = region.$4.clamp(0.0, 1.0) * height;
        paths.add(
          await _cropImageToPng(
            image,
            ui.Rect.fromLTRB(
              math.min(x1, x2),
              math.min(y1, y2),
              math.max(x1, x2),
              math.max(y1, y2),
            ),
          ),
        );
      }
      return paths;
    } catch (_) {
      return List<String?>.filled(regions.length, null);
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<({String path, Uint8List bytes, int width, int height})?>
  _cropToPngWithInfo(ui.Image image, PlateDetection box) async {
    final marginX = box.width * 0.12;
    final marginY = box.height * 0.22;
    final left = (box.left - marginX).clamp(0.0, image.width.toDouble());
    final top = (box.top - marginY).clamp(0.0, image.height.toDouble());
    final right = (box.right + marginX).clamp(0.0, image.width.toDouble());
    final bottom = (box.bottom + marginY).clamp(0.0, image.height.toDouble());
    return _cropImageToPngWithInfo(
      image,
      ui.Rect.fromLTRB(left, top, right, bottom),
    );
  }

  /// Buat salinan PNG dari [imagePath] dengan warna dibalik dan kontras
  /// ditingkatkan. Dipakai OCR cadangan untuk plat hitam berhuruf putih
  /// (plat truk): ML Kit jauh lebih andal membaca teks hitam di latar putih.
  Future<String?> invertToPng(String imagePath) async {
    ui.Image? image;
    ui.Codec? codec;
    ui.Image? inverted;
    try {
      final bytes = await File(imagePath).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Isi latar putih solid dulu agar tidak ada saluran alfa transparan.
      canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      // Grayscale + inversi + peningkatan kontras (~1.6x) untuk huruf putih
      // di atas plat hitam/abu-abu gelap.
      const c = -1.6;
      const t = 255.0 * 1.3;
      const rW = 0.299 * c;
      const gW = 0.587 * c;
      const bW = 0.114 * c;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          ..colorFilter = const ui.ColorFilter.matrix(<double>[
            rW, gW, bW, 0, t, //
            rW, gW, bW, 0, t, //
            rW, gW, bW, 0, t, //
            0, 0, 0, 1, 0, //
          ]),
      );
      final picture = recorder.endRecording();
      try {
        inverted = await picture.toImage(image.width, image.height);
      } finally {
        picture.dispose();
      }
      final png = await _encodePng(inverted);
      if (png == null) return null;
      return await _savePngBytes(png);
    } catch (_) {
      return null;
    } finally {
      inverted?.dispose();
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<String?> _cropImageToPng(ui.Image image, ui.Rect source) async {
    final result = await _cropImageToPngWithInfo(image, source);
    return result?.path;
  }

  Future<({String path, Uint8List bytes, int width, int height})?>
  _cropImageToPngWithInfo(ui.Image image, ui.Rect source) async {
    if (source.width < 8 || source.height < 4) return null;

    // Perbesar crop: plat kecil (jauh) butuh glyph yang lebih besar untuk OCR.
    // Semua crop (termasuk tile selebar frame) ikut diperbesar minimal 2,2x
    // agar teks plat cukup besar saat masuk ML Kit.
    final targetWidth = math.min(1600.0, math.max(720.0, source.width * 2.2));
    final targetHeight = targetWidth * source.height / source.width;
    final outW = targetWidth.round();
    final outH = targetHeight.round();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // Pastikan kanvas opaque agar PNG tidak membawa alpha channel kosong.
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
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
      cropped = await picture.toImage(outW, outH);
      final bytes = await _encodePng(cropped);
      if (bytes == null) return null;
      final path = await _savePngBytes(bytes);
      return (path: path, bytes: bytes, width: outW, height: outH);
    } catch (_) {
      return null;
    } finally {
      cropped?.dispose();
      picture.dispose();
    }
  }

  Future<Uint8List?> _encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Simpan byte PNG ke file sementara dan kembalikan path-nya.
  Future<String> _savePngBytes(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'anpr_plate_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file.path;
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
}
