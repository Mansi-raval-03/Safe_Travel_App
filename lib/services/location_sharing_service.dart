import 'dart:async';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'native_location_sharing_service.dart';

/// Service for managing location sharing with time limitations
class LocationSharingService {
  static final LocationSharingService _instance = LocationSharingService._internal();
  factory LocationSharingService() => _instance;
  LocationSharingService._internal();

  final LocationService _locationService = LocationService();
  final NativeLocationSharingService _nativeSharing = NativeLocationSharingService();
  
  // Sharing session state
  bool _isSharingActive = false;
  DateTime? _sharingStartTime;
  Duration? _sharingDuration;
  Timer? _sharingTimer;
  String? _currentSharingSessionId;
  
  // Sharing configuration
  SharingPrivacyLevel _privacyLevel = SharingPrivacyLevel.friends;
  bool _includeSpeedAndHeading = true;
  bool _allowRealTimeUpdates = true;
  
  // Streams for real-time updates
  final StreamController<LocationSharingStatus> _sharingStatusController = 
      StreamController<LocationSharingStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _locationUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isSharingActive => _isSharingActive;
  DateTime? get sharingStartTime => _sharingStartTime;
  Duration? get sharingDuration => _sharingDuration;
  String? get currentSharingSessionId => _currentSharingSessionId;
  SharingPrivacyLevel get privacyLevel => _privacyLevel;
  
  Stream<LocationSharingStatus> get sharingStatusStream => _sharingStatusController.stream;
  Stream<Map<String, dynamic>> get locationUpdateStream => _locationUpdateController.stream;
  
  Duration? get remainingSharingTime {
    if (_sharingStartTime == null || _sharingDuration == null) return null;
    final elapsed = DateTime.now().difference(_sharingStartTime!);
    final remaining = _sharingDuration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Start location sharing with specified duration and settings
  Future<LocationSharingResult> startLocationSharing({
    required Duration duration,
    SharingPrivacyLevel privacyLevel = SharingPrivacyLevel.friends,
    bool includeSpeedAndHeading = true,
    bool allowRealTimeUpdates = true,
    String? customMessage,
  }) async {
    try {
      if (_isSharingActive) {
        return LocationSharingResult(
          success: false,
          message: 'Location sharing is already active',
          sessionId: _currentSharingSessionId,
        );
      }

      // Ensure location service is initialized and tracking
      if (!_locationService.isInitialized) {
        bool initialized = await _locationService.initialize();
        if (!initialized) {
          return LocationSharingResult(
            success: false,
            message: 'Failed to initialize location service',
          );
        }
      }

      // Check if location is accurate enough for sharing
      if (!_locationService.isLocationAccurateForSharing()) {
        return LocationSharingResult(
          success: false,
          message: 'Location accuracy is too poor for reliable sharing (${_locationService.getAccuracyDescription()})',
        );
      }

      // Configure sharing settings
      _privacyLevel = privacyLevel;
      _includeSpeedAndHeading = includeSpeedAndHeading;
      _allowRealTimeUpdates = allowRealTimeUpdates;
      
      // Start sharing session
      _isSharingActive = true;
      _sharingStartTime = DateTime.now();
      _sharingDuration = duration;
      _currentSharingSessionId = _generateSessionId();
      
      // Start location tracking if not already active
      if (!_locationService.isTracking) {
        _locationService.startLocationTracking(duration: duration);
      }
      
      // Set up sharing timer
      _sharingTimer = Timer(duration, () {
        print('⏰ Location sharing duration expired');
        stopLocationSharing();
      });
      
      // Listen to location updates for real-time sharing
      if (_allowRealTimeUpdates) {
        _locationService.locationStream.listen(_handleLocationUpdate);
      }
      
      // Notify status change
      _sharingStatusController.add(LocationSharingStatus(
        isActive: true,
        startTime: _sharingStartTime!,
        duration: duration,
        sessionId: _currentSharingSessionId!,
        privacyLevel: privacyLevel,
      ));
      
      print('✅ Location sharing started successfully for ${duration.inMinutes} minutes');
      return LocationSharingResult(
        success: true,
        message: 'Location sharing started for ${duration.inMinutes} minutes',
        sessionId: _currentSharingSessionId,
        sharingLink: generateSharingLink(),
      );
      
    } catch (e) {
      print('❌ Error starting location sharing: $e');
      return LocationSharingResult(
        success: false,
        message: 'Failed to start location sharing: $e',
      );
    }
  }

  /// Stop location sharing
  void stopLocationSharing() {
    if (!_isSharingActive) {
      print('⚠️  Location sharing is not active');
      return;
    }

    print('🛑 Stopping location sharing...');
    
    _sharingTimer?.cancel();
    _sharingTimer = null;
    
    _isSharingActive = false;
    final endTime = DateTime.now();
    final actualDuration = _sharingStartTime != null 
        ? endTime.difference(_sharingStartTime!)
        : Duration.zero;
    
    // Notify status change
    _sharingStatusController.add(LocationSharingStatus(
      isActive: false,
      startTime: _sharingStartTime,
      duration: _sharingDuration,
      actualDuration: actualDuration,
      endTime: endTime,
      sessionId: _currentSharingSessionId,
      privacyLevel: _privacyLevel,
    ));
    
    _sharingStartTime = null;
    _sharingDuration = null;
    _currentSharingSessionId = null;
    
    print('✅ Location sharing stopped successfully');
  }

  /// Generate a unique sharing session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'share_${timestamp}_$random';
  }

  /// Handle location updates for real-time sharing
  void _handleLocationUpdate(Position position) {
    if (!_isSharingActive || !_allowRealTimeUpdates) return;
    
    final locationData = _formatLocationData(position);
    _locationUpdateController.add(locationData);
    
    // Log update for debugging
    print('📡 Sharing location update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
  }

  /// Format location data based on privacy settings
  Map<String, dynamic> _formatLocationData(Position position) {
    Map<String, dynamic> data = {
      'sessionId': _currentSharingSessionId,
      'timestamp': position.timestamp.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'privacyLevel': _privacyLevel.name,
    };

    // Add optional data based on settings
    if (_includeSpeedAndHeading) {
      data['speed'] = position.speed;
      data['heading'] = position.heading;
    }

    // Add privacy-appropriate data
    switch (_privacyLevel) {
      case SharingPrivacyLevel.public:
        data['altitude'] = position.altitude;
        break;
      case SharingPrivacyLevel.friends:
        if (position.speed > 1.0) { // Only include altitude if moving
          data['altitude'] = position.altitude;
        }
        break;
      case SharingPrivacyLevel.family:
        data['altitude'] = position.altitude;
        data['accuracyDescription'] = _locationService.getAccuracyDescription();
        break;
      case SharingPrivacyLevel.emergency:
        data['altitude'] = position.altitude;
        data['accuracyDescription'] = _locationService.getAccuracyDescription();
        data['isEmergency'] = true;
        break;
    }

    return data;
  }

  /// Generate shareable location link
  String generateSharingLink() {
    final position = _locationService.currentPosition;
    if (position == null || !_isSharingActive) return '';

    final lat = position.latitude;
    final lng = position.longitude;
    
    // Create a comprehensive sharing link
    final baseUrl = 'https://maps.google.com/maps';
    final params = [
      'q=$lat,$lng',
      'll=$lat,$lng',
      'z=15',
    ].join('&');
    
    return '$baseUrl?$params';
  }

  /// Share location via platform sharing (legacy text-based)
  Future<void> shareLocationWithPlatform({String? customMessage}) async {
    try {
      if (!_isSharingActive) {
        throw Exception('Location sharing is not active');
      }

      final position = _locationService.currentPosition;
      if (position == null) {
        throw Exception('No current location available');
      }

      final remainingTime = remainingSharingTime;
      final timeText = remainingTime != null 
          ? '${remainingTime.inMinutes} minutes remaining'
          : 'Active';

      final message = customMessage ?? 
          'I\'m sharing my live location with you. $timeText\n\n'
          'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
          'Accuracy: ${_locationService.getAccuracyDescription()}\n'
          'Updated: ${DateTime.now().toString().substring(0, 19)}\n\n'
          '${generateSharingLink()}\n\n'
          'Shared via Safe Travel App';

      await Share.share(
        message,
        subject: 'Live Location Sharing - Safe Travel',
      );

      print('✅ Location shared successfully via platform');
    } catch (e) {
      print('❌ Error sharing location: $e');
      throw e;
    }
  }

  /// Share location via specific app with native location support
  Future<bool> shareLocationViaApp(String appId, {String? customMessage}) async {
    try {
      if (!_isSharingActive) {
        throw Exception('Location sharing is not active');
      }

      final position = _locationService.currentPosition;
      if (position == null) {
        throw Exception('No current location available');
      }

      final remainingTime = remainingSharingTime;
      final timeText = remainingTime != null 
          ? '${remainingTime.inMinutes} minutes remaining'
          : 'Active';

      final message = customMessage ?? 
          'I\'m sharing my live location with you! $timeText\n'
          'Safe Travel App - Emergency Location Sharing';

      final success = await _nativeSharing.shareLocationViaApp(appId, position, message: message);
      
      if (success) {
        print('✅ Location shared successfully via $appId');
      } else {
        print('❌ Failed to share location via $appId');
      }

      return success;
    } catch (e) {
      print('❌ Error sharing location via $appId: $e');
      return false;
    }
  }

  /// Get available sharing options for current platform
  Future<List<SharingOption>> getAvailableSharingOptions() async {
    return await _nativeSharing.getAvailableSharingOptions();
  }

  /// Check if a specific app is available for sharing
  Future<bool> isAppAvailableForSharing(String appId) async {
    return await _nativeSharing.isAppAvailable(appId);
  }

  /// Copy location link to clipboard
  Future<void> copyLocationLinkToClipboard() async {
    try {
      final link = generateSharingLink();
      if (link.isEmpty) {
        throw Exception('No sharing link available');
      }

      await Clipboard.setData(ClipboardData(text: link));
      print('✅ Location link copied to clipboard');
    } catch (e) {
      print('❌ Error copying to clipboard: $e');
      throw e;
    }
  }

  /// Get sharing status for UI display
  Map<String, dynamic> getSharingStatus() {
    return {
      'isActive': _isSharingActive,
      'startTime': _sharingStartTime?.toIso8601String(),
      'duration': _sharingDuration?.inMinutes,
      'remainingTime': remainingSharingTime?.inMinutes,
      'sessionId': _currentSharingSessionId,
      'privacyLevel': _privacyLevel.name,
      'settings': {
        'includeSpeedAndHeading': _includeSpeedAndHeading,
        'allowRealTimeUpdates': _allowRealTimeUpdates,
      },
      'currentLocation': _locationService.getLocationSharingData(),
    };
  }

  /// Update sharing privacy level
  void updatePrivacyLevel(SharingPrivacyLevel newLevel) {
    if (_privacyLevel != newLevel) {
      _privacyLevel = newLevel;
      print('🔐 Privacy level updated to: ${newLevel.name}');
      
      // Notify status change if sharing is active
      if (_isSharingActive) {
        _sharingStatusController.add(LocationSharingStatus(
          isActive: true,
          startTime: _sharingStartTime!,
          duration: _sharingDuration!,
          sessionId: _currentSharingSessionId!,
          privacyLevel: _privacyLevel,
        ));
      }
    }
  }

  /// Extend current sharing session
  Future<bool> extendSharingSession(Duration additionalTime) async {
    if (!_isSharingActive) {
      print('❌ No active sharing session to extend');
      return false;
    }

    try {
      // Cancel current timer
      _sharingTimer?.cancel();
      
      // Update duration
      _sharingDuration = _sharingDuration! + additionalTime;
      
      // Set new timer
      final remainingTime = remainingSharingTime;
      if (remainingTime != null && remainingTime > Duration.zero) {
        _sharingTimer = Timer(remainingTime, () {
          print('⏰ Extended location sharing duration expired');
          stopLocationSharing();
        });
        
        print('⏱️  Sharing session extended by ${additionalTime.inMinutes} minutes');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error extending sharing session: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    print('🧹 Disposing location sharing service...');
    stopLocationSharing();
    _sharingStatusController.close();
    _locationUpdateController.close();
    print('✅ Location sharing service disposed');
  }
}

/// Privacy levels for location sharing
enum SharingPrivacyLevel {
  public,     // Share with anyone (minimal privacy)
  friends,    // Share with friends (moderate privacy)
  family,     // Share with family (high detail)
  emergency,  // Emergency sharing (maximum detail)
}

/// Location sharing result
class LocationSharingResult {
  final bool success;
  final String message;
  final String? sessionId;
  final String? sharingLink;
  final DateTime? startTime;

  LocationSharingResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.sharingLink,
    this.startTime,
  });
}

/// Location sharing status
class LocationSharingStatus {
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final Duration? duration;
  final Duration? actualDuration;
  final String? sessionId;
  final SharingPrivacyLevel? privacyLevel;

  LocationSharingStatus({
    required this.isActive,
    this.startTime,
    this.endTime,
    this.duration,
    this.actualDuration,
    this.sessionId,
    this.privacyLevel,
  });
}