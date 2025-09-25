import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationController.stream;
  Position? get currentPosition => _currentPosition;

  /// Initialize location service and request permissions
  /// 
  /// 
  Future<bool> initialize() async {
    try {
      // Check location permission
      final permission = await Permission.location.status;
      if (permission.isDenied) {
        final result = await Permission.location.request();
        if (result.isDenied) {
          print('Location permission denied');
          return false;
        }
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return false;
      }

      // Get initial position
      _currentPosition = await getCurrentLocation();
      if (_currentPosition != null) {
        _locationController.add(_currentPosition!);
      }

      return true;
    } catch (e) {
      print('Error initializing location service: $e');
      return false;
    }
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  void startLocationTracking() {
    if (_positionStreamSubscription != null) {
      return; // Already tracking
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        _locationController.add(position);
        print('Location updated: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
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

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _locationController.close();
  }
}