import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'location_cache_manager.dart';
import 'connectivity_monitor_service.dart';

/// Configuration for auto location sync
class AutoSyncConfig {
  final Duration offlineThreshold;
  final Duration syncTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final String baseUrl;
  final bool enableBackgroundSync;

  const AutoSyncConfig({
    this.offlineThreshold = const Duration(minutes: 15),
    this.syncTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.baseUrl = 'http://localhost:3000',
    this.enableBackgroundSync = true,
  });
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int locationsSynced;
  final int locationsSkipped;
  final DateTime syncTime;
  final Duration? offlineDuration;
  final String? error;

  SyncResult({
    required this.success,
    required this.message,
    this.locationsSynced = 0,
    this.locationsSkipped = 0,
    required this.syncTime,
    this.offlineDuration,
    this.error,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, synced: $locationsSynced, message: $message)';
  }
}

/// Main service that handles automatic location syncing
class AutoLocationSyncService {
  static AutoLocationSyncService? _instance;
  static AutoLocationSyncService get instance => _instance ??= AutoLocationSyncService._();
  AutoLocationSyncService._();

  final LocationCacheManager _cacheManager = LocationCacheManager.instance;
  final ConnectivityMonitorService _connectivityMonitor = ConnectivityMonitorService.instance;
  
  AutoSyncConfig _config = const AutoSyncConfig();
  String? _authToken;
  bool _isInitialized = false;
  bool _isSyncing = false;
  
  // Stream controllers
  final StreamController<SyncResult> _syncResultController = 
      StreamController<SyncResult>.broadcast();
  
  StreamSubscription<bool>? _reconnectionSubscription;

  // Public streams
  Stream<SyncResult> get onSyncResult => _syncResultController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  AutoSyncConfig get config => _config;

  /// Initialize the auto location sync service
  Future<void> initialize({
    AutoSyncConfig? config,
    String? authToken,
  }) async {
    try {
      if (_isInitialized) {
        print('⚠️ AutoLocationSyncService already initialized');
        return;
      }

      // Update configuration
      if (config != null) {
        _config = config;
      }
      
      if (authToken != null) {
        _authToken = authToken;
      }

      // Initialize dependencies
      await _cacheManager.initialize();
      await _connectivityMonitor.initialize();

      // Listen for reconnection events
      _reconnectionSubscription = _connectivityMonitor.onReconnection.listen(
        (reconnected) async {
          if (reconnected) {
            await _handleReconnection();
          }
        },
      );

      _isInitialized = true;
      print('✅ AutoLocationSyncService initialized');
      
      // Perform initial sync check if connected
      if (_connectivityMonitor.isConnected) {
        await _performInitialSyncCheck();
      }

    } catch (e) {
      print('❌ Error initializing AutoLocationSyncService: $e');
      rethrow;
    }
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
    print('🔐 Auth token updated for AutoLocationSyncService');
  }

  /// Update configuration
  void updateConfig(AutoSyncConfig newConfig) {
    _config = newConfig;
    print('⚙️ AutoLocationSyncService configuration updated');
  }

  /// Handle reconnection events
  Future<void> _handleReconnection() async {
    try {
      print('🔄 Handling reconnection event');
      
      // Check if sync should be triggered based on offline duration
      if (_cacheManager.shouldTriggerSync(threshold: _config.offlineThreshold)) {
        await triggerSync(reason: 'auto_reconnection');
      } else {
        print('⏭️ Reconnection detected but offline duration below threshold');
      }
    } catch (e) {
      print('❌ Error handling reconnection: $e');
    }
  }

  /// Perform initial sync check on service startup
  Future<void> _performInitialSyncCheck() async {
    try {
      print('🔍 Performing initial sync check');
      
      // Check if there's pending data to sync
      if (_cacheManager.hasDataToSync()) {
        final lastSync = _cacheManager.getLastSyncTime();
        final now = DateTime.now();
        
        // If no previous sync or last sync was more than threshold ago
        if (lastSync == null || now.difference(lastSync) > _config.offlineThreshold) {
          await triggerSync(reason: 'initial_check');
        }
      }
    } catch (e) {
      print('❌ Error in initial sync check: $e');
    }
  }

  /// Manually trigger a sync operation
  Future<SyncResult> triggerSync({
    String reason = 'manual',
    bool forceSync = false,
  }) async {
    if (!_isInitialized) {
      throw Exception('AutoLocationSyncService not initialized');
    }

    if (_isSyncing && !forceSync) {
      print('⏸️ Sync already in progress, skipping');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncTime: DateTime.now(),
      );
    }

    _isSyncing = true;

    try {
      print('🚀 Starting location sync (reason: $reason)');

      // Check if we're connected
      if (!_connectivityMonitor.isConnected) {
        throw Exception('No internet connection available');
      }

      // Check authentication
      if (_authToken == null || _authToken!.isEmpty) {
        throw Exception('No authentication token available');
      }

      // Gather locations to sync
      final locationsToSync = await _gatherLocationsToSync();
      
      if (locationsToSync.isEmpty) {
        print('📭 No locations to sync');
        return SyncResult(
          success: true,
          message: 'No locations to sync',
          syncTime: DateTime.now(),
        );
      }

      // Get offline duration info
      final offlineDuration = _calculateOfflineDuration();

      // Perform the sync
      final result = await _performSync(locationsToSync, reason, offlineDuration);
      
      // Emit result
      _syncResultController.add(result);
      
      return result;

    } catch (e) {
      print('❌ Sync failed: $e');
      
      final errorResult = SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncTime: DateTime.now(),
        error: e.toString(),
      );
      
      _syncResultController.add(errorResult);
      return errorResult;
      
    } finally {
      _isSyncing = false;
    }
  }

  /// Gather all locations that need to be synced
  Future<List<CachedLocationData>> _gatherLocationsToSync() async {
    final locations = <CachedLocationData>[];

    // Add queued locations
    final queuedLocations = _cacheManager.getSyncQueue();
    locations.addAll(queuedLocations);

    // Add current location if needed
    try {
      final currentLocation = await _getCurrentLocation();
      if (currentLocation != null) {
        // Cache the current location
        await _cacheManager.saveLastLocation(currentLocation);
        
        // Add to sync list if not already in queue
        final isAlreadyQueued = queuedLocations.any((loc) =>
          (loc.latitude - currentLocation.latitude).abs() < 0.0001 &&
          (loc.longitude - currentLocation.longitude).abs() < 0.0001 &&
          loc.timestamp.difference(currentLocation.timestamp).abs() < const Duration(minutes: 1)
        );
        
        if (!isAlreadyQueued) {
          locations.add(currentLocation);
        }
      }
    } catch (e) {
      print('⚠️ Could not get current location: $e');
      
      // Use last known location if current location fails
      final lastLocation = _cacheManager.getLastLocation();
      if (lastLocation != null && !queuedLocations.contains(lastLocation)) {
        locations.add(lastLocation);
      }
    }

    print('📍 Gathered ${locations.length} locations to sync');
    return locations;
  }

  /// Get current device location
  Future<CachedLocationData?> _getCurrentLocation() async {
    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('⚠️ Location permission denied');
        return null;
      }

      // Check if location services are enabled
      if (!await Geolocator.isLocationServiceEnabled()) {
        print('⚠️ Location services disabled');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final userId = _cacheManager.getUserId();
      
      return CachedLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        userId: userId,
      );

    } catch (e) {
      print('❌ Error getting current location: $e');
      return null;
    }
  }

  /// Calculate offline duration
  Duration? _calculateOfflineDuration() {
    final lastOffline = _cacheManager.getLastOfflineTime();
    final lastConnected = _connectivityMonitor.lastConnectedTime;
    
    if (lastOffline != null && lastConnected != null && lastConnected.isAfter(lastOffline)) {
      return lastConnected.difference(lastOffline);
    }
    
    return null;
  }

  /// Perform the actual sync operation with retry logic
  Future<SyncResult> _performSync(
    List<CachedLocationData> locations,
    String reason,
    Duration? offlineDuration,
  ) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _config.maxRetries; attempt++) {
      try {
        print('🔄 Sync attempt $attempt/${_config.maxRetries}');

        final result = await _sendSyncRequest(locations, reason, offlineDuration);
        
        if (result.success) {
          // Update cache after successful sync
          await _updateCacheAfterSync(locations);
          return result;
        } else {
          throw Exception(result.message);
        }

      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('❌ Sync attempt $attempt failed: $e');

        if (attempt < _config.maxRetries) {
          print('⏳ Waiting ${_config.retryDelay.inSeconds}s before retry...');
          await Future.delayed(_config.retryDelay);
        }
      }
    }

    // All attempts failed
    throw lastError ?? Exception('Unknown sync error');
  }

  /// Send sync request to backend
  Future<SyncResult> _sendSyncRequest(
    List<CachedLocationData> locations,
    String reason,
    Duration? offlineDuration,
  ) async {
    final url = Uri.parse('${_config.baseUrl}/api/v1/location/sync');
    
    final requestBody = {
      'locations': locations.map((loc) => {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'timestamp': loc.timestamp.toIso8601String(),
        if (loc.accuracy != null) 'accuracy': loc.accuracy,
      }).toList(),
      'deviceInfo': {
        if (offlineDuration != null) 'offlineDuration': offlineDuration.inMinutes,
        'deviceType': 'mobile',
        'platform': defaultTargetPlatform.name,
      },
      'syncReason': reason,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: jsonEncode(requestBody),
    ).timeout(_config.syncTimeout);

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      final data = responseData['data'];
      
      return SyncResult(
        success: true,
        message: responseData['message'] ?? 'Sync successful',
        locationsSynced: data['saved'] ?? 0,
        locationsSkipped: data['skipped'] ?? 0,
        syncTime: DateTime.now(),
        offlineDuration: offlineDuration,
      );
    } else {
      throw Exception(responseData['message'] ?? 'Sync request failed');
    }
  }

  /// Update cache after successful sync
  Future<void> _updateCacheAfterSync(List<CachedLocationData> syncedLocations) async {
    // Update last sync time
    await _cacheManager.updateLastSyncTime();
    
    // Remove synced locations from queue
    final queuedLocations = _cacheManager.getSyncQueue();
    final syncedTimestamps = syncedLocations.map((l) => l.timestamp).toSet();
    final locationsToRemove = queuedLocations.where((loc) =>
      syncedTimestamps.contains(loc.timestamp)
    ).toList();
    
    if (locationsToRemove.isNotEmpty) {
      await _cacheManager.removeFromSyncQueue(locationsToRemove);
    }
    
    print('✅ Cache updated after successful sync');
  }

  /// Add location to sync queue for later syncing
  Future<void> queueLocationForSync(CachedLocationData location) async {
    if (!_isInitialized) {
      print('⚠️ Service not initialized, cannot queue location');
      return;
    }

    await _cacheManager.addToSyncQueue(location);
    
    // Try immediate sync if connected
    if (_connectivityMonitor.isConnected && !_isSyncing) {
      try {
        await triggerSync(reason: 'queued_location');
      } catch (e) {
        print('⚠️ Failed to sync queued location immediately: $e');
      }
    }
  }

  /// Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncing,
      'hasAuthToken': _authToken != null && _authToken!.isNotEmpty,
      'connectivity': _connectivityMonitor.getConnectivityStatus(),
      'cache': _cacheManager.getSyncStatus(),
      'config': {
        'offlineThreshold': _config.offlineThreshold.inMinutes,
        'syncTimeout': _config.syncTimeout.inSeconds,
        'maxRetries': _config.maxRetries,
        'retryDelay': _config.retryDelay.inSeconds,
        'baseUrl': _config.baseUrl,
      },
    };
  }

  /// Dispose the service
  void dispose() {
    _reconnectionSubscription?.cancel();
    _syncResultController.close();
    _connectivityMonitor.dispose();
    _isInitialized = false;
    print('🗑️ AutoLocationSyncService disposed');
  }

  /// Debug method
  void debugPrintStatus() {
    final status = getSyncStatus();
    print('🔍 AutoLocationSyncService Status:');
    print('  Initialized: ${status['isInitialized']}');
    print('  Syncing: ${status['isSyncing']}');
    print('  Has Auth Token: ${status['hasAuthToken']}');
    print('  Connected: ${status['connectivity']['isConnected']}');
    print('  Has Data to Sync: ${status['cache']['hasDataToSync']}');
    print('  Should Trigger Sync: ${status['cache']['shouldTriggerSync']}');
    print('  Queue Size: ${status['cache']['syncQueueSize']}');
  }
}