import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AnprResult {
  final bool success;
  final String? plate;
  final String? rawText;
  final double confidence;
  final String? source;
  final bool isFromYoloBox;
  final Map<String, dynamic>? box;

  AnprResult({
    required this.success,
    this.plate,
    this.rawText,
    this.confidence = 0.0,
    this.source,
    this.isFromYoloBox = false,
    this.box,
  });

  factory AnprResult.fromJson(Map<String, dynamic> json) {
    return AnprResult(
      success: json['success'] == true,
      plate: json['plate']?.toString(),
      rawText: json['rawText']?.toString(),
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0.0,
      source: json['source']?.toString(),
      isFromYoloBox: json['isFromYoloBox'] == true,
      box: json['box'] is Map<String, dynamic> ? json['box'] : null,
    );
  }
}

class AnprService {
  static Future<AnprResult> detectFromBase64(String base64Image) async {
    final url = Uri.parse(ApiConfig.anprServerUrl);

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': 'data:image/jpeg;base64,$base64Image',
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return AnprResult.fromJson(data);
      }
      return AnprResult(success: false);
    } catch (_) {
      return AnprResult(success: false);
    }
  }
}
