import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'location_cache_manager.dart';

/// Enum to represent connectivity states
enum ConnectivityState {
  connected,
  disconnected,
  unknown,
}

/// Model for connectivity change events
class ConnectivityChangeEvent {
  final ConnectivityState previousState;
  final ConnectivityState currentState;
  final DateTime timestamp;
  final List<ConnectivityResult> connectivityResults;
  final Duration? offlineDuration;

  ConnectivityChangeEvent({
    required this.previousState,
    required this.currentState,
    required this.timestamp,
    required this.connectivityResults,
    this.offlineDuration,
  });

  bool get isReconnection => 
    previousState == ConnectivityState.disconnected && 
    currentState == ConnectivityState.connected;

  bool get isDisconnection => 
    previousState == ConnectivityState.connected && 
    currentState == ConnectivityState.disconnected;

  @override
  String toString() {
    return 'ConnectivityChangeEvent(${previousState.name} → ${currentState.name}, duration: ${offlineDuration?.inMinutes}min)';
  }
}

/// Service that monitors network connectivity changes and triggers location sync
class ConnectivityMonitorService {
  static ConnectivityMonitorService? _instance;
  static ConnectivityMonitorService get instance => _instance ??= ConnectivityMonitorService._();
  ConnectivityMonitorService._();

  final Connectivity _connectivity = Connectivity();
  final LocationCacheManager _cacheManager = LocationCacheManager.instance;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  ConnectivityState _currentState = ConnectivityState.unknown;
  DateTime? _lastDisconnectedTime;
  DateTime? _lastConnectedTime;
  
  // Stream controllers for external listeners
  final StreamController<ConnectivityChangeEvent> _connectivityChangeController = 
      StreamController<ConnectivityChangeEvent>.broadcast();
  
  final StreamController<bool> _reconnectionController = 
      StreamController<bool>.broadcast();

  // Public streams
  Stream<ConnectivityChangeEvent> get onConnectivityChanged => 
      _connectivityChangeController.stream;
  
  Stream<bool> get onReconnection => _reconnectionController.stream;

  // Getters
  ConnectivityState get currentState => _currentState;
  bool get isConnected => _currentState == ConnectivityState.connected;
  bool get isDisconnected => _currentState == ConnectivityState.disconnected;
  DateTime? get lastDisconnectedTime => _lastDisconnectedTime;
  DateTime? get lastConnectedTime => _lastConnectedTime;

  /// Initialize the connectivity monitor
  Future<void> initialize() async {
    try {
      // Initialize cache manager first
      await _cacheManager.initialize();
      
      // Check initial connectivity state
      await _updateConnectivityState();
      
      // Start listening for connectivity changes
      _startListening();
      
      print('🌐 ConnectivityMonitorService initialized. Current state: ${_currentState.name}');
    } catch (e) {
      print('❌ Error initializing ConnectivityMonitorService: $e');
    }
  }

  /// Start listening for connectivity changes
  void _startListening() {
    _connectivitySubscription?.cancel();
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        await _handleConnectivityChange(results);
      },
      onError: (error) {
        print('❌ Connectivity stream error: $error');
      },
    );
  }

  /// Handle connectivity change events
  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    try {
      final previousState = _currentState;
      final newState = _determineConnectivityState(results);
      
      if (newState != previousState) {
        final now = DateTime.now();
        Duration? offlineDuration;
        
        // Handle state transitions
        if (newState == ConnectivityState.connected) {
          _lastConnectedTime = now;
          
          // Calculate offline duration if we were previously disconnected
          if (previousState == ConnectivityState.disconnected && _lastDisconnectedTime != null) {
            offlineDuration = now.difference(_lastDisconnectedTime!);
            await _cacheManager.updateLastActiveTime(now);
          }
        } else if (newState == ConnectivityState.disconnected) {
          _lastDisconnectedTime = now;
          await _cacheManager.updateLastOfflineTime(now);
        }
        
        _currentState = newState;
        
        // Create change event
        final changeEvent = ConnectivityChangeEvent(
          previousState: previousState,
          currentState: newState,
          timestamp: now,
          connectivityResults: results,
          offlineDuration: offlineDuration,
        );
        
        // Emit events
        _connectivityChangeController.add(changeEvent);
        
        if (changeEvent.isReconnection) {
          _reconnectionController.add(true);
          await _handleReconnection(offlineDuration);
        }
        
        print('🌐 Connectivity changed: $changeEvent');
      }
    } catch (e) {
      print('❌ Error handling connectivity change: $e');
    }
  }

  /// Handle reconnection events and check if sync should be triggered
  Future<void> _handleReconnection(Duration? offlineDuration) async {
    try {
      const syncThreshold = Duration(minutes: 15);
      
      print('🔄 Device reconnected after ${offlineDuration?.inMinutes ?? 0} minutes');
      
      // Check if we should trigger a sync based on offline duration
      if (offlineDuration != null && offlineDuration >= syncThreshold) {
        print('✅ Offline duration exceeds threshold. Auto-sync should be triggered.');
        
        // Update cache manager state
        await _cacheManager.updateLastActiveTime();
        
        // This event will be picked up by the AutoLocationSyncService
        // The actual sync logic is handled there to maintain separation of concerns
      } else if (offlineDuration != null) {
        print('⏭️ Offline duration (${offlineDuration.inMinutes}min) below threshold (${syncThreshold.inMinutes}min). Skipping auto-sync.');
      }
    } catch (e) {
      print('❌ Error handling reconnection: $e');
    }
  }

  /// Determine connectivity state from results
  ConnectivityState _determineConnectivityState(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityState.unknown;
    
    // Check if any result indicates connectivity
    final hasConnection = results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn ||
      result == ConnectivityResult.bluetooth
    );
    
    return hasConnection ? ConnectivityState.connected : ConnectivityState.disconnected;
  }

  /// Update current connectivity state by checking current connection
  Future<void> _updateConnectivityState() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final state = _determineConnectivityState(results);
      
      if (state != _currentState) {
        final now = DateTime.now();
        
        if (state == ConnectivityState.connected) {
          _lastConnectedTime = now;
        } else if (state == ConnectivityState.disconnected) {
          _lastDisconnectedTime = now;
          await _cacheManager.updateLastOfflineTime(now);
        }
        
        _currentState = state;
      }
    } catch (e) {
      print('❌ Error updating connectivity state: $e');
      _currentState = ConnectivityState.unknown;
    }
  }

  /// Manually refresh connectivity state
  Future<void> refreshConnectivityState() async {
    await _updateConnectivityState();
    print('🔄 Connectivity state refreshed: ${_currentState.name}');
  }

  /// Check if device has been offline long enough to trigger sync
  bool shouldTriggerSyncDueToReconnection({Duration threshold = const Duration(minutes: 15)}) {
    if (_lastDisconnectedTime == null || _lastConnectedTime == null) {
      return false;
    }
    
    // Check if the last reconnection was recent and followed a long offline period
    final timeSinceReconnection = DateTime.now().difference(_lastConnectedTime!);
    final wasRecentlyReconnected = timeSinceReconnection < const Duration(minutes: 5);
    
    if (!wasRecentlyReconnected) return false;
    
    // Check if offline duration was significant
    final offlineDuration = _lastConnectedTime!.difference(_lastDisconnectedTime!);
    return offlineDuration >= threshold;
  }

  /// Get detailed connectivity status
  Map<String, dynamic> getConnectivityStatus() {
    return {
      'currentState': _currentState.name,
      'isConnected': isConnected,
      'isDisconnected': isDisconnected,
      'lastConnectedTime': _lastConnectedTime?.toIso8601String(),
      'lastDisconnectedTime': _lastDisconnectedTime?.toIso8601String(),
      'currentOfflineDuration': _lastDisconnectedTime != null && isDisconnected
          ? DateTime.now().difference(_lastDisconnectedTime!).inMinutes
          : null,
      'shouldTriggerSync': shouldTriggerSyncDueToReconnection(),
    };
  }

  /// Force trigger a reconnection event for testing
  Future<void> simulateReconnection({Duration? offlineDuration}) async {
    final mockOfflineDuration = offlineDuration ?? const Duration(minutes: 20);
    
    print('🧪 Simulating reconnection after ${mockOfflineDuration.inMinutes} minutes offline');
    
    await _handleReconnection(mockOfflineDuration);
    _reconnectionController.add(true);
  }

  /// Stop monitoring
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityChangeController.close();
    _reconnectionController.close();
    print('🗑️ ConnectivityMonitorService disposed');
  }

  /// Debug method to print current state
  void debugPrintState() {
    final status = getConnectivityStatus();
    print('🌐 ConnectivityMonitorService State:');
    print('  Current State: ${status['currentState']}');
    print('  Is Connected: ${status['isConnected']}');
    print('  Last Connected: ${status['lastConnectedTime']}');
    print('  Last Disconnected: ${status['lastDisconnectedTime']}');
    print('  Current Offline Duration: ${status['currentOfflineDuration']} min');
    print('  Should Trigger Sync: ${status['shouldTriggerSync']}');
  }
}

/// Extension methods for ConnectivityResult
extension ConnectivityResultExtension on ConnectivityResult {
  String get displayName {
    switch (this) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  bool get isActive {
    switch (this) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
      case ConnectivityResult.bluetooth:
        return true;
      case ConnectivityResult.other:
      case ConnectivityResult.none:
        return false;
    }
  }
}