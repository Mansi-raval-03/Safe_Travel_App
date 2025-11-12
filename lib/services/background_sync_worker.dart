import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'auto_location_sync_service.dart';
import 'location_cache_manager.dart';
import 'connectivity_monitor_service.dart';

/// Background sync worker using Workmanager
class BackgroundSyncWorker {
  static const String _taskName = 'location_sync_task';
  static const String _periodicTaskName = 'periodic_location_sync_task';
  static const String _uniqueName = 'location_sync_unique';
  
  static BackgroundSyncWorker? _instance;
  static BackgroundSyncWorker get instance => _instance ??= BackgroundSyncWorker._();
  BackgroundSyncWorker._();

  bool _isInitialized = false;

  /// Initialize workmanager and register background tasks
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ BackgroundSyncWorker already initialized');
      return;
    }

    try {
      // Initialize Workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      _isInitialized = true;
      print('✅ BackgroundSyncWorker initialized');

      // Register periodic task
      await _registerPeriodicTask();

    } catch (e) {
      print('❌ Error initializing BackgroundSyncWorker: $e');
      rethrow;
    }
  }

  /// Register a periodic background sync task
  Future<void> _registerPeriodicTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _periodicTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
      
      print('📅 Periodic background sync task registered (every 15 minutes)');
    } catch (e) {
      print('❌ Error registering periodic task: $e');
    }
  }

  /// Register a one-time background sync task
  Future<void> scheduleImmediateSync({
    Duration delay = const Duration(seconds: 5),
    Map<String, dynamic>? inputData,
  }) async {
    if (!_isInitialized) {
      print('⚠️ BackgroundSyncWorker not initialized');
      return;
    }

    try {
      final uniqueName = 'immediate_sync_${DateTime.now().millisecondsSinceEpoch}';
      
      await Workmanager().registerOneOffTask(
        uniqueName,
        _taskName,
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        inputData: inputData ?? {},
      );
      
      print('⏰ Immediate sync task scheduled (delay: ${delay.inSeconds}s)');
    } catch (e) {
      print('❌ Error scheduling immediate sync: $e');
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      print('🗑️ All background sync tasks cancelled');
    } catch (e) {
      print('❌ Error cancelling tasks: $e');
    }
  }

  /// Cancel periodic task
  Future<void> cancelPeriodicTask() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      print('🗑️ Periodic sync task cancelled');
    } catch (e) {
      print('❌ Error cancelling periodic task: $e');
    }
  }

  /// Restart periodic task with new configuration
  Future<void> restartPeriodicTask({Duration? frequency}) async {
    await cancelPeriodicTask();
    await Future.delayed(const Duration(seconds: 1));
    await _registerPeriodicTask();
  }

  /// Check if background sync is supported
  bool isBackgroundSyncSupported() {
    // Background sync is generally supported on mobile platforms
    // Web doesn't support workmanager
    return defaultTargetPlatform == TargetPlatform.android || 
           defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Get background task status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSupported': isBackgroundSyncSupported(),
      'platform': defaultTargetPlatform.name,
    };
  }

  void dispose() {
    _isInitialized = false;
    print('🗑️ BackgroundSyncWorker disposed');
  }
}

/// Background task callback dispatcher
/// This function runs in background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('🔄 Background sync task started: $task');
      
      // Initialize services in background isolate
      final cacheManager = LocationCacheManager.instance;
      final connectivityMonitor = ConnectivityMonitorService.instance;
      final syncService = AutoLocationSyncService.instance;

      await cacheManager.initialize();
      await connectivityMonitor.initialize();

      // Check if we should perform sync
      final shouldSync = _shouldPerformBackgroundSync(cacheManager, connectivityMonitor);
      
      if (!shouldSync) {
        print('⏭️ Background sync not needed at this time');
        return Future.value(true);
      }

      // Get auth token from cache/storage
      // In a real app, you'd need to store this securely
      final authToken = await _getAuthTokenFromStorage();
      
      if (authToken == null) {
        // No auth token available — treat as a successful no-op so the Workmanager
        // job does not get marked as failed. Background tasks should be resilient
        // when the user is not authenticated.
        print('⚠️ No auth token available for background sync — skipping');
        return Future.value(true);
      }

      // Initialize sync service with stored token
      await syncService.initialize(
        authToken: authToken,
        config: const AutoSyncConfig(
          baseUrl: 'http://localhost:3000', // Should be configurable
          syncTimeout: Duration(seconds: 30),
          maxRetries: 2,
        ),
      );

      // Perform sync
      final result = await syncService.triggerSync(reason: 'background_task');
      
      print('📱 Background sync completed: ${result.success ? 'SUCCESS' : 'FAILED'}');
      print('   Locations synced: ${result.locationsSynced}');
      print('   Message: ${result.message}');

      return Future.value(result.success);

    } catch (e) {
      print('❌ Background sync task failed: $e');
      return Future.value(false);
    }
  });
}

/// Check if background sync should be performed
bool _shouldPerformBackgroundSync(
  LocationCacheManager cacheManager, 
  ConnectivityMonitorService connectivityMonitor
) {
  // Don't sync if not connected
  if (!connectivityMonitor.isConnected) {
    return false;
  }

  // Don't sync if no data to sync
  if (!cacheManager.hasDataToSync()) {
    return false;
  }

  // Check if enough time has passed since last sync
  final lastSync = cacheManager.getLastSyncTime();
  if (lastSync != null) {
    final timeSinceLastSync = DateTime.now().difference(lastSync);
    const minSyncInterval = Duration(minutes: 10);
    
    if (timeSinceLastSync < minSyncInterval) {
      return false;
    }
  }

  // Check if we've been offline long enough
  return cacheManager.shouldTriggerSync();
}

/// Get auth token from storage (implement based on your auth system)
Future<String?> _getAuthTokenFromStorage() async {
  try {
    // This is a placeholder implementation
    // In a real app, you'd retrieve the token from secure storage
    // For example, using flutter_secure_storage or shared_preferences
    
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    
    // You could store auth token in shared preferences
    // or use a secure storage solution
    
    // For now, return null - the main app should set this
    return null;
    
  } catch (e) {
    print('❌ Error getting auth token from storage: $e');
    return null;
  }
}

/// Helper class for managing background sync preferences
class BackgroundSyncPreferences {
  static const String _keyEnabled = 'background_sync_enabled';
  static const String _keyFrequency = 'background_sync_frequency_minutes';
  static const String _keyAuthToken = 'background_sync_auth_token';

  static Future<bool> isEnabled() async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    return cacheManager.prefs.getBool(_keyEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    await cacheManager.prefs.setBool(_keyEnabled, enabled);
    
    if (enabled) {
      await BackgroundSyncWorker.instance._registerPeriodicTask();
    } else {
      await BackgroundSyncWorker.instance.cancelPeriodicTask();
    }
  }

  static Future<int> getFrequencyMinutes() async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    return cacheManager.prefs.getInt(_keyFrequency) ?? 15;
  }

  static Future<void> setFrequencyMinutes(int minutes) async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    await cacheManager.prefs.setInt(_keyFrequency, minutes);
    
    // Restart periodic task with new frequency
    await BackgroundSyncWorker.instance.restartPeriodicTask();
  }

  static Future<void> setAuthToken(String token) async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    await cacheManager.prefs.setString(_keyAuthToken, token);
  }

  static Future<String?> getAuthToken() async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    return cacheManager.prefs.getString(_keyAuthToken);
  }

  static Future<void> clearAuthToken() async {
    final cacheManager = LocationCacheManager.instance;
    await cacheManager.initialize();
    await cacheManager.prefs.remove(_keyAuthToken);
  }
}