import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Supabase-backed SOS sender / live-location helper.
class SosServiceSupabase {
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _locTimer;
  String? _activeSosId;

  SosServiceSupabase._private();
  static final SosServiceSupabase instance = SosServiceSupabase._private();

  /// Send a one-off SOS (creates sos_events row, invokes edge function and starts live updates)
  Future<String?> sendSOS({required String receiverId, required String message}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final inserted = await _supabase
          .from('sos_events')
          .insert({
            'sender_id': user.id,
            'receiver_id': receiverId,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'message': message,
            'is_active': true,
          })
          .select()
          .single();

      final dynamic rawId = inserted['id'];
      final String sosId = rawId == null ? '' : rawId.toString();
      if (sosId.isEmpty) return null;

      // cancel any existing live update timer and start new
      _locTimer?.cancel();
      _activeSosId = sosId;

      // invoke edge function to send FCM (silent server-side send)
      try {
        await _supabase.functions.invoke('send_sos_notification', body: {'sosId': sosId});
      } catch (e) {
        // Edge function may be missing in local dev; log and continue
        // ignore: avoid_print
        print('send_sos_notification invoke failed: $e');
      }

      _startLiveLocationUpdates(sosId);
      return sosId;
    } catch (e) {
      // ignore and bubble up null to caller
      // ignore: avoid_print
      print('sendSOS error: $e');
      return null;
    }
  }

  void _startLiveLocationUpdates(String sosId) {
    _locTimer?.cancel();
    _locTimer = Timer.periodic(const Duration(seconds: 4), (t) async {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        await _supabase.from('sos_live_location').insert({
          'sos_id': sosId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        // continue trying; log for debugging
        // ignore: avoid_print
        print('live update error: $e');
      }
    });
  }

  Future<void> stopSOS() async {
    final id = _activeSosId;
    if (id == null) return;
    await _supabase.from('sos_events').update({'is_active': false}).eq('id', id);
    _locTimer?.cancel();
    _activeSosId = null;
  }
}
