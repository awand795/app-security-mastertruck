import 'package:flutter/services.dart';

String normalizePlate(String? value) {
  if (value == null) return '';
  return value.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

/// Pesan error standar jika nomor polisi tidak sesuai format plat Indonesia.
const String kPlateStandardErrorMessage =
    'Format plat tidak sesuai standar Indonesia (Contoh: B 1234 ABC atau BK 8899 XY).';

/// Validasi plat nomor standar Indonesia:
/// - 1-2 huruf kode wilayah (A-Z)
/// - 1-4 digit angka nomor registrasi (1-9999)
/// - 1-3 huruf seri sub-wilayah (A-Z)
/// Contoh valid: "B 2156 TQR", "BK 8899 XY", "D 1 A"
/// Contoh tidak valid: "BK 7", "asdasd", "12345"
bool isValidPlate(String? value) {
  if (value == null) return false;
  final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (clean.isEmpty) return false;
  return RegExp(r'^[A-Z]{1,2}\d{1,4}[A-Z]{1,3}$').hasMatch(clean);
}

String formatPlate(String? value) {
  if (value == null) return '';
  final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (clean.isEmpty) return '';

  final standardMatch = RegExp(r'^([A-Z]{1,2})(\d{1,4})([A-Z]{0,3})$').firstMatch(clean);
  if (standardMatch != null) {
    final part1 = standardMatch.group(1);
    final part2 = standardMatch.group(2);
    final part3 = standardMatch.group(3);
    final parts = [part1, part2, part3].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(' ');
  }

  final groups = RegExp(r'[A-Z]+|\d+').allMatches(clean).map((m) => m.group(0)).toList();
  return groups.isNotEmpty ? groups.join(' ') : clean;
}

class PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final clean = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final formatted = formatPlate(clean);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
