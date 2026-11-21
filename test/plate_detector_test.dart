import 'dart:typed_data';
import 'dart:ui';

import 'package:bengkel_kim3_security_app/services/plate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _zeros() => List<double>.filled(PlateDetector.numAnchors, 0);

void main() {
  group('DetectionPass.plan', () {
    test('tanpa area panduan memakai frame penuh sebagai satu pass', () {
      final passes = DetectionPass.plan(1280, 720);
      expect(passes, hasLength(1));
      expect(passes.first.left, 0);
      expect(passes.first.top, 0);
      expect(passes.first.width, 1280);
      expect(passes.first.height, 720);
    });

    test('area panduan dipotong sesuai koordinat ternormalisasi', () {
      final passes = DetectionPass.plan(
        1280,
        720,
        roi: const Rect.fromLTRB(0.02, 0.32, 0.98, 0.68),
      );
      expect(passes, hasLength(1));
      final roi = passes.first;
      expect(roi.left, closeTo(1280 * 0.02, 1e-9));
      expect(roi.top, closeTo(720 * 0.32, 1e-9));
      expect(roi.width, closeTo(1280 * 0.96, 1e-9));
      expect(roi.height, closeTo(720 * 0.36, 1e-9));
    });

    test('area panduan terlalu kecil diabaikan', () {
      final passes = DetectionPass.plan(
        1280,
        720,
        roi: const Rect.fromLTRB(0.5, 0.5, 0.5001, 0.5001),
      );
      expect(passes, hasLength(1));
      expect(passes.first.width, 1280);
      expect(passes.first.height, 720);
    });

    test('ukuran tidak valid menghasilkan pass kosong', () {
      expect(DetectionPass.plan(0, 0), isEmpty);
    });
  });

  group('decodeOutput', () {
    test('mendekode kotak di atas threshold', () {
      final cx = _zeros();
      final cy = _zeros();
      final width = _zeros();
      final height = _zeros();
      final score = _zeros();
      cx[0] = 100;
      cy[0] = 120;
      width[0] = 60;
      height[0] = 20;
      score[0] = 0.9;
      score[1] = 0.05;

      final detections = PlateDetector.decodeOutput([
        cx,
        cy,
        width,
        height,
        score,
      ]);

      expect(detections, hasLength(1));
      final detection = detections.first;
      expect(detection.left, 70);
      expect(detection.top, 110);
      expect(detection.right, 130);
      expect(detection.bottom, 130);
      expect(detection.score, 0.9);
    });

    test('mengabaikan kotak dengan ukuran tidak valid', () {
      final cx = _zeros();
      final cy = _zeros();
      final width = _zeros();
      final height = _zeros();
      final score = _zeros();
      score[0] = 0.9;
      score[1] = 0.9;
      width[1] = 0;

      expect(
        PlateDetector.decodeOutput([cx, cy, width, height, score]),
        isEmpty,
      );
    });

    test('output dengan channel kurang dari 5 diabaikan', () {
      expect(PlateDetector.decodeOutput([_zeros(), _zeros()]), isEmpty);
    });

    test('decodeFlatOutput membaca keluaran datar 5 x 3549', () {
      final flat = Float32List(
        PlateDetector.valuesPerAnchor * PlateDetector.numAnchors,
      );
      // anchor ke-7: cx=100, cy=120, w=60, h=20, skor=0.9
      flat[7] = 100;
      flat[PlateDetector.numAnchors + 7] = 120;
      flat[2 * PlateDetector.numAnchors + 7] = 60;
      flat[3 * PlateDetector.numAnchors + 7] = 20;
      flat[4 * PlateDetector.numAnchors + 7] = 0.9;

      final detections = PlateDetector.decodeFlatOutput(flat);
      expect(detections, hasLength(1));
      expect(detections.first.score, closeTo(0.9, 1e-6));
      expect(detections.first.left, closeTo(70, 1e-6));
      expect(detections.first.top, closeTo(110, 1e-6));
    });

    test('decodeFlatOutput mengabaikan buffer terlalu pendek', () {
      expect(PlateDetector.decodeFlatOutput(Float32List(10)), isEmpty);
    });
  });

  group('nonMaxSuppression', () {
    const overlappingA = PlateDetection(
      left: 10,
      top: 10,
      right: 60,
      bottom: 40,
      score: 0.9,
    );
    const overlappingB = PlateDetection(
      left: 12,
      top: 11,
      right: 58,
      bottom: 41,
      score: 0.8,
    );
    const separate = PlateDetection(
      left: 200,
      top: 200,
      right: 260,
      bottom: 240,
      score: 0.6,
    );

    test('kotak bertumpuk disisakan satu dengan skor tertinggi', () {
      final kept = PlateDetector.nonMaxSuppression([
        overlappingB,
        overlappingA,
        separate,
      ]);
      expect(kept, hasLength(2));
      expect(kept.first.score, 0.9);
      expect(kept.last, separate);
    });

    test('IoU kotak yang sama bernilai 1', () {
      expect(PlateDetector.iou(overlappingA, overlappingA), closeTo(1, 1e-9));
    });

    test('IoU kotak terpisah bernilai 0', () {
      expect(PlateDetector.iou(overlappingA, separate), 0);
    });
  });

  group('DetectionPass.toImage', () {
    const fullFrame = DetectionPass(left: 0, top: 0, width: 832, height: 832);

    test('mengembalikan koordinat ke ukuran gambar asli', () {
      final mapped = fullFrame.toImage(
        const PlateDetection(
          left: 100,
          top: 100,
          right: 200,
          bottom: 140,
          score: 0.9,
        ),
      );
      expect(mapped.left, 200);
      expect(mapped.top, 200);
      expect(mapped.right, 400);
      expect(mapped.bottom, 280);
    });

    test('menambahkan offset dan skala area crop tengah', () {
      const center = DetectionPass(
        left: 200,
        top: 100,
        width: 416,
        height: 208,
      );
      final mapped = center.toImage(
        const PlateDetection(
          left: 10,
          top: 110,
          right: 50,
          bottom: 130,
          score: 0.8,
        ),
      );
      expect(mapped.left, 210);
      expect(mapped.top, 155);
      expect(mapped.right, 250);
      expect(mapped.bottom, 165);
    });

    test('tidak menghasilkan koordinat di luar area pass', () {
      final mapped = fullFrame.toImage(
        const PlateDetection(
          left: -50,
          top: -50,
          right: 500,
          bottom: 500,
          score: 0.9,
        ),
      );
      expect(mapped.left, greaterThanOrEqualTo(0));
      expect(mapped.top, greaterThanOrEqualTo(0));
      expect(mapped.right, lessThanOrEqualTo(832));
      expect(mapped.bottom, lessThanOrEqualTo(832));
    });
  });
}
