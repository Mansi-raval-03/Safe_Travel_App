import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Full-screen SOS alert UI.
/// - Plays a looping audio alarm (from assets)
/// - Subscribes to `sos_live_location` Supabase stream and updates marker/camera
class SosAlertScreen extends StatefulWidget {
  final String sosId;
  final String senderName;
  final String message;
  final double initialLat;
  final double initialLng;

  const SosAlertScreen({
    required this.sosId,
    required this.senderName,
    required this.message,
    required this.initialLat,
    required this.initialLng,
    Key? key,
  }) : super(key: key);

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  AudioPlayer? _player;
  GoogleMapController? _mapController;
  LatLng _pos = const LatLng(0, 0);
  Set<Marker> _markers = {};

  StreamSubscription<List<Map<String, dynamic>>>? _liveSub;

  @override
  void initState() {
    super.initState();
    _pos = LatLng(widget.initialLat, widget.initialLng);
    _markers = {Marker(markerId: const MarkerId('sender'), position: _pos)};
    _startAlarm();
    _subscribeLiveLocation();
  }

  Future<void> _startAlarm() async {
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/police-siren-397963.mp3'));
      // simple haptic feedback as a fallback
      HapticFeedback.vibrate();
    } catch (e) {
      // ignore on platforms where audio/haptics aren't available
    }
  }

  void _subscribeLiveLocation() {
    final supabase = Supabase.instance.client;

    final stream = supabase
        .from('sos_live_location')
        .stream(primaryKey: ['id'])
        .eq('sos_id', widget.sosId);

    _liveSub = stream.listen((rows) {
      try {
        if (rows.isEmpty) return;
        final last = rows.last;
        final lat = (last['latitude'] as num).toDouble();
        final lng = (last['longitude'] as num).toDouble();
        final pos = LatLng(lat, lng);
        setState(() {
          _pos = pos;
          _markers = {Marker(markerId: const MarkerId('sender'), position: _pos)};
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pos, 16));
      } catch (e) {
        // parsing error — ignore
      }
    });
  }

  @override
  void dispose() {
    try {
      _player?.stop();
      _player?.dispose();
      _player = null;
    } catch (e) {}
    try {
      _liveSub?.cancel();
      _liveSub = null;
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS from ${widget.senderName}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(widget.message, style: const TextStyle(color: Colors.white70, fontSize: 16), overflow: TextOverflow.ellipsis, maxLines: 2),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _pos, zoom: 16),
                markers: _markers,
                onMapCreated: (c) => _mapController = c,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // TODO: implement call action — open dialer with sender phone if available
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Call Sender'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: implement navigation intent to sender location
                      },
                      child: const Text('Navigate'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

