import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/plate_utils.dart';

class AnprResult {
  final bool success;
  final String? plate;
  final String? rawText;
  final double confidence;

  /// Semua kandidat plat yang terbaca, terurut dari skor tertinggi.
  final List<String> candidates;

  /// Pesan kesalahan bila OCR gagal dijalankan (bukan sekadar tidak ada teks).
  final String? error;

  AnprResult({
    required this.success,
    this.plate,
    this.rawText,
    this.confidence = 0.0,
    this.candidates = const [],
    this.error,
  });
}

/// Hasil kesepakatan beberapa frame pembacaan.
class PlateConsensus {
  const PlateConsensus({
    required this.plate,
    required this.votes,
    required this.confidence,
    required this.exactMatch,
  });

  final String plate;

  /// Jumlah frame yang mendukung plat ini.
  final int votes;

  /// Keyakinan 0..1 berdasarkan jumlah dan kekompakan bacaan.
  final double confidence;

  /// True bila semua frame pendukung membaca plat yang persis sama.
  final bool exactMatch;
}

class AnprService {
  /// Dibuat lazily agar fungsi parsing murni bisa dipakai tanpa plugin ML Kit.
  static TextRecognizer? _recognizerInstance;
  static TextRecognizer get _recognizer => _recognizerInstance ??=
      TextRecognizer(script: TextRecognitionScript.latin);

  static const Map<String, String> _toLetterMap = {
    '0': 'O',
    '1': 'I',
    '2': 'Z',
    '4': 'A',
    '5': 'S',
    '6': 'G',
    '8': 'B',
  };

  static const Map<String, String> _toDigitMap = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'T': '1',
    'Z': '2',
    'A': '4',
    'S': '5',
    'G': '6',
    'B': '8',
  };

  static final RegExp _validPrefix = RegExp(r'^[A-Z]{1,2}$');
  static final RegExp _validDigits = RegExp(r'^[1-9][0-9]{0,3}$');
  static final RegExp _validSuffix = RegExp(r'^[A-Z]{1,3}$');
  // Prefix ikut menerima angka karena OCR sering membaca B sebagai 8,
  // G sebagai 6, dan seterusnya; koreksi dilakukan setelah pencocokan.
  static final RegExp _plateShape = RegExp(
    r'([A-Z0-9]{1,2})\s?([A-Z0-9]{1,4})\s?([A-Z0-9]{1,3})',
  );
  static final RegExp _hasLetter = RegExp(r'[A-Z]');

  /// Skor minimum agar sebuah temuan dianggap kandidat plat.
  static const int _minCandidateScore = 9;

  static String _fixLetters(String s) =>
      s.split('').map((c) => _toLetterMap[c] ?? c).join();

  static String _fixDigits(String s) =>
      s.split('').map((c) => _toDigitMap[c] ?? c).join();

  static String _compactPlate(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Skor semakin tinggi untuk pola plat yang paling lazim di Indonesia:
  /// 2 huruf wilayah + 4 angka + 2-3 huruf seri, ditulis terpisah spasi.
  static int _scoreCandidate(
    String prefix,
    String digits,
    String suffix, {
    required bool spaced,
  }) {
    var score = 0;
    if (spaced) score += 4;
    score += prefix.length == 2 ? 3 : 2;
    score += switch (digits.length) {
      4 => 6,
      3 => 5,
      2 => 3,
      _ => 1,
    };
    score += switch (suffix.length) {
      3 => 5,
      2 => 4,
      _ => 2,
    };
    // "NO 1 A" dan sejenisnya: dua huruf + satu angka sangat jarang.
    if (prefix.length == 2 && digits.length == 1) score -= 3;
    return score;
  }

  /// Ekstrak semua kandidat plat dari teks OCR mentah, terurut skor.
  static List<String> extractPlateCandidates(String rawText) =>
      _candidatesFromText(rawText).map((c) => c.$1).toList();

  static List<(String, int)> _candidatesFromText(String rawText) {
    if (rawText.trim().isEmpty) return const [];

    final normalized = rawText
        .toUpperCase()
        // Buang baris masa berlaku plat (misal: 08.28, 11-27).
        .replaceAll(RegExp(r'\b\d{2}[./-]\d{2,4}\b'), ' ')
        // OCR kadang menulis plat dengan tanda hubung/titik (BK-9393-RR)
        // atau karakter pengganggu lain; jadikan pemisah spasi.
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return const [];

    final tokens = normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    // Satu baris penuh, tiap token, dan gabungan 2-3 token berurutan agar
    // plat yang terpecah per baris ("BK" / "9393" / "RR") tetap terbaca.
    final sources = <String>{normalized, ...tokens};
    for (var i = 0; i < tokens.length; i++) {
      for (var len = 2; len <= 3 && i + len <= tokens.length; len++) {
        sources.add(tokens.sublist(i, i + len).join(' '));
      }
    }

    final best = <String, int>{};
    for (final source in sources) {
      for (final match in _plateShape.allMatches(source)) {
        final rawPrefix = match.group(1) ?? '';
        final rawSuffix = match.group(3) ?? '';
        // Kode wilayah & seri plat selalu mengandung huruf; token yang murni
        // angka (mis. potongan nomor dokumen) bukan plat.
        if (!_hasLetter.hasMatch(rawPrefix) ||
            !_hasLetter.hasMatch(rawSuffix)) {
          continue;
        }

        final prefix = _fixLetters(rawPrefix);
        final digits = _fixDigits(match.group(2) ?? '');
        final suffix = _fixLetters(rawSuffix);

        if (!_validPrefix.hasMatch(prefix) ||
            !_validDigits.hasMatch(digits) ||
            !_validSuffix.hasMatch(suffix)) {
          continue;
        }

        final plate = '$prefix $digits $suffix';
        if (!isValidPlate(plate)) continue;

        final score = _scoreCandidate(
          prefix,
          digits,
          suffix,
          spaced: match.group(0)!.contains(' '),
        );
        if (score < _minCandidateScore) continue;

        final previous = best[plate];
        if (previous == null || score > previous) best[plate] = score;
      }
    }

    final entries = best.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => (e.key, e.value)).toList();
  }

  /// Kandidat plat terbaik dari teks OCR mentah.
  static String? extractIndonesianPlate(String rawText) {
    final candidates = _candidatesFromText(rawText);
    return candidates.isEmpty ? null : candidates.first.$1;
  }

  static bool _isOneCharSubsequence(String shorter, String longer) {
    if (longer.length - shorter.length != 1) return false;
    var i = 0;
    var j = 0;
    var skipped = false;
    while (i < shorter.length && j < longer.length) {
      if (shorter[i] == longer[j]) {
        i++;
        j++;
      } else if (!skipped) {
        skipped = true;
        j++;
      } else {
        return false;
      }
    }
    return true;
  }

  /// Gabungkan dua pembacaan yang mirip (mis. "BK 939 RR" vs "BK 9393 RR").
  static String? mergeSimilarPlates(String plateA, String plateB) {
    if (plateA == plateB) return plateA;
    final cleanA = _compactPlate(plateA);
    final cleanB = _compactPlate(plateB);

    if (_isOneCharSubsequence(cleanA, cleanB)) return plateB;
    if (_isOneCharSubsequence(cleanB, cleanA)) return plateA;

    final partsA = plateA.split(' ');
    final partsB = plateB.split(' ');
    if (partsA.length == 3 &&
        partsB.length == 3 &&
        partsA[0] == partsB[0] &&
        partsA[1] == partsB[1]) {
      final sufA = partsA[2];
      final sufB = partsB[2];
      if (sufA.length == sufB.length) {
        var diff = 0;
        for (var i = 0; i < sufA.length; i++) {
          if (sufA[i] != sufB[i]) diff++;
        }
        if (diff <= 1) return sufB.length >= sufA.length ? plateB : plateA;
      }
    }
    return null;
  }

  /// Dua plat dianggap satu kendaraan bila sama persis atau hanya berbeda
  /// satu karakter pada posisi yang sama (mis. O/0 atau 8/B hasil OCR).
  static bool isSimilarPlate(String a, String b) {
    final cleanA = _compactPlate(a);
    final cleanB = _compactPlate(b);
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA == cleanB) return true;
    if (cleanA.length != cleanB.length) return false;

    var diff = 0;
    for (var i = 0; i < cleanA.length; i++) {
      if (cleanA[i] != cleanB[i]) {
        diff++;
        if (diff > 1) return false;
      }
    }
    return true;
  }

  /// Suara terbanyak per posisi karakter untuk bacaan-bacaan yang mirip.
  static String? _voteCharacters(List<MapEntry<String, int>> cluster) {
    if (cluster.isEmpty) return null;
    final length = cluster.first.key.length;
    if (cluster.any((e) => e.key.length != length)) return null;

    final result = StringBuffer();
    for (var i = 0; i < length; i++) {
      final counts = <String, int>{};
      for (final entry in cluster) {
        final char = entry.key[i];
        counts[char] = (counts[char] ?? 0) + entry.value;
      }
      final winner = counts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      // Minimal dua frame harus setuju pada karakter tersebut.
      if (winner.value < 2) return null;
      result.write(winner.key);
    }
    return result.toString();
  }

  /// Cari konsensus dari beberapa frame pembacaan.
  ///
  /// - Minimal [minExactVotes] frame membaca plat yang persis sama, atau
  /// - Minimal [minSimilarVotes] frame yang saling mirip (beda maksimal satu
  ///   karakter) sehingga bisa dilakukan voting per karakter.
  ///
  /// Mengembalikan null bila belum ada kesepakatan yang cukup aman.
  static PlateConsensus? consensusPlate(
    List<String> reads, {
    int minExactVotes = 2,
    int minSimilarVotes = 2,
  }) {
    if (reads.isEmpty) return null;

    final counts = <String, int>{};
    for (final read in reads) {
      final clean = _compactPlate(read);
      if (!isValidPlate(clean)) continue;
      counts[clean] = (counts[clean] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final exact =
        counts.entries.where((entry) => entry.value >= minExactVotes).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (exact.isNotEmpty) {
      final winner = exact.first;
      return PlateConsensus(
        plate: formatPlate(winner.key),
        votes: winner.value,
        exactMatch: true,
        confidence: math.min(0.99, 0.93 + 0.02 * winner.value),
      );
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Catatan: cluster dibentuk dari entri yang sudah terurut suara terbanyak,
    // sehingga `cluster.first` adalah bacaan paling dominan.
    for (final seed in entries) {
      final cluster = entries
          .where((entry) => isSimilarPlate(seed.key, entry.key))
          .toList();
      final votes = cluster.fold<int>(0, (sum, entry) => sum + entry.value);
      if (votes < minSimilarVotes) continue;

      // Voting per karakter dipakai bila tiap posisi punya suara mayoritas.
      final voted = _voteCharacters(cluster);
      if (voted != null && isValidPlate(voted)) {
        return PlateConsensus(
          plate: formatPlate(voted),
          votes: votes,
          exactMatch: false,
          confidence: 0.9,
        );
      }

      // OCR kadang menyebar di beberapa posisi sekaligus sehingga voting per
      // karakter gagal (tiap karakter hanya disuarakan satu frame). Asalkan
      // semua bacaan di cluster hanya beda maksimal satu karakter, ambil
      // bacaan dengan suara terbanyak agar plat tetap terkunci tanpa menunggu
      // frame yang persis sama.
      final dominant = cluster.first;
      if (!isValidPlate(dominant.key)) continue;
      return PlateConsensus(
        plate: formatPlate(dominant.key),
        votes: votes,
        exactMatch: false,
        confidence: 0.86,
      );
    }

    return null;
  }

  /// Deteksi plat secara offline on-device memakai Google ML Kit.
  ///
  /// Semua blok teks dinilai, bukan hanya blok pertama, lalu kandidat dengan
  /// skor pola tertinggi yang dipakai. Blok teks yang besar (plat yang lebih
  /// dekat/terlihat jelas di bingkai) mendapat bonus kecil.
  ///
  /// File [filePath] **tidak** dihapus di sini. Pemanggil yang mengelola
  /// siklus hidup file sementara, karena crop yang sama sering dipakai lagi
  /// untuk percobaan warna dibalik (plat hitam berhuruf putih).
  static Future<AnprResult> detectFromImageFile(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognized = await _recognizer.processImage(inputImage);

      final blocks = recognized.blocks;
      final widestBlock = blocks.fold<double>(
        0,
        (widest, block) => math.max(widest, block.boundingBox.width),
      );

      final scored = <String, int>{};
      void collect(String text, {double sizeBonus = 0}) {
        for (final (plate, score) in _candidatesFromText(text)) {
          final total = score + sizeBonus.round();
          final previous = scored[plate];
          if (previous == null || total > previous) scored[plate] = total;
        }
      }

      for (final block in blocks) {
        final width = block.boundingBox.width;
        final bonus = widestBlock <= 0 ? 0.0 : (width / widestBlock) * 6;
        collect(block.text, sizeBonus: bonus);
      }
      collect(recognized.text);

      if (scored.isEmpty) {
        return AnprResult(success: false, rawText: recognized.text);
      }

      final ranked = scored.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final bestPlate = ranked.first;
      return AnprResult(
        success: true,
        plate: bestPlate.key,
        rawText: recognized.text,
        confidence: (0.7 + bestPlate.value * 0.01).clamp(0.7, 0.95),
        candidates: ranked.map((entry) => entry.key).toList(),
      );
    } catch (e) {
      return AnprResult(success: false, error: e.toString());
    }
  }
}
