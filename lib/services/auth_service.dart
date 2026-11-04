import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UserSession {
  final String userId;
  final String name;
  final String? idToken;
  final String? sessionId;
  final String? role;
  final String? kodeCabang;
  final String? namaCabang;

  UserSession({
    required this.userId,
    required this.name,
    this.idToken,
    this.sessionId,
    this.role,
    this.kodeCabang,
    this.namaCabang,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'idToken': idToken,
    'sessionId': sessionId,
    'role': role,
    'kodeCabang': kodeCabang,
    'namaCabang': namaCabang,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    userId: json['userId'] ?? '',
    name: json['name'] ?? '',
    idToken: json['idToken'],
    sessionId: json['sessionId'],
    role: json['role'],
    kodeCabang: json['kodeCabang'],
    namaCabang: json['namaCabang'],
  );
}

class AuthService {
  static const String _sessionKey = 'security_user_session';
  static UserSession? _currentSession;

  static UserSession? get currentSession => _currentSession;
  static bool get isAuthenticated => _currentSession != null;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null) {
      try {
        _currentSession = UserSession.fromJson(jsonDecode(raw));
      } catch (_) {
        _currentSession = null;
      }
    }
  }

  static Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
    String company = 'LPM',
  }) async {
    final url = Uri.parse('${ApiConfig.darkoPosBaseUrl}/api/v1/users/login');

    try {
      var res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiConfig.darkoPosApiKey,
        },
        body: jsonEncode({
          'userid': userId,
          'password': password,
          'company': company,
        }),
      ).timeout(const Duration(seconds: 10));

      // Jika 401 dan company terisi, coba fallback tanpa company persis seperti di portal web
      if (res.statusCode == 401 && company.isNotEmpty) {
        res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConfig.darkoPosApiKey,
          },
          body: jsonEncode({
            'userid': userId,
            'password': password,
            'company': '',
          }),
        ).timeout(const Duration(seconds: 10));
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
          'message': 'Akun Anda tidak memiliki izin akses ke portal keamanan gerbang.',
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

      if (data['token'] != null || data['idToken'] != null || data['success'] == true) {
        final idToken = data['idToken'] ?? data['token'];
        final sessionId = data['sessionId'];
        final name = data['name'] ?? data['fullname'] ?? userId;

        final session = UserSession(
          userId: userId,
          name: name.toString(),
          idToken: idToken?.toString(),
          sessionId: sessionId?.toString(),
          role: data['role']?.toString() ?? 'SECURITY',
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

    if (token != null) {
      try {
        final url = Uri.parse('${ApiConfig.darkoPosBaseUrl}/api/v1/users/logout');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'JWT $token',
          },
          body: jsonEncode({'sessionId': sessionId ?? ''}),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
