import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

class GooglePlacesService {
  // Replace with your Google API key. For security, store this in a secure place or use build-time env vars.
  static const String apiKey = 'https://maps.googleapis.com/maps/api/js?key=AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao&libraries=places&callback=initMap';
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
    final uri = Uri.parse(_base).replace(queryParameters: {
      'key': apiKey,
      'location': '$lat,$lng',
      'radius': radiusMeters.toString(),
      'type': type,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Places API error: ${resp.statusCode}');
    final Map<String, dynamic> body = json.decode(resp.body);
    final status = body['status'];
    if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception('Places API status: $status');
    }
    final results = (body['results'] as List<dynamic>? ) ?? [];
    return results.map((e) => PlaceModel.fromJson(e)).toList();
  }
}
