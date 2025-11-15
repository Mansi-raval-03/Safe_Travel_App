import 'dart:async';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'location_service.dart';
import 'navigation_service.dart';
import 'notification_service.dart';
import 'sms_service.dart';
import 'emergency_contact_service.dart';

class SocketIOService {
  static final SocketIOService _instance = SocketIOService._internal();
  factory SocketIOService() => _instance;
  SocketIOService._internal();

  IO.Socket? _socket;
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  
  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _userLocationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _nearbyUsersController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get userLocationStream => _userLocationController.stream;
  Stream<List<Map<String, dynamic>>> get nearbyUsersStream => _nearbyUsersController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Initialize Socket.IO connection
  Future<bool> initialize({
    required String serverUrl,
    required String userId,
    String? userName,
  }) async {
    try {
      // Initialize location service first
      bool locationInitialized = await _locationService.initialize();
      if (!locationInitialized) {
        print('Failed to initialize location service');
        return false;
      }

      // Create socket connection
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'userId': userId,
          'userName': userName ?? 'Unknown User',
        }
      });

      // Set up event listeners
      _setupEventListeners();

      // Connect to server
      _socket!.connect();

      return true;
    } catch (e) {
      print('Error initializing Socket.IO service: $e');
      return false;
    }
  }

  /// Set up Socket.IO event listeners
  void _setupEventListeners() {
    _socket!.on('connect', (_) {
      print('Connected to Socket.IO server');
      _startLocationSharing();
    });

    _socket!.on('disconnect', (_) {
      print('Disconnected from Socket.IO server');
      _stopLocationSharing();
    });

    _socket!.on('connect_error', (error) {
      print('Socket.IO connection error: $error');
    });

    // Listen for nearby users updates
    _socket!.on('nearby_users', (data) {
      if (data is List) {
        List<Map<String, dynamic>> nearbyUsers = List<Map<String, dynamic>>.from(data);
        _nearbyUsersController.add(nearbyUsers);
      }
    });

    // Listen for user location updates
    _socket!.on('user_location_updated', (data) {
      if (data is Map<String, dynamic>) {
        _userLocationController.add(Map<String, dynamic>.from(data));
      }
    });

    // Listen for emergency alerts
    _socket!.on('emergency_alert', (data) {
      if (data is Map<String, dynamic>) {
          _handleEmergencyAlert(Map<String, dynamic>.from(data));
      }
    });

    // Listen for safety updates
    _socket!.on('safety_update', (data) {
      if (data is Map<String, dynamic>) {
        _handleSafetyUpdate(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Start sharing location with other users
  void _startLocationSharing() {
    // Send initial location
    if (_locationService.currentPosition != null) {
      _emitLocationUpdate(_locationService.currentPosition!);
    }

    // Subscribe to location updates
    _locationSubscription = _locationService.locationStream.listen((position) {
      _emitLocationUpdate(position);
    });

    // Start location tracking
    _locationService.startLocationTracking();
  }

  /// Stop sharing location
  void _stopLocationSharing() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopLocationTracking();
  }

  /// Emit location update to server
  void _emitLocationUpdate(Position position) {
    if (_socket?.connected == true) {
      _socket!.emit('location_update', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'speed': position.speed,
        'heading': position.heading,
      });
    }
  }

  /// Send emergency alert
  void sendEmergencyAlert({
    required String alertType,
    String? message,
    Map<String, dynamic>? additionalData,
  }) {
    if (_socket?.connected == true && _locationService.currentPosition != null) {
      _socket!.emit('emergency_alert', {
        'alertType': alertType,
        'message': message,
        'latitude': _locationService.currentPosition!.latitude,
        'longitude': _locationService.currentPosition!.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'additionalData': additionalData,
      });

      // Fire-and-forget: send SMS to saved emergency contacts silently
      () async {
        try {
          // Fetch contacts from API/local store
          final contacts = await EmergencyContactService.getAllContacts();
          final phones = contacts.map((c) => c.phone).where((p) => p.trim().isNotEmpty).toList();
          if (phones.isEmpty) {
            print('SocketIOService: no emergency contact phone numbers found');
            return;
          }

          final smsPerm = await SmsService.ensurePermissions();
          if (!smsPerm) {
            print('SocketIOService: SMS permissions not granted');
            return;
          }

          final lat = _locationService.currentPosition!.latitude;
          final lng = _locationService.currentPosition!.longitude;
          final smsMessage = message ?? 'Emergency! I need help.';

          // Send SMS messages (non-blocking to the caller)
          await SmsService.sendSOSMessages(
            phones: phones,
            message: smsMessage,
            latitude: lat,
            longitude: lng,
          );
        } catch (e) {
          print('SocketIOService: error sending SOS SMS: $e');
        }
      }();
    }
  }

  /// Join a specific room/group
  void joinRoom(String roomId) {
    if (_socket?.connected == true) {
      _socket!.emit('join_room', {'roomId': roomId});
    }
  }

  /// Leave a room/group
  void leaveRoom(String roomId) {
    if (_socket?.connected == true) {
      _socket!.emit('leave_room', {'roomId': roomId});
    }
  }

  /// Request nearby users
  void requestNearbyUsers({double radiusInKm = 5.0}) {
    if (_socket?.connected == true && _locationService.currentPosition != null) {
      _socket!.emit('request_nearby_users', {
        'latitude': _locationService.currentPosition!.latitude,
        'longitude': _locationService.currentPosition!.longitude,
        'radius': radiusInKm,
      });
    }
  }

  /// Handle emergency alerts from other users
  void _handleEmergencyAlert(Map<String, dynamic> alert) {
    print('Emergency alert received: $alert');

    // Play audible siren (asset) and vibrate to get user's attention
    try {
      // Haptic vibration (short burst)
      HapticFeedback.vibrate();
    } catch (e) {
      print('Haptic feedback failed: $e');
    }

    // Play siren sound (non-blocking)
    try {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      player.play(AssetSource('assets/sounds/police-siren-397963.mp3'));
    } catch (e) {
      print('Failed to play siren: $e');
    }

    // Show an in-app alert dialog with sender details and live location
    try {
      NavigationService.showEmergencyDialog(alert);
    } catch (e) {
      print('Failed to show emergency dialog: $e');
    }

    // Also post a local notification so the alert reaches users when app is backgrounded
    try {
      NotificationService.showEmergencyNotification(alert);
    } catch (e) {
      print('Failed to show local notification: $e');
    }
  }

  /// Handle safety updates
  void _handleSafetyUpdate(Map<String, dynamic> update) {
    // Handle safety updates like traffic alerts, road closures, etc.
    print('Safety update received: $update');
  }

  /// Update user status (safe, in_danger, help_needed, etc.)
  void updateUserStatus(String status, {String? message}) {
    if (_socket?.connected == true) {
      _socket!.emit('status_update', {
        'status': status,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Send a check-in update
  void sendCheckIn({
    required String location,
    String? message,
    List<String>? tags,
  }) {
    if (_socket?.connected == true && _locationService.currentPosition != null) {
      _socket!.emit('check_in', {
        'location': location,
        'message': message,
        'tags': tags,
        'latitude': _locationService.currentPosition!.latitude,
        'longitude': _locationService.currentPosition!.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Disconnect from Socket.IO server
  void disconnect() {
    _stopLocationSharing();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _userLocationController.close();
    _nearbyUsersController.close();
    _locationService.dispose();
  }
}