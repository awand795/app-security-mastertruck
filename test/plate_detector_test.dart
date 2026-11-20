import 'package:bengkel_kim3_security_app/services/plate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _zeros() => List<double>.filled(PlateDetector.numAnchors, 0);

void main() {
  group('letterboxTransform', () {
    test('gambar persegi tidak diberi padding', () {
      final transform = PlateDetector.letterboxTransform(832, 832);
      expect(transform.scale, 0.5);
      expect(transform.padX, 0);
      expect(transform.padY, 0);
    });

    test('gambar landscape diberi padding vertikal', () {
      final transform = PlateDetector.letterboxTransform(416, 208);
      expect(transform.scale, 1.0);
      expect(transform.padX, 0);
      expect(transform.padY, 104);
    });

    test('gambar portrait diberi padding horizontal', () {
      final transform = PlateDetector.letterboxTransform(208, 416);
      expect(transform.scale, 1.0);
      expect(transform.padX, 104);
      expect(transform.padY, 0);
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

  group('mapToImage', () {
    const detection = PlateDetection(
      left: 100,
      top: 100,
      right: 200,
      bottom: 140,
      score: 0.9,
    );

    test('mengembalikan koordinat ke ukuran gambar asli', () {
      final transform = PlateDetector.letterboxTransform(832, 832);
      final mapped = PlateDetector.mapToImage(detection, transform, 832, 832);
      expect(mapped.left, 200);
      expect(mapped.top, 200);
      expect(mapped.right, 400);
      expect(mapped.bottom, 280);
    });

    test('membuang padding atas sebelum diskalakan', () {
      final transform = PlateDetector.letterboxTransform(416, 208);
      final mapped = PlateDetector.mapToImage(
        const PlateDetection(
          left: 10,
          top: 110,
          right: 50,
          bottom: 130,
          score: 0.8,
        ),
        transform,
        416,
        208,
      );
      expect(mapped.left, 10);
      expect(mapped.top, 6);
      expect(mapped.right, 50);
      expect(mapped.bottom, 26);
    });

    test('tidak menghasilkan koordinat di luar gambar', () {
      final transform = PlateDetector.letterboxTransform(832, 832);
      final mapped = PlateDetector.mapToImage(
        const PlateDetection(
          left: -50,
          top: -50,
          right: 500,
          bottom: 500,
          score: 0.9,
        ),
        transform,
        832,
        832,
      );
      expect(mapped.left, greaterThanOrEqualTo(0));
      expect(mapped.top, greaterThanOrEqualTo(0));
      expect(mapped.right, lessThanOrEqualTo(832));
      expect(mapped.bottom, lessThanOrEqualTo(832));
    });
  });
}
