import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/gate_model.dart';

class UserSession {
  final String userId;
  final String name;
  final String? idToken;
  final String? sessionId;
  final String? role;
  final String? kodeCabang;
  final String? namaCabang;
  final int? gateId;
  final String? gateCode;
  final String? gateName;
  final DateTime? lastLoginAt;

  UserSession({
    required this.userId,
    required this.name,
    this.idToken,
    this.sessionId,
    this.role,
    this.kodeCabang,
    this.namaCabang,
    this.gateId,
    this.gateCode,
    this.gateName,
    this.lastLoginAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'idToken': idToken,
    'sessionId': sessionId,
    'role': role,
    'kodeCabang': kodeCabang,
    'namaCabang': namaCabang,
    'gateId': gateId,
    'gateCode': gateCode,
    'gateName': gateName,
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    userId: json['userId'] ?? '',
    name: json['name'] ?? '',
    idToken: json['idToken'],
    sessionId: json['sessionId'],
    role: json['role'],
    kodeCabang: json['kodeCabang'],
    namaCabang: json['namaCabang'],
    gateId: json['gateId'] is int
        ? json['gateId'] as int
        : int.tryParse(json['gateId']?.toString() ?? ''),
    gateCode: json['gateCode']?.toString(),
    gateName: json['gateName']?.toString(),
    lastLoginAt: json['lastLoginAt'] != null
        ? DateTime.tryParse(json['lastLoginAt'].toString())
        : null,
  );
}

class AuthService {
  static const String _sessionKey = 'security_user_session';
  static const Duration sessionMaxAge = Duration(days: 2);
  static UserSession? _currentSession;

  static UserSession? get currentSession => _currentSession;
  static bool get isAuthenticated => _currentSession != null;
  static bool get hasGate => _currentSession?.gateId != null;

  static bool isSessionExpired({DateTime? now}) {
    final loginAt = _currentSession?.lastLoginAt;
    if (loginAt == null) return false;
    final ref = now ?? DateTime.now();
    return ref.difference(loginAt) >= sessionMaxAge;
  }

  static Future<void> setSelectedGate(GateModel gate) async {
    final cur = _currentSession;
    if (cur == null) return;
    final updated = UserSession(
      userId: cur.userId,
      name: cur.name,
      idToken: cur.idToken,
      sessionId: cur.sessionId,
      role: cur.role,
      kodeCabang: cur.kodeCabang,
      namaCabang: cur.namaCabang,
      gateId: gate.id,
      gateCode: gate.kodeGate,
      gateName: gate.namaGate,
      lastLoginAt: cur.lastLoginAt,
    );
    _currentSession = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(updated.toJson()));
  }

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null) {
      try {
        _currentSession = UserSession.fromJson(jsonDecode(raw));
        if (isSessionExpired()) {
          _currentSession = null;
          await prefs.remove(_sessionKey);
        }
      } catch (_) {
        _currentSession = null;
      }
    }
  }

  static Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
    String company = 'LPM',
    GateModel? gate,
  }) async {
    // Login melalui API Gateway (API Builder) agar bisa diarahkan ke banyak
    // backend auth tanpa perubahan APK. Gateway yang menyimpan kunci DarkoPOS.
    final url = Uri.parse(
      '${ApiConfig.gatewayBaseUrl}${ApiConfig.securityLoginPath}',
    );

    try {
      var res = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': ApiConfig.gatewayApiKey,
            },
            body: jsonEncode({
              'userid': userId,
              'password': password,
              'company': company,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // Jika 401 dan company terisi, coba fallback tanpa company persis seperti di portal web
      if (res.statusCode == 401 && company.isNotEmpty) {
        res = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-Api-Key': ApiConfig.gatewayApiKey,
              },
              body: jsonEncode({
                'userid': userId,
                'password': password,
                'company': '',
              }),
            )
            .timeout(const Duration(seconds: 10));
      }

      // Bila respons 401 Unauthorized, jangan lakukan jsonDecode dan jangan tampilkan exception teknis
      if (res.statusCode == 401) {
        return {
          'success': false,
          'message': 'User ID atau kata sandi yang Anda masukkan tidak sesuai. Silakan periksa kembali dan coba lagi.',
        };
      }

      if (res.statusCode == 403) {
        return {
          'success': false,
          'message':
              'Akun Anda tidak memiliki izin akses ke portal keamanan gerbang.',
        };
      }

      if (res.statusCode == 404) {
        return {
          'success': false,
          'message': 'Layanan autentikasi POS sedang tidak tersedia. Silakan hubungi tim administrator bengkel.',
        };
      }

      if (res.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Terjadi kendala pada server sistem POS. Silakan coba kembali beberapa saat lagi.',
        };
      }

      if (res.statusCode != 200) {
        return {
          'success': false,
          'message': 'Gagal masuk ke sistem. Silakan periksa kembali data akun Anda atau coba beberapa saat lagi.',
        };
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'message': 'User ID atau kata sandi yang Anda masukkan tidak sesuai. Silakan periksa kembali dan coba lagi.',
        };
      }

      if (data['token'] != null ||
          data['idToken'] != null ||
          data['success'] == true) {
        final idToken = data['idToken'] ?? data['token'];
        final sessionId = data['sessionId'];
        final name = data['name'] ?? data['fullname'] ?? userId;

        final session = UserSession(
          userId: userId,
          name: name.toString(),
          idToken: idToken?.toString(),
          sessionId: sessionId?.toString(),
          role: data['role']?.toString() ?? 'SECURITY',
          gateId: gate?.id,
          gateCode: gate?.kodeGate,
          gateName: gate?.namaGate,
          lastLoginAt: DateTime.now(),
        );

        _currentSession = session;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

        return {'success': true, 'session': session};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'User ID atau kata sandi yang Anda masukkan tidak sesuai. Silakan periksa kembali dan coba lagi.',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Waktu koneksi ke server POS habis. Pastikan jaringan internet stabil dan coba kembali.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server autentikasi POS. Pastikan koneksi internet stabil atau hubungi tim sistem.',
      };
    }
  }

  static Future<void> logout() async {
    final token = _currentSession?.idToken;
    final sessionId = _currentSession?.sessionId;

    // Logout juga via API Gateway (darkosync) agar backend auth konsisten
    // dan bisa diganti tanpa ubah APK. Token user diteruskan sebagai param.
    try {
      final url = Uri.parse(
        '${ApiConfig.gatewayBaseUrl}${ApiConfig.securityLogoutPath}',
      );
      await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': ApiConfig.gatewayApiKey,
            },
            body: jsonEncode({
              'token': token ?? '',
              'sessionId': sessionId ?? '',
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
