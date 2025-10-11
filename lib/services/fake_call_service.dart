import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Service for managing fake incoming call functionality
/// Handles ringtone playback and call simulation
class FakeCallService {
  // Singleton pattern
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;
  FakeCallService._internal();

  // Audio player for ringtone
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  
  // State management
  bool _isCallActive = false;
  Timer? _delayTimer;
  
  /// Check if a fake call is currently active
  bool get isCallActive => _isCallActive;

  /// Start fake call with 3-second delay
  /// 
  /// Returns a [Future] that completes after the delay
  /// Calls [onCallReceived] callback when the call should be displayed
  Future<void> startFakeCall({
    required Function onCallReceived,
    int delaySeconds = 3,
  }) async {
    if (_isCallActive) {
      print('⚠️ Fake call already active');
      return;
    }

    print('📱 Starting fake call with ${delaySeconds}s delay...');

    // Set delay timer
    _delayTimer = Timer(Duration(seconds: delaySeconds), () async {
      _isCallActive = true;
      
      // Start ringtone
      await _playRingtone();
      
      // Trigger callback to show fake call UI
      onCallReceived();
      
      print('📞 Fake call received!');
    });
  }

  /// Play ringtone sound
  Future<void> _playRingtone() async {
    try {
      // Set to loop
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      
      // Play ringtone from assets
      await _ringtonePlayer.play(AssetSource('sounds/police-siren-397963.mp3'));
      
      print('🔊 Ringtone playing');
    } catch (e) {
      print('⚠️ Ringtone not available (audio file missing): $e');
      print('💡 Add ringtone.mp3 to assets/sounds/ folder to enable sound');
    }
  }

  /// Stop ringtone
  Future<void> stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      print('🔇 Ringtone stopped');
    } catch (e) {
      print('❌ Error stopping ringtone: $e');
    }
  }

  /// Accept the fake call
  /// Stops ringtone and marks call as answered
  Future<void> acceptCall() async {
    await stopRingtone();
    _isCallActive = true;
    print('✅ Fake call accepted');
  }

  /// Decline the fake call
  /// Stops ringtone and ends the call
  Future<void> declineCall() async {
    await stopRingtone();
    _isCallActive = false;
    print('❌ Fake call declined');
  }

  /// End the ongoing call
  Future<void> endCall() async {
    await stopRingtone();
    _isCallActive = false;
    print('📴 Fake call ended');
  }

  /// Cancel the delayed fake call before it starts
  void cancelDelayedCall() {
    _delayTimer?.cancel();
    _delayTimer = null;
    print('⏹️ Fake call cancelled');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _delayTimer?.cancel();
    await _ringtonePlayer.dispose();
    _isCallActive = false;
  }
}
