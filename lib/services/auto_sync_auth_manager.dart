import 'dart:async';
import 'auto_location_sync_service.dart';
import 'background_sync_worker.dart';
import 'location_cache_manager.dart';
import '../models/user.dart';

/// Manages the integration between authentication and auto location sync
class AutoSyncAuthManager {
  static AutoSyncAuthManager? _instance;
  static AutoSyncAuthManager get instance => _instance ??= AutoSyncAuthManager._();
  AutoSyncAuthManager._();

  final AutoLocationSyncService _syncService = AutoLocationSyncService.instance;
  final LocationCacheManager _cacheManager = LocationCacheManager.instance;

  /// Update authentication token for auto-sync services
  Future<void> updateAuthToken(String token) async {
    try {
      // Update token in sync service
      _syncService.setAuthToken(token);
      
      // Store for background sync
      await BackgroundSyncPreferences.setAuthToken(token);
      
      print('✅ Auto-sync auth token updated');
    } catch (e) {
      print('❌ Failed to update auto-sync auth token: $e');
    }
  }

  /// Set user ID and initialize user-specific sync
  Future<void> setUser(User user) async {
    try {
      await _cacheManager.setUserId(user.id);
      
      print('✅ Auto-sync user set: ${user.id}');
    } catch (e) {
      print('❌ Failed to set auto-sync user: $e');
    }
  }

  /// Complete authentication setup for auto-sync
  Future<void> onLoginSuccess(User user, String token) async {
    try {
      // Update both user and token
      await Future.wait([
        setUser(user),
        updateAuthToken(token),
      ]);
      
      print('✅ Auto-sync login setup complete');
    } catch (e) {
      print('❌ Auto-sync login setup failed: $e');
    }
  }

  /// Clear all auto-sync data on logout
  Future<void> onLogout() async {
    try {
      // Clear auth token
      _syncService.setAuthToken('');
      await BackgroundSyncPreferences.clearAuthToken();
      
      // Clear user data
      await _cacheManager.clearAll();
      
      print('✅ Auto-sync logout cleanup complete');
    } catch (e) {
      print('❌ Auto-sync logout cleanup failed: $e');
    }
  }

  /// Get sync status for debugging
  Map<String, dynamic> getSyncStatus() {
    return _syncService.getSyncStatus();
  }

  /// Start monitoring sync events (for UI updates)
  StreamSubscription<SyncResult> listenToSyncEvents(Function(SyncResult) onSyncResult) {
    return _syncService.onSyncResult.listen(onSyncResult);
  }
}