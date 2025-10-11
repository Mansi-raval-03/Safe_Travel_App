import 'package:audioplayers/audioplayers.dart';

/// Service for managing emergency siren functionality
/// Handles looping siren sound playback with toggle controls
class EmergencySirenService {
  // Singleton pattern
  static final EmergencySirenService _instance = EmergencySirenService._internal();
  factory EmergencySirenService() => _instance;
  EmergencySirenService._internal();

  // Audio player for siren
  final AudioPlayer _sirenPlayer = AudioPlayer();
  
  // State management
  bool _isSirenPlaying = false;
  
  /// Check if siren is currently playing
  bool get isSirenPlaying => _isSirenPlaying;

  /// Toggle siren playback (start if stopped, stop if playing)
  /// 
  /// Returns [true] if siren is now playing, [false] if stopped
  Future<bool> toggleSiren() async {
    if (_isSirenPlaying) {
      await stopSiren();
      return false;
    } else {
      await startSiren();
      return true;
    }
  }

  /// Start playing emergency siren sound (looping)
  Future<void> startSiren() async {
    if (_isSirenPlaying) {
      print('⚠️ Siren already playing');
      return;
    }

    try {
      // Set to loop continuously
      await _sirenPlayer.setReleaseMode(ReleaseMode.loop);
      
      // Set volume to maximum for emergency
      await _sirenPlayer.setVolume(1.0);
      
      // Play siren from assets
      await _sirenPlayer.play(AssetSource('sounds/police-siren-397963.mp3'));
      
      _isSirenPlaying = true;
      print('🚨 Emergency siren started');
    } catch (e) {
      print('⚠️ Siren not available (audio file missing): $e');
      print('💡 Add siren.mp3 to assets/sounds/ folder to enable sound');
      _isSirenPlaying = false;
    }
  }

  /// Stop playing emergency siren sound
  Future<void> stopSiren() async {
    if (!_isSirenPlaying) {
      print('⚠️ Siren not playing');
      return;
    }

    try {
      await _sirenPlayer.stop();
      _isSirenPlaying = false;
      print('🔇 Emergency siren stopped');
    } catch (e) {
      print('❌ Error stopping siren: $e');
    }
  }

  /// Set siren volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _sirenPlayer.setVolume(clampedVolume);
      print('🔊 Siren volume set to ${(clampedVolume * 100).toStringAsFixed(0)}%');
    } catch (e) {
      print('❌ Error setting siren volume: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _sirenPlayer.dispose();
    _isSirenPlaying = false;
  }
}
