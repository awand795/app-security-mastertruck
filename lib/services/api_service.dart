import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/active_vehicle_model.dart';
import '../models/booking_candidate_model.dart';
import '../models/employee_model.dart';
import '../models/gate_model.dart';
import '../models/lokasi_model.dart';
import '../models/memo_keluar_model.dart';
import '../models/set_foto_model.dart';
import '../models/tujuan_kedatangan_model.dart';

class ApiService {
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Api-Key': ApiConfig.gatewayApiKey,
  };

  // 0. Get Active Gates from Database
  static Future<List<GateModel>> getGates() async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/gates',
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['data'] is List)
            ? data['data']
            : data;
        if (list is List) {
          return list
              .map((e) => GateModel.fromJson(e as Map<String, dynamic>))
              .where((g) => g.isActive && g.namaGate.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 0a. Get Active Lokasi from Database
  static Future<List<LokasiItem>> getLokasi() async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/lokasi',
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['data'] is List)
            ? data['data']
            : data;
        if (list is List) {
          return list
              .map((e) => LokasiItem.fromJson(e as Map<String, dynamic>))
              .where((l) => l.isActive && l.kodeLokasi.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 0b. Get Active Tujuan Kedatangan from Database
  static Future<List<TujuanKedatanganItem>> getTujuanKedatangan() async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/tujuan-kedatangan',
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['data'] is List)
            ? data['data']
            : data;
        if (list is List) {
          return list
              .map(
                (e) => TujuanKedatanganItem.fromJson(e as Map<String, dynamic>),
              )
              .where((t) => t.isActive && t.namaTujuan.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 0c. Get Active Set Foto Configuration from Database
  static Future<List<SetFotoItem>> getSetFoto() async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/set-foto',
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['data'] is List)
            ? data['data']
            : data;
        if (list is List) {
          return list
              .map((e) => SetFotoItem.fromJson(e as Map<String, dynamic>))
              .where((f) => f.isActive && f.kodeFoto.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 1. Search Check-in Candidates (Booking + Registered Members)
  static Future<List<CheckinCandidate>> searchCandidates(String query) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/checkin-candidates',
    ).replace(queryParameters: {'q': query});

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((e) => CheckinCandidate.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 2. Submit Check-in
  static Future<Map<String, dynamic>> postCheckIn({
    required String noPolisi,
    required String namaPengemudi,
    required String noTeleponPengemudi,
    required String tipeKunjungan,
    String? subTujuan,
    required String keluhan,
    required String petugasSecurity,
    int? bookingId,
    String? picTujuan,
    String? jenisKedatangan,
    String? catatanMasuk,
    int? gateMasukId,
    String? gateMasukName,
    String? lokasiKode,
    String? lokasiNama,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/check-in',
    );

    try {
      final res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'no_polisi': noPolisi,
              'nama_pengemudi': namaPengemudi,
              'no_telepon_pengemudi': noTeleponPengemudi,
              'tipe_kunjungan': tipeKunjungan,
              'sub_tujuan': subTujuan ?? tipeKunjungan,
              'keluhan': keluhan,
              'petugas_security': petugasSecurity,
              'booking_id': bookingId,
              'pic_tujuan': picTujuan,
              'jenis_kedatangan': jenisKedatangan ?? 'WALK_IN',
              'catatan_masuk': catatanMasuk ?? '',
              'gate_masuk_id': gateMasukId,
              'gate_masuk_nama': gateMasukName,
              'lokasi_kode': lokasiKode,
              'lokasi_nama': lokasiNama,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      final raw = (data is Map && data['data'] != null) ? data['data'] : data;
      final result = (raw is List && raw.isNotEmpty) ? raw[0] : raw;

      return {
        'success':
            result['success'] == true ||
            result['kunjungan_id'] != null ||
            result['id'] != null,
        'kunjungan_id': result['kunjungan_id'] ?? result['id'],
        'nomor_tiket':
            result['nomor_tiket'] ??
            result['ticket_no'] ??
            'TKT-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'is_reenter': result['is_reenter'] == true,
        'message': result['message'] ?? 'Check-in berhasil dicatat.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal check-in: $e'};
    }
  }

  // 3. Upload Multi-Camera Foto (Depan, Belakang, Kiri, Kanan)
  static Future<bool> postAddFoto({
    required int kunjunganId,
    required String jenisEvent, // 'MASUK' | 'KELUAR'
    required String sudutPandang, // 'DEPAN', 'BELAKANG', 'KIRI', 'KANAN'
    required String base64Image,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/add-foto',
    );

    try {
      final res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'kunjungan_id': kunjunganId,
              'jenis_event': jenisEvent,
              'sudut_pandang': sudutPandang,
              'foto_data': base64Image.startsWith('data:')
                  ? base64Image
                  : 'data:image/jpeg;base64,$base64Image',
            }),
          )
          .timeout(const Duration(seconds: 12));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 4. Get Active Vehicles inside workshop (DI_BENGKEL + KELUAR_SEMENTARA)
  static Future<List<ActiveVehicle>> getActiveInside({
    String query = '',
    String statusFilter = '',
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.gatewayBaseUrl}/mastertruck/security/active-inside',
        ).replace(
          queryParameters: {
            'q': query,
            if (statusFilter.isNotEmpty) 'status_filter': statusFilter,
          },
        );

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((e) => ActiveVehicle.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 4b. Re-enter vehicle with status KELUAR_SEMENTARA
  static Future<Map<String, dynamic>> postReEnter({
    required int kunjunganId,
    required String petugasSecurity,
    int? gateMasukId,
    String? gateMasukName,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/re-enter',
    );
    try {
      final res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'kunjungan_id': kunjunganId,
              'petugas_security': petugasSecurity,
              'gate_masuk_id': gateMasukId,
              'gate_masuk_nama': gateMasukName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final raw = (data is Map && data['data'] != null) ? data['data'] : data;
      final result = (raw is List && raw.isNotEmpty) ? raw[0] : raw;
      return {
        'success': result['success'] == true,
        'message': result['message'] ?? 'Unit berhasil masuk kembali.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal memproses masuk kembali: $e'};
    }
  }

  // 5. Submit Check-out
  static Future<Map<String, dynamic>> postCheckOut({
    required int kunjunganId,
    required String petugasSecurityKeluar,
    String catatanKeluar = '',
    String alasanKeluar = '',
    int? gateKeluarId,
    String? gateKeluarName,
    String? lokasiKode,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/check-out',
    );

    try {
      final res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'kunjungan_id': kunjunganId,
              'id': kunjunganId,
              'petugas_security': petugasSecurityKeluar,
              'petugas_security_keluar': petugasSecurityKeluar,
              'catatan_keluar': catatanKeluar,
              'alasan_keluar': alasanKeluar,
              'gate_keluar_id': gateKeluarId,
              'gate_keluar_nama': gateKeluarName,
              'lokasi_kode': lokasiKode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      final raw = (data is Map && data['data'] != null) ? data['data'] : data;
      final result = (raw is List && raw.isNotEmpty) ? raw[0] : raw;

      return {
        'success': result['success'] == true || result['nomor_memo'] != null,
        'nomor_memo':
            result['nomor_memo'] ??
            result['memo_no'] ??
            'MEMO-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'status_kunjungan': result['status_kunjungan']?.toString() ?? 'SELESAI',
        'alasan_keluar': result['alasan_keluar']?.toString(),
        'gate_masuk_nama': result['gate_masuk_nama']?.toString(),
        'gate_keluar_nama': result['gate_keluar_nama']?.toString(),
        'message':
            result['message'] ??
            'Kendaraan berhasil di-checkout. Gate Pass terbit.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal check-out: $e'};
    }
  }

  // 6. Get Memo Keluar History (Today's exits)
  static Future<List<MemoKeluar>> getMemoKeluar({String query = ''}) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/memo-keluar',
    ).replace(queryParameters: {'q': query});

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((e) => MemoKeluar.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 7. Get Employee list for PIC dropdown
  static Future<List<EmployeeItem>> getEmployees({String query = ''}) async {
    final uri = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}/mastertruck/security/employees',
    ).replace(queryParameters: query.isNotEmpty ? {'q': query} : null);

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map((e) => EmployeeItem.fromJson(e as Map<String, dynamic>))
              .where((emp) => emp.name.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
