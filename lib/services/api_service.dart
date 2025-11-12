import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Update base URL if needed
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

  static Future<http.Response> post(String path, Map<String, dynamic> body, {Map<String, String>? headers}) {
    final url = Uri.parse('$baseUrl$path');
    return http.post(url, body: jsonEncode(body), headers: {
      'Content-Type': 'application/json',
      ...?headers,
    });
  }

  static Future<http.Response> get(String path, {Map<String, String>? headers}) {
    final url = Uri.parse('$baseUrl$path');
    return http.get(url, headers: {
      'Content-Type': 'application/json',
      ...?headers,
    });
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body, {Map<String, String>? headers}) {
    final url = Uri.parse('$baseUrl$path');
    return http.patch(url, body: jsonEncode(body), headers: {
      'Content-Type': 'application/json',
      ...?headers,
    });
  }
}
