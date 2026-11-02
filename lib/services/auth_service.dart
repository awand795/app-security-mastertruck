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
    String company = '',
  }) async {
    final url = Uri.parse('${ApiConfig.darkoPosBaseUrl}/api/v1/users/login');

    try {
      final res = await http.post(
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

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && (data['token'] != null || data['idToken'] != null || data['success'] == true)) {
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
          'message': data['message'] ?? 'User ID atau password salah.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke server DarkoPOS: $e',
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
