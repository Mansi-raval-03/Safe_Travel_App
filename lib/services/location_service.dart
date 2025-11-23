import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'offline_database_service.dart';
import 'location_cache_manager.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  StreamController<Position>? _locationController;
  
  StreamController<Position> get locationController {
    if (_locationController == null || _locationController!.isClosed) {
      _locationController = StreamController<Position>.broadcast();
    }
    return _locationController!;
  }
  
  // Real-time location tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  Timer? _trackingTimer;
  DateTime? _trackingStartTime;
  Duration? _trackingDuration;
  
  // Periodic location storage (every 5 minutes)
  Timer? _periodicStorageTimer;
  bool _isPeriodicStorageActive = false;
  static const Duration _storageInterval = Duration(minutes: 5);
  
  // Location accuracy and update settings
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  int _distanceFilterMeters = 1; // Update every 1 meter for faster refresh
  Duration _timeInterval = const Duration(seconds: 1); // Preferred update every 1 second

  Stream<Position> get locationStream => locationController.stream;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  DateTime? get trackingStartTime => _trackingStartTime;
  Duration? get remainingTrackingTime {
    if (_trackingStartTime == null || _trackingDuration == null) return null;
    final elapsed = DateTime.now().difference(_trackingStartTime!);
    final remaining = _trackingDuration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Initialize location service and request permissions with enhanced settings
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Request comprehensive location permissions
      bool permissionGranted = await _requestLocationPermissions();
      if (!permissionGranted) {
        print('❌ Location permissions not granted');
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled.');
        // Try to open location settings
        await Geolocator.openLocationSettings();
        return false;
      }

      // Get initial position with high accuracy
      _currentPosition = await getCurrentLocation();
      if (_currentPosition != null) {
        if (!locationController.isClosed) {
          locationController.add(_currentPosition!);
        }
        print('✅ Location service initialized successfully');
        print('📍 Initial position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        _isInitialized = true;
        return true;
      }

      print('❌ Could not get initial location');
      return false;
    } catch (e) {
      print('❌ Error initializing location service: $e');
      return false;
    }
  }

  /// Request comprehensive location permissions for all platforms
  Future<bool> _requestLocationPermissions() async {
    try {
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      print('📱 Current location permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        // Open app settings for user to manually enable
        await Geolocator.openAppSettings();
        return false;
      }

      // For enhanced accuracy on iOS 14+, request temporary full accuracy if needed
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        try {
          // This will only work on iOS and only if the accuracy is currently reduced
          await Geolocator.requestTemporaryFullAccuracy(purposeKey: "PreciseLocationForSafety");
        } catch (e) {
          // This is expected on Android or if already precise, so we ignore the error
          print('ℹ️  Temporary full accuracy not requested: $e');
        }
      }

      print('✅ Location permissions granted: $permission');
      return true;
    } catch (e) {
      print('❌ Error requesting location permissions: $e');
      return false;
    }
  }

  /// Compatibility wrapper: request permission (old API)
  Future<bool> requestPermission() async {
    return await _requestLocationPermissions();
  }

  /// Compatibility wrapper: get current position (old API returned non-nullable Position)
  Future<Position> getCurrentPosition() async {
    final p = await getCurrentLocation();
    if (p == null) throw Exception('Location not available');
    return p;
  }

  /// Compatibility wrapper: get position stream with options
  Stream<Position> getPositionStream({int distanceFilterMeters = 50, LocationAccuracy accuracy = LocationAccuracy.best}) {
    final locSettings = LocationSettings(accuracy: accuracy, distanceFilter: distanceFilterMeters);
    return Geolocator.getPositionStream(locationSettings: locSettings);
  }

  /// Open app settings (compat wrapper)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Try last known position first for faster UI responsiveness
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final DateTime ts = last.timestamp;
          final ageSeconds = DateTime.now().difference(ts).inSeconds;
          if (ageSeconds <= 30) {
            _currentPosition = last;
            await _cacheLocationForSync(last);
            return last;
          }
        }
      } catch (e) {
        print('⚠️ Could not read last known location: $e');
      }

      // Fall back to an active GPS fix but constrain to a short timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 6));

        _currentPosition = position;
        // Cache location for auto-sync
        await _cacheLocationForSync(position);
        return position;
      } catch (e) {
        print('⚠️ getCurrentPosition timed out or failed: $e');
        // If last known position exists return it as a fallback
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            _currentPosition = last;
            await _cacheLocationForSync(last);
            return last;
          }
        } catch (_) {}
        return null;
      }
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start continuous location tracking with optional time limit
  void startLocationTracking({Duration? duration}) {
    if (_isTracking) {
      print('⚠️  Location tracking already active');
      return;
    }

    if (!_isInitialized) {
      print('❌ Location service not initialized. Call initialize() first.');
      return;
    }

    print('🔄 Starting location tracking...');
    if (duration != null) {
      print('⏱️  Tracking duration: ${duration.inMinutes} minutes');
    }

    _isTracking = true;
    _trackingStartTime = DateTime.now();
    _trackingDuration = duration;

    // Configure platform-specific location settings for optimal real-time tracking
    LocationSettings locationSettings = _getOptimalLocationSettings();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        if (!locationController.isClosed) {
          locationController.add(position);
        }
        
        // Cache location for auto-sync
        _cacheLocationForSync(position);
        
        print('📍 Location update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
        print('🎯 Accuracy: ${position.accuracy.toStringAsFixed(1)}m, Speed: ${position.speed.toStringAsFixed(1)}m/s');
      },
      onError: (error) {
        print('❌ Location stream error: $error');
        _handleLocationError(error);
      },
    );

    // Set up timer for duration-limited tracking
    if (duration != null) {
      _trackingTimer = Timer(duration, () {
        print('⏰ Location tracking duration expired');
        stopLocationTracking();
      });
    }

    // Start periodic location storage (every 5 minutes)
    startPeriodicLocationStorage();

    print('✅ Location tracking started successfully');
  }

  /// Get optimal location settings based on platform and requirements
  LocationSettings _getOptimalLocationSettings() {
    // Cross-platform location settings optimized for real-time tracking
    try {
      // Prefer platform-specific settings when available
      // Android supports intervalDuration via AndroidSettings
      // Use LocationSettings fallback for other platforms
      return LocationSettings(
        accuracy: _currentAccuracy,
        distanceFilter: _distanceFilterMeters,
      );
    } catch (e) {
      print('⚠️ Could not create platform-specific location settings: $e');
      return LocationSettings(
        accuracy: _currentAccuracy,
        distanceFilter: _distanceFilterMeters,
      );
    }
  }

  /// Handle location tracking errors gracefully
  void _handleLocationError(dynamic error) {
    print('❌ Location tracking error: $error');
    
    // Try to recover from common errors
    if (error.toString().contains('PERMISSION_DENIED')) {
      print('🔄 Attempting to re-request location permissions...');
      _requestLocationPermissions().then((granted) {
        if (granted) {
          print('✅ Permissions re-granted, restarting tracking...');
          // Restart tracking after permission is granted
          stopLocationTracking();
          Future.delayed(const Duration(seconds: 1), () {
            startLocationTracking(duration: _trackingDuration);
          });
        }
      });
    } else if (error.toString().contains('LOCATION_SERVICES_DISABLED')) {
      print('📱 Location services disabled, opening settings...');
      Geolocator.openLocationSettings();
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    if (!_isTracking) {
      print('⚠️  Location tracking is not active');
      return;
    }

    print('🛑 Stopping location tracking...');
    
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _trackingTimer?.cancel();
    _trackingTimer = null;
    
    // Stop periodic location storage
    stopPeriodicLocationStorage();
    
    _isTracking = false;
    _trackingStartTime = null;
    _trackingDuration = null;
    
    print('✅ Location tracking stopped successfully');
  }

  /// Start periodic location storage (every 5 minutes)
  void startPeriodicLocationStorage() {
    if (_isPeriodicStorageActive) {
      print('⚠️  Periodic location storage already active');
      return;
    }

    print('💾 Starting periodic location storage (every 5 minutes)...');
    _isPeriodicStorageActive = true;

    // Store current location immediately
    _storeCurrentLocation();

    // Set up periodic timer to store location every 5 minutes
    _periodicStorageTimer = Timer.periodic(_storageInterval, (timer) {
      _storeCurrentLocation();
    });

    print('✅ Periodic location storage started successfully');
  }

  /// Stop periodic location storage
  void stopPeriodicLocationStorage() {
    if (!_isPeriodicStorageActive) {
      print('⚠️  Periodic location storage is not active');
      return;
    }

    print('🛑 Stopping periodic location storage...');
    
    _periodicStorageTimer?.cancel();
    _periodicStorageTimer = null;
    _isPeriodicStorageActive = false;
    
    print('✅ Periodic location storage stopped successfully');
  }

  /// Store current location to SQLite database
  Future<void> _storeCurrentLocation() async {
    if (_currentPosition == null) {
      print('⚠️  No current position available for storage');
      return;
    }

    try {
      final offlineDb = OfflineDatabaseService.instance;
      final id = await offlineDb.storeLocationData(_currentPosition!);
      
      if (id > 0) {
      print('💾 Location stored to database with ID: $id');
      print('📍 Stored position: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}');
      print('🎯 Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)}m at ${DateTime.fromMillisecondsSinceEpoch(_currentPosition!.timestamp.millisecondsSinceEpoch)}');
      } else {
        print('❌ Failed to store location to database');
      }
    } catch (e) {
      print('❌ Error storing location to database: $e');
    }
  }

  /// Get periodic storage status
  bool get isPeriodicStorageActive => _isPeriodicStorageActive;

  /// Start periodic location storage independently (without tracking)
  Future<bool> startPeriodicLocationStorageOnly() async {
    if (!_isInitialized) {
      print('❌ Location service not initialized. Call initialize() first.');
      return false;
    }

    // Get current location first
    final position = await getCurrentLocation();
    if (position == null) {
      print('❌ Cannot start periodic storage without location access');
      return false;
    }

    startPeriodicLocationStorage();
    return true;
  }

  /// Get stored location count for monitoring
  Future<int> getStoredLocationCount() async {
    try {
      final offlineDb = OfflineDatabaseService.instance;
      final stats = await offlineDb.getServiceStats();
      return stats['totalLocations'] ?? 0;
    } catch (e) {
      print('❌ Error getting stored location count: $e');
      return 0;
    }
  }

  /// Get recent stored locations for monitoring
  Future<List<Map<String, dynamic>>> getRecentStoredLocations({int limit = 10}) async {
    try {
      final offlineDb = OfflineDatabaseService.instance;
      return await offlineDb.getRecentStoredLocations(limit: limit);
    } catch (e) {
      print('❌ Error getting recent stored locations: $e');
      return [];
    }
  }

  /// Update tracking accuracy and filter settings
  void updateTrackingSettings({
    LocationAccuracy? accuracy,
    int? distanceFilterMeters,
    Duration? timeInterval,
  }) {
    bool wasTracking = _isTracking;
    Duration? remainingDuration = remainingTrackingTime;
    
    if (accuracy != null) _currentAccuracy = accuracy;
    if (distanceFilterMeters != null) _distanceFilterMeters = distanceFilterMeters;
    if (timeInterval != null) _timeInterval = timeInterval;
    
    print('⚙️  Updated tracking settings:');
    print('   Accuracy: $_currentAccuracy');
    print('   Distance filter: ${_distanceFilterMeters}m');
    print('   Time interval: ${_timeInterval.inSeconds}s');
    
    // Restart tracking with new settings if it was active
    if (wasTracking) {
      stopLocationTracking();
      Future.delayed(const Duration(milliseconds: 500), () {
        startLocationTracking(duration: remainingDuration);
      });
    }
  }

  /// Calculate distance between two points
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if location is within a certain radius of a point
  bool isWithinRadius(double targetLat, double targetLng, double radiusInMeters) {
    if (_currentPosition == null) return false;
    
    double distance = calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLng,
    );
    
    return distance <= radiusInMeters;
  }

  /// Get location sharing data for external sharing
  Map<String, dynamic> getLocationSharingData() {
    if (_currentPosition == null) {
      return {};
    }

    return {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'accuracy': _currentPosition!.accuracy,
      'timestamp': _currentPosition!.timestamp.toIso8601String(),
      'speed': _currentPosition!.speed,
      'heading': _currentPosition!.heading,
      'altitude': _currentPosition!.altitude,
      'isTracking': _isTracking,
      'trackingStartTime': _trackingStartTime?.toIso8601String(),
      'remainingTime': remainingTrackingTime?.inMinutes,
    };
  }

  /// Generate a shareable location link (Google Maps format)
  String generateShareableLocationLink() {
    if (_currentPosition == null) {
      return '';
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    
    // Generate Google Maps link with current location
    return 'https://www.google.com/maps?q=$lat,$lng&ll=$lat,$lng&z=15';
  }

  /// Get detailed location status for UI display
  Map<String, dynamic> getLocationStatus() {
    return {
      'isInitialized': _isInitialized,
      'isTracking': _isTracking,
      'hasCurrentPosition': _currentPosition != null,
      'accuracy': _currentPosition?.accuracy ?? 0,
      'lastUpdate': _currentPosition?.timestamp,
      'trackingDuration': _trackingStartTime != null 
          ? DateTime.now().difference(_trackingStartTime!)
          : null,
      'remainingTime': remainingTrackingTime,
      'settings': {
        'accuracy': _currentAccuracy.toString(),
        'distanceFilter': _distanceFilterMeters,
        'timeInterval': _timeInterval.inSeconds,
      }
    };
  }

  /// Check if location is accurate enough for sharing
  bool isLocationAccurateForSharing() {
    if (_currentPosition == null) return false;
    return _currentPosition!.accuracy <= 50; // Within 50 meters
  }

  /// Get human-readable location accuracy description
  String getAccuracyDescription() {
    if (_currentPosition == null) return 'No location data';
    
    final accuracy = _currentPosition!.accuracy;
    if (accuracy <= 5) return 'Excellent (${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 10) return 'Good (${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 50) return 'Fair (${accuracy.toStringAsFixed(1)}m)';
    return 'Poor (${accuracy.toStringAsFixed(1)}m)';
  }

  /// Cache location data for auto-sync functionality
  Future<void> _cacheLocationForSync(Position position) async {
    try {
      final cacheManager = LocationCacheManager.instance;
      
      // Only cache if user ID is set (user is logged in)
      final userId = cacheManager.getUserId();
      if (userId == null || userId.isEmpty) {
        return; // Skip caching if no user logged in
      }
      
      // Create location data for caching
      final locationData = CachedLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        userId: userId,
      );
      
      // Save location to cache (this will be synced when connectivity returns)
      await cacheManager.saveLastLocation(locationData);
      
    } catch (e) {
      print('⚠️ Failed to cache location for sync: $e');
      // Don't throw error - location tracking should continue even if caching fails
    }
  }

  /// Dispose resources
  void dispose() {
    print('🧹 Disposing location service...');
    stopLocationTracking();
    stopPeriodicLocationStorage();
    if (_locationController != null && !_locationController!.isClosed) {
      _locationController!.close();
      _locationController = null;
    }
    _isInitialized = false;
    print('✅ Location service disposed');
  }
}