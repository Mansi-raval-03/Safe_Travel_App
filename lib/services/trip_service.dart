import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_event.dart';
import 'api_service.dart';

class TripService {
  static const String _localKey = 'cached_trips';

  // Save trip locally (unsynced)
  static Future<void> saveLocalTrip(TripEvent trip) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_localKey) ?? [];
    list.add(trip.encode());
    await prefs.setStringList(_localKey, list);
  }

  // Get cached trips
  static Future<List<TripEvent>> getLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_localKey) ?? [];
    return list.map((e) => TripEvent.decode(e)).toList();
  }

  // Clear local cache
  static Future<void> clearLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey);
  }

  // Sync local trips to backend
  static Future<void> syncLocalTrips(String userId, {String? authToken}) async {
    final local = await getLocalTrips();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_localKey) ?? [];
    final remaining = <String>[];
    for (int i = 0; i < local.length; i++) {
      final t = local[i];
      try {
        final body = {
          'userId': userId,
          'title': t.title,
          'startTime': t.startTime.toIso8601String(),
          'endTime': t.endTime.toIso8601String(),
          'destination': t.destination.toJson(),
          'notes': t.notes,
          'modeOfTravel': t.travelMode.apiValue,
        };
        final headers = authToken != null ? {'Authorization': 'Bearer $authToken'} : null;
        final resp = await ApiService.post('/events/create', body, headers: headers);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          // successfully synced, skip adding to remaining
        } else {
          print('Trip sync failed: ${resp.statusCode} ${resp.body}');
          remaining.add(stored[i]);
        }
      } catch (err) {
        print('Trip sync error: $err');
        remaining.add(stored[i]);
      }
    }

    // Persist only remaining (unsynced) items
    await prefs.setStringList(_localKey, remaining);
  }

  // Fetch trips from backend
  static Future<List<TripEvent>> fetchUserTrips(String userId, {String? authToken}) async {
    final headers = authToken != null ? {'Authorization': 'Bearer $authToken'} : null;
    try {
      final resp = await ApiService.get('/events/user/$userId', headers: headers);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List<dynamic>).map((e) => TripEvent.fromJson(e)).toList();
        return list;
      }
      print('Fetch user trips failed: ${resp.statusCode} ${resp.body}');
    } catch (err) {
      print('Error fetching user trips: $err');
    }

    // On any failure, return local cached trips so UI remains populated
    return await getLocalTrips();
  }
}
