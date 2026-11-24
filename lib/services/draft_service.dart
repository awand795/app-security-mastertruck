import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_vehicle_model.dart';
import '../models/booking_candidate_model.dart';

class CheckInDraft {
  final String nopol;
  final String driverName;
  final String driverPhone;
  final String complaint;
  final String notes;
  final String customTipe;
  final String picText;
  final String jenisKedatangan;
  final int? bookingId;
  final String? lokasiKode;
  final String? tujuanKode;
  final String? selectedPic;
  final String? selectedEmployeeId;
  final CheckinCandidate? selectedCandidate;
  final Map<String, String> photos; // angle -> base64

  const CheckInDraft({
    this.nopol = '',
    this.driverName = '',
    this.driverPhone = '',
    this.complaint = '',
    this.notes = '',
    this.customTipe = '',
    this.picText = '',
    this.jenisKedatangan = 'WALK_IN',
    this.bookingId,
    this.lokasiKode,
    this.tujuanKode,
    this.selectedPic,
    this.selectedEmployeeId,
    this.selectedCandidate,
    this.photos = const {},
  });

  bool get isEmpty =>
      nopol.trim().isEmpty &&
      driverName.trim().isEmpty &&
      driverPhone.trim().isEmpty &&
      complaint.trim().isEmpty &&
      notes.trim().isEmpty &&
      customTipe.trim().isEmpty &&
      picText.trim().isEmpty &&
      selectedCandidate == null &&
      selectedPic == null &&
      photos.isEmpty;
}

class CheckOutDraft {
  final String nopol;
  final String notes;
  final String reason;
  final String? lokasiKode;
  final ActiveVehicle? selectedVehicle;
  final Map<String, String> photos; // angle -> base64

  const CheckOutDraft({
    this.nopol = '',
    this.notes = '',
    this.reason = '',
    this.lokasiKode,
    this.selectedVehicle,
    this.photos = const {},
  });

  bool get isEmpty =>
      nopol.trim().isEmpty &&
      notes.trim().isEmpty &&
      reason.trim().isEmpty &&
      selectedVehicle == null &&
      photos.isEmpty;
}

/// Layanan auto-save draft form Check-In & Check-Out secara lokal di perangkat.
///
/// Metadata teks & pilihan disimpan di SharedPreferences (ringan), sedangkan
/// foto disimpan sebagai file JPEG di direktori aplikasi agar tidak membebani
/// XML SharedPreferences maupun memori.
class DraftService {
  static const String _checkInKey = 'draft_checkin_v1';
  static const String _checkOutKey = 'draft_checkout_v1';

  static Future<Directory?> _draftPhotoDir(String subdir) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/draft_photos/$subdir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _savePhotosToDir(
    String subdir,
    Map<String, String> photos,
  ) async {
    final dir = await _draftPhotoDir(subdir);
    if (dir == null) return const {};

    final savedFiles = <String, String>{};
    final validNames = <String>{};

    for (final entry in photos.entries) {
      if (entry.value.isEmpty) continue;
      final safeAngle = entry.key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = '$safeAngle.jpg';
      final file = File('${dir.path}/$fileName');
      try {
        final raw = entry.value.contains(',')
            ? entry.value.split(',').last
            : entry.value;
        final bytes = base64Decode(raw);
        await file.writeAsBytes(bytes, flush: true);
        savedFiles[entry.key] = fileName;
        validNames.add(fileName);
      } catch (_) {}
    }

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : '';
          if (!validNames.contains(name)) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}

    return savedFiles;
  }

  static Future<Map<String, String>> _loadPhotosFromDir(
    String subdir,
    dynamic rawPhotoFiles,
  ) async {
    if (rawPhotoFiles is! Map) return {};
    final dir = await _draftPhotoDir(subdir);
    if (dir == null) return {};

    final result = <String, String>{};
    for (final entry in rawPhotoFiles.entries) {
      final angle = entry.key.toString();
      final fileName = entry.value?.toString() ?? '';
      if (fileName.isEmpty) continue;
      try {
        final file = File('${dir.path}/$fileName');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            result[angle] = base64Encode(bytes);
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<void> _clearDir(String subdir) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/draft_photos/$subdir');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // ── Check-In Draft ────────────────────────────────────────────────────────

  static Future<void> saveCheckInDraft(CheckInDraft draft) async {
    if (draft.isEmpty) {
      await clearCheckInDraft();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final photoFiles = await _savePhotosToDir('checkin', draft.photos);
      final payload = <String, dynamic>{
        'nopol': draft.nopol,
        'driverName': draft.driverName,
        'driverPhone': draft.driverPhone,
        'complaint': draft.complaint,
        'notes': draft.notes,
        'customTipe': draft.customTipe,
        'picText': draft.picText,
        'jenisKedatangan': draft.jenisKedatangan,
        'bookingId': draft.bookingId,
        'lokasiKode': draft.lokasiKode,
        'tujuanKode': draft.tujuanKode,
        'selectedPic': draft.selectedPic,
        'selectedEmployeeId': draft.selectedEmployeeId,
        'selectedCandidate': draft.selectedCandidate?.toJson(),
        'photoFiles': photoFiles,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_checkInKey, jsonEncode(payload));
    } catch (_) {}
  }

  static Future<CheckInDraft?> loadCheckInDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_checkInKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;

      final photos = await _loadPhotosFromDir('checkin', map['photoFiles']);
      final candidateRaw = map['selectedCandidate'];
      final candidate = candidateRaw is Map<String, dynamic>
          ? CheckinCandidate.fromJson(candidateRaw)
          : null;

      final draft = CheckInDraft(
        nopol: (map['nopol'] ?? '').toString(),
        driverName: (map['driverName'] ?? '').toString(),
        driverPhone: (map['driverPhone'] ?? '').toString(),
        complaint: (map['complaint'] ?? '').toString(),
        notes: (map['notes'] ?? '').toString(),
        customTipe: (map['customTipe'] ?? '').toString(),
        picText: (map['picText'] ?? '').toString(),
        jenisKedatangan: (map['jenisKedatangan'] ?? 'WALK_IN').toString(),
        bookingId: map['bookingId'] is int
            ? map['bookingId'] as int
            : int.tryParse(map['bookingId']?.toString() ?? ''),
        lokasiKode: map['lokasiKode']?.toString(),
        tujuanKode: map['tujuanKode']?.toString(),
        selectedPic: map['selectedPic']?.toString(),
        selectedEmployeeId: map['selectedEmployeeId']?.toString(),
        selectedCandidate: candidate,
        photos: photos,
      );
      return draft.isEmpty ? null : draft;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCheckInDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkInKey);
    } catch (_) {}
    await _clearDir('checkin');
  }

  // ── Check-Out Draft ───────────────────────────────────────────────────────

  static Future<void> saveCheckOutDraft(CheckOutDraft draft) async {
    if (draft.isEmpty) {
      await clearCheckOutDraft();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final photoFiles = await _savePhotosToDir('checkout', draft.photos);
      final payload = <String, dynamic>{
        'nopol': draft.nopol,
        'notes': draft.notes,
        'reason': draft.reason,
        'lokasiKode': draft.lokasiKode,
        'selectedVehicle': draft.selectedVehicle?.toJson(),
        'photoFiles': photoFiles,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_checkOutKey, jsonEncode(payload));
    } catch (_) {}
  }

  static Future<CheckOutDraft?> loadCheckOutDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_checkOutKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;

      final photos = await _loadPhotosFromDir('checkout', map['photoFiles']);
      final vehicleRaw = map['selectedVehicle'];
      final vehicle = vehicleRaw is Map<String, dynamic>
          ? ActiveVehicle.fromJson(vehicleRaw)
          : null;

      final draft = CheckOutDraft(
        nopol: (map['nopol'] ?? '').toString(),
        notes: (map['notes'] ?? '').toString(),
        reason: (map['reason'] ?? '').toString(),
        lokasiKode: map['lokasiKode']?.toString(),
        selectedVehicle: vehicle,
        photos: photos,
      );
      return draft.isEmpty ? null : draft;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCheckOutDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkOutKey);
    } catch (_) {}
    await _clearDir('checkout');
  }

  static Future<void> clearAllDrafts() async {
    await clearCheckInDraft();
    await clearCheckOutDraft();
  }
}
