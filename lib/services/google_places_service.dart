import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

class GooglePlacesService {
  // API key: prefer supplying via --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY at build/run time.
  // This reads the key at compile time from Dart environment variables. If not provided,
  // the code will attempt to read the manifest meta-data via platform channel.
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
  static const MethodChannel _channel = MethodChannel('safe_travel_app/config');

  /// Resolve the effective API key to use for Places requests.
  /// Preference order:
  /// 1. Compile-time `--dart-define=GOOGLE_PLACES_API_KEY=...`
  /// 2. Android manifest meta-data `com.google.android.geo.API_KEY` (via platform channel)
  /// 3. Fallback placeholder string (will cause REQUEST_DENIED from the API).
  static Future<String> resolvedApiKey() async {
    if (apiKey.isNotEmpty) {
      return apiKey;
    }
    try {
      final String? key = await _channel.invokeMethod<String>('getMapsApiKey');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return apiKey;
  }
  static const String _base = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Fetch nearby places of a given [type] around [lat],[lng] within [radiusMeters].
  /// Optionally provide [keyword] to filter results by text.
  static Future<List<PlaceModel>> nearbySearch({
    required double lat,
    required double lng,
    required String type,
    int radiusMeters = 2000,
    String? keyword,
  }) async {
    final effectiveKey = await resolvedApiKey();
    final uri = Uri.parse(_base).replace(queryParameters: {
      'key': effectiveKey,
      'location': '$lat,$lng',
      'radius': radiusMeters.toString(),
      'type': type,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Places API HTTP error: ${resp.statusCode} ${resp.body}');
    final Map<String, dynamic> body = json.decode(resp.body);
    final status = body['status'];
    if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
      final err = body['error_message'] ?? '';
      // Provide a clearer message for common issues.
      if (status == 'REQUEST_DENIED') {
        throw Exception('Places API status: REQUEST_DENIED - ${err.isNotEmpty ? err : 'The provided API key is invalid or restricted.'}');
      }
      throw Exception('Places API status: $status ${err.isNotEmpty ? "- $err" : ''}');
    }
    final results = (body['results'] as List<dynamic>? ) ?? [];
    return results.map((e) => PlaceModel.fromJson(e)).toList();
  }

  /// Test whether the resolved API key is valid by performing a lightweight nearby search.
  /// Returns a map with `{ok: bool, status: String, message: String?}` to allow callers
  /// to present clearer UI errors.
  static Future<Map<String, dynamic>> testApiKey({double? lat, double? lng}) async {
    try {
      final key = await resolvedApiKey();
      if (key.isEmpty || key.startsWith('AIzaSyCthvrA0JDPHBJ5KCax_4nODlXxZLEnNFw')) {
        return {'ok': false, 'status': 'NO_KEY', 'message': 'No API key provided (use --dart-define or manifest).'};
      }

      // Use a fallback coordinate if none provided (central London) — only for key testing.
      final testLat = lat ?? 51.5074;
      final testLng = lng ?? -0.1278;

      final uri = Uri.parse(_base).replace(queryParameters: {
        'key': key,
        'location': '$testLat,$testLng',
        'radius': '100',
        'type': 'hospital',
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        return {'ok': false, 'status': 'HTTP_ERROR', 'message': 'HTTP ${resp.statusCode}'};
      }
      final Map<String, dynamic> body = json.decode(resp.body);
      final status = body['status'] as String? ?? '';
      if (status == 'OK' || status == 'ZERO_RESULTS') {
        return {'ok': true, 'status': status};
      }
      final err = body['error_message'] as String?;
      return {'ok': false, 'status': status, 'message': err};
    } catch (e) {
      return {'ok': false, 'status': 'EXCEPTION', 'message': e.toString()};
    }
  }
}
