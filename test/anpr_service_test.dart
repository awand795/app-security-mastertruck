import 'package:bengkel_kim3_security_app/services/anpr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractIndonesianPlate', () {
    test('membaca plat standar', () {
      expect(AnprService.extractIndonesianPlate('B 2156 TQR'), 'B 2156 TQR');
      expect(AnprService.extractIndonesianPlate('BK 9393 RR'), 'BK 9393 RR');
      expect(AnprService.extractIndonesianPlate('D 1 A'), 'D 1 A');
    });

    test('mengabaikan baris masa berlaku dan teks pengganggu', () {
      const raw = 'MASA BERLAKU\n08.28\nBK 9393 RR\n11-27';
      expect(AnprService.extractIndonesianPlate(raw), 'BK 9393 RR');
    });

    test('plat dengan tanda hubung/titik tetap terbaca', () {
      expect(AnprService.extractIndonesianPlate('BK-9393-RR'), 'BK 9393 RR');
      expect(AnprService.extractIndonesianPlate('BK.9393.RR'), 'BK 9393 RR');
    });

    test('plat yang terpecah per baris tetap terbaca', () {
      expect(AnprService.extractIndonesianPlate('BK\n9393\nRR'), 'BK 9393 RR');
    });

    test('mengoreksi kekeliruan OCR huruf/angka', () {
      // 8 -> B, O -> 0
      expect(AnprService.extractIndonesianPlate('8K 939O RR'), 'BK 9390 RR');
      // suffix angka -> huruf
      expect(AnprService.extractIndonesianPlate('BK 9393 R8'), 'BK 9393 RB');
    });

    test('memilih kandidat dengan pola paling meyakinkan', () {
      const raw = 'NO 1 A\nSPK-2026-1042\nBK 9393 RR';
      expect(AnprService.extractIndonesianPlate(raw), 'BK 9393 RR');
    });

    test('mengembalikan null bila bukan plat', () {
      expect(AnprService.extractIndonesianPlate('SELAMAT DATANG'), isNull);
      expect(AnprService.extractIndonesianPlate('12345'), isNull);
      expect(AnprService.extractIndonesianPlate('   '), isNull);
    });
  });

  group('isSimilarPlate', () {
    test('beda satu karakter dianggap sama', () {
      expect(AnprService.isSimilarPlate('BK 9393 RR', 'BK 9393 RB'), isTrue);
      expect(AnprService.isSimilarPlate('BK9393RR', 'BK 9393 RR'), isTrue);
    });

    test('beda lebih dari satu karakter dianggap berbeda', () {
      expect(AnprService.isSimilarPlate('BK 9393 RR', 'BK 9383 RB'), isFalse);
      expect(AnprService.isSimilarPlate('BK 939 RR', 'BK 9393 RR'), isFalse);
    });
  });

  group('consensusPlate', () {
    test('dua bacaan identik langsung dikonfirmasi', () {
      final result = AnprService.consensusPlate(['BK 9393 RR', 'BK9393RR']);
      expect(result, isNotNull);
      expect(result!.plate, 'BK 9393 RR');
      expect(result.votes, 2);
      expect(result.exactMatch, isTrue);
      expect(result.confidence, greaterThan(0.9));
    });

    test('satu bacaan belum cukup', () {
      expect(AnprService.consensusPlate(['BK 9393 RR']), isNull);
      expect(AnprService.consensusPlate([]), isNull);
    });

    test('tiga bacaan mirip diambil suara terbanyak per karakter', () {
      final result = AnprService.consensusPlate([
        'BK 9393 RR',
        'BK 9393 RB',
        'BK 9393 BR',
      ]);
      expect(result, isNotNull);
      // Karakter terakhir R menang 2 dari 3 suara.
      expect(result!.plate, 'BK 9393 RR');
      expect(result.exactMatch, isFalse);
      expect(result.votes, 3);
      expect(result.confidence, lessThan(0.95));
    });

    test('tiga bacaan mirip tanpa mayoritas per karakter tetap dikunci', () {
      // Tiap posisi terakhir berbeda (R/B/Q) sehingga voting per karakter
      // gagal, tetapi bacaan saling mirip dan harus tetap terkunci.
      final result = AnprService.consensusPlate([
        'BK 9393 RR',
        'BK 9393 RB',
        'BK 9393 RQ',
      ]);
      expect(result, isNotNull);
      expect(result!.plate, 'BK 9393 RR');
      expect(result.exactMatch, isFalse);
      expect(result.votes, 3);
    });

    test('bacaan yang tidak sepakat tidak dikonfirmasi', () {
      expect(AnprService.consensusPlate(['BK 9393 RR', 'B 2156 TQR']), isNull);
    });

    test('bacaan tidak valid diabaikan', () {
      expect(AnprService.consensusPlate(['ABCDEFG', 'BK 9393 RR']), isNull);
    });
  });

  group('mergeSimilarPlates', () {
    test('menggabungkan plat yang kurang satu karakter', () {
      expect(
        AnprService.mergeSimilarPlates('BK 939 RR', 'BK 9393 RR'),
        'BK 9393 RR',
      );
    });

    test('plat berbeda jauh tidak digabung', () {
      expect(
        AnprService.mergeSimilarPlates('BK 9393 RR', 'B 2156 TQR'),
        isNull,
      );
    });
  });
}
