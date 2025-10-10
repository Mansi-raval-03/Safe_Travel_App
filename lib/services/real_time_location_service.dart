import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'offline_database_service.dart';
import '../config/api_config.dart';

/// Simplified Real-Time Location Service with Socket.IO Integration
///
/// - Real-time location broadcasting via Socket.IO
/// - Offline SQLite caching with automatic sync
/// - Network-aware sync on connectivity restore
/// - Live location sharing and receiving
class RealTimeLocationService {
  static RealTimeLocationService? _instance;
  static RealTimeLocationService get instance {
    _instance ??= RealTimeLocationService._();
    return _instance!;
  }

  RealTimeLocationService._();

  // Core services
  late final OfflineDatabaseService _dbService;
  late IO.Socket _socket;

  // Location tracking
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastKnownPosition;

  // Network monitoring
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controllers
  final _locationStreamController = StreamController<Position>.broadcast();
  final _remoteLocationStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _networkStatusController = StreamController<bool>.broadcast();
  final _trackingStatusController = StreamController<LocationTrackingStatus>.broadcast();

  // Tracking configuration
  bool _isTracking = false;
  bool _isBackgroundTracking = false;
  String? _userId;
  Timer? _syncTimer;
  Timer? _heartbeatTimer;

  // Getters
  bool get isTracking => _isTracking;
  bool get isBackgroundTracking => _isBackgroundTracking;
  bool get isOnline => _isOnline;
  Position? get lastKnownPosition => _lastKnownPosition;
  Stream<Position> get locationStream => _locationStreamController.stream;
  Stream<Map<String, dynamic>> get remoteLocationStream => _remoteLocationStreamController.stream;
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  Stream<LocationTrackingStatus> get trackingStatusStream => _trackingStatusController.stream;

  /// Initialize the real-time location service
  Future<void> initialize({String? userId}) async {
    try {
      print('🚀 Initializing RealTimeLocationService...');
      _userId = userId;

      // Initialize database service
      _dbService = OfflineDatabaseService.instance;
      await _dbService.database; // This will initialize the database
      print('✅ Database service initialized');

      // Initialize socket
      await _initializeSocket();
      print('✅ Socket.IO service initialized');

      // Initialize connectivity monitoring
      await _initializeConnectivityMonitoring();
      print('✅ Connectivity monitoring initialized');

      print('🎯 RealTimeLocationService successfully initialized');
    } catch (e, st) {
      print('❌ Error initializing RealTimeLocationService: $e\n$st');
      rethrow;
    }
  }

  /// Initialize Socket.IO connection with comprehensive event handling
  Future<void> _initializeSocket() async {
    try {
      final socketUrl = ApiConfig.currentSocketUrl;

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      // Connect / disconnect
      _socket.onConnect((_) {
        print('🔗 Socket connected to $socketUrl');
        _broadcastTrackingStatus(LocationTrackingStatus.connected);

        // Register user with socket if provided
        if (_userId != null) {
          _socket.emit('user_init', {
            'userId': _userId,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }

        // If we became connected and online, try syncing
        if (_isOnline) {
          _syncOfflineLocations();
        }
      });

      _socket.onDisconnect((_) {
        print('🔌 Socket disconnected');
        _broadcastTrackingStatus(LocationTrackingStatus.disconnected);
      });

      _socket.onReconnect((_) {
        print('🔄 Socket reconnected');
        _broadcastTrackingStatus(LocationTrackingStatus.connected);
      });

      // Remote events
      _socket.on('location_update_received', (data) {
        _handleRemoteLocationUpdate(data);
      });

      _socket.on('nearby_users', (data) {
        _handleNearbyUsersUpdate(data);
      });

      // Errors
      _socket.onConnectError((error) {
        print('❌ Socket connection error: $error');
        _broadcastTrackingStatus(LocationTrackingStatus.error);
      });

      _socket.onError((error) {
        print('❌ Socket error: $error');
      });

      // Start connection
      _socket.connect();
    } catch (e, st) {
      print('❌ Error initializing socket: $e\n$st');
      rethrow;
    }
  }

  /// Start real-time location tracking with Socket.IO broadcasting
  Future<void> startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, required bool includeBackground, // meters
  }) async {
    try {
      print('🎯 Starting location tracking...');

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Configure location settings
      LocationSettings locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      // Start location stream
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handleLocationUpdate(position);
        },
        onError: (error) {
          print('❌ Location stream error: $error');
          _broadcastTrackingStatus(LocationTrackingStatus.error);
        },
      );

      _isTracking = true;
      _broadcastTrackingStatus(LocationTrackingStatus.tracking);

      // Start periodic sync and heartbeat
      _startPeriodicSync();
      _startHeartbeat();

      print('✅ Location tracking started successfully');
    } catch (e, st) {
      print('❌ Error starting location tracking: $e\n$st');
      rethrow;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      print('🛑 Stopping location tracking...');

      // Cancel location subscription
      if (_locationSubscription != null) {
        await _locationSubscription!.cancel();
        _locationSubscription = null;
      }

      // Cancel timers
      _syncTimer?.cancel();
      _heartbeatTimer?.cancel();

      _isTracking = false;
      _isBackgroundTracking = false;
      _broadcastTrackingStatus(LocationTrackingStatus.stopped);

      print('✅ Location tracking stopped');
    } catch (e, st) {
      print('❌ Error stopping location tracking: $e\n$st');
    }
  }

  /// Handle location update from GPS
  Future<void> _handleLocationUpdate(Position position) async {
    try {
      _lastKnownPosition = position;

      print('📍 Location update: ${position.latitude}, ${position.longitude}');

      // Broadcast to local stream
      _locationStreamController.add(position);

      // Store offline for sync later
      await _storeLocationOffline(position);

      // Real-time broadcast via Socket.IO (if connected & online)
      if (_socket.connected && _isOnline) {
        _socket.emit('location_update', {
          'userId': _userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': DateTime.now().toIso8601String(),
        });
        print('📡 Location broadcasted via Socket.IO');
      }
    } catch (e, st) {
      print('❌ Error handling location update: $e\n$st');
    }
  }

  /// Store location data offline for later sync
  Future<void> _storeLocationOffline(Position position) async {
    try {
      await _dbService.storeLocation({
        'userId': _userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0, // assume DB schema uses this flag
      });
      print('💾 Location stored offline');
    } catch (e, st) {
      print('❌ Error storing location offline: $e\n$st');
    }
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivityMonitoring() async {
    try {
      // Check initial connectivity
      final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult.contains(ConnectivityResult.mobile) || 
                  connectivityResult.contains(ConnectivityResult.wifi);
      _networkStatusController.add(_isOnline);

      // Monitor connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        final previousOnlineStatus = _isOnline;
        // Check if any connection is mobile or wifi
        _isOnline = results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi);

        print('🌐 Network status changed: ${_isOnline ? 'Online' : 'Offline'}');
        _networkStatusController.add(_isOnline);

        // Trigger sync when going back online
        if (!previousOnlineStatus && _isOnline) {
          print('🔄 Back online - triggering sync...');
          // If socket is not connected, socket will attempt reconnect automatically.
          // Wait a moment for socket to connect, then sync. We try immediate sync; socket.onConnect will also trigger sync.
          _syncOfflineLocations();
        }
      });
    } catch (e) {
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && _socket.connected) {
        _syncOfflineLocations();
      }
    });
  }

  /// Start heartbeat timer to maintain socket connection
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_socket.connected) {
        _socket.emit('heartbeat', {
          'userId': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Sync offline stored locations when network is available
  Future<void> _syncOfflineLocations() async {
    try {
      if (!_isOnline || !_socket.connected) {
        print('⚠️ Skipping sync: offline or socket not connected');
        return;
      }

      final unsynced = await _dbService.getUnsyncedLocations(); // expected to return List<Map>
      print('🔄 Syncing ${unsynced.length} offline locations...');

      int successCount = 0;
      for (final location in unsynced) {
        try {
          // send to server via Socket.IO
          _socket.emit('location_sync', location);

          // Mark as synced in DB
          final id = location['id'] ?? location['rowid'];
          if (id != null) {
            await _dbService.markLocationsSynced([id]); // Pass as list
          }
          successCount++;
        } catch (e) {
          print('❌ Error syncing location ${location['id'] ?? 'unknown'}: $e');
        }
      }

      if (successCount > 0) {
        print('✅ Successfully synced $successCount locations');
      } else {
        print('ℹ️ No locations were synced this run');
      }
    } catch (e, st) {
      print('❌ Error during location sync: $e\n$st');
    }
  }

  /// Handle remote location updates from other users
  void _handleRemoteLocationUpdate(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        print('📱 Received remote location: ${data['latitude']}, ${data['longitude']}');
        _remoteLocationStreamController.add(data);
      } else {
        // If server sends JSON strings, attempt to parse or ignore
        print('ℹ️ Received remote location data of unexpected type: ${data.runtimeType}');
      }
    } catch (e, st) {
      print('❌ Error handling remote location: $e\n$st');
    }
  }

  /// Handle nearby users update
  void _handleNearbyUsersUpdate(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        print('👥 Nearby users update: ${data['count']} users nearby');
        _remoteLocationStreamController.add({
          'type': 'nearby_users',
          'data': data,
        });
      } else {
        print('ℹ️ nearby_users event with unexpected data type: ${data.runtimeType}');
      }
    } catch (e, st) {
      print('❌ Error handling nearby users update: $e\n$st');
    }
  }

  /// Broadcast tracking status to listeners
  void _broadcastTrackingStatus(LocationTrackingStatus status) {
    _trackingStatusController.add(status);
  }

  /// Clean shutdown of the service
  Future<void> dispose() async {
    try {
      print('🧹 Disposing RealTimeLocationService...');

      // Stop location tracking
      await stopLocationTracking();

      // Close stream controllers
      await _locationStreamController.close();
      await _remoteLocationStreamController.close();
      await _networkStatusController.close();
      await _trackingStatusController.close();

      // Cancel connectivity subscription
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;

      // Disconnect socket
      try {
        _socket.disconnect();
        _socket.destroy();
      } catch (e) {
        // ignore socket errors during dispose
      }

      print('✅ RealTimeLocationService disposed');
    } catch (e, st) {
      print('❌ Error disposing service: $e\n$st');
    }
  }
}

/// Location tracking status enumeration
enum LocationTrackingStatus {
  stopped,
  connecting,
  connected,
  tracking,
  backgroundTracking,
  disconnected,
  error,
}
