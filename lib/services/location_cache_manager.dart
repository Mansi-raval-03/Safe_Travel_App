import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for cached location data
class CachedLocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final String? userId;

  const CachedLocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.userId,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'userId': userId,
    };
  }

  // Create from JSON
  factory CachedLocationData.fromJson(Map<String, dynamic> json) {
    return CachedLocationData(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      accuracy: json['accuracy']?.toDouble(),
      userId: json['userId'],
    );
  }

  @override
  String toString() {
    return 'CachedLocationData(lat: $latitude, lng: $longitude, timestamp: $timestamp)';
  }
}

/// Manages local caching of location data and sync timestamps
class LocationCacheManager {
  static const String _keyLastLocation = 'last_known_location';
  static const String _keyLastSyncTime = 'last_sync_timestamp';
  static const String _keyLastOfflineTime = 'last_offline_timestamp';
  static const String _keyLastActiveTime = 'last_active_timestamp';
  static const String _keySyncQueue = 'sync_queue_locations';
  static const String _keyUserId = 'current_user_id';

  static LocationCacheManager? _instance;
  static LocationCacheManager get instance => _instance ??= LocationCacheManager._();
  LocationCacheManager._();

  SharedPreferences? _prefs;

  /// Initialize the cache manager
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('LocationCacheManager not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // User Management
  /// Set the current user ID
  Future<void> setUserId(String userId) async {
    await prefs.setString(_keyUserId, userId);
  }

  /// Get the current user ID
  String? getUserId() {
    return prefs.getString(_keyUserId);
  }

  // Location Caching
  /// Save the last known location
  Future<void> saveLastLocation(CachedLocationData location) async {
    try {
      final json = jsonEncode(location.toJson());
      await prefs.setString(_keyLastLocation, json);
      
      // Also update last active time when location is saved
      await updateLastActiveTime();
      
      print('✅ Cached location: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      print('❌ Error saving location to cache: $e');
    }
  }

  /// Get the last known location
  CachedLocationData? getLastLocation() {
    try {
      final json = prefs.getString(_keyLastLocation);
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      return CachedLocationData.fromJson(data);
    } catch (e) {
      print('❌ Error retrieving cached location: $e');
      return null;
    }
  }

  // Timestamp Management
  /// Update the last sync timestamp
  Future<void> updateLastSyncTime([DateTime? timestamp]) async {
    final time = timestamp ?? DateTime.now();
    await prefs.setInt(_keyLastSyncTime, time.millisecondsSinceEpoch);
    print('📡 Updated last sync time: $time');
  }

  /// Get the last sync timestamp
  DateTime? getLastSyncTime() {
    final ms = prefs.getInt(_keyLastSyncTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Update the last offline timestamp
  Future<void> updateLastOfflineTime([DateTime? timestamp]) async {
    final time = timestamp ?? DateTime.now();
    await prefs.setInt(_keyLastOfflineTime, time.millisecondsSinceEpoch);
    print('📵 Updated last offline time: $time');
  }

  /// Get the last offline timestamp
  DateTime? getLastOfflineTime() {
    final ms = prefs.getInt(_keyLastOfflineTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Update the last active timestamp
  Future<void> updateLastActiveTime([DateTime? timestamp]) async {
    final time = timestamp ?? DateTime.now();
    await prefs.setInt(_keyLastActiveTime, time.millisecondsSinceEpoch);
  }

  /// Get the last active timestamp
  DateTime? getLastActiveTime() {
    final ms = prefs.getInt(_keyLastActiveTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  // Sync Queue Management
  /// Add location to sync queue for later upload
  Future<void> addToSyncQueue(CachedLocationData location) async {
    try {
      final queue = getSyncQueue();
      queue.add(location);
      
      // Keep only last 50 locations to prevent storage bloat
      if (queue.length > 50) {
        queue.removeRange(0, queue.length - 50);
      }
      
      final jsonList = queue.map((loc) => loc.toJson()).toList();
      await prefs.setString(_keySyncQueue, jsonEncode(jsonList));
      
      print('📋 Added to sync queue. Queue size: ${queue.length}');
    } catch (e) {
      print('❌ Error adding to sync queue: $e');
    }
  }

  /// Get all locations in sync queue
  List<CachedLocationData> getSyncQueue() {
    try {
      final json = prefs.getString(_keySyncQueue);
      if (json == null) return [];
      
      final List<dynamic> list = jsonDecode(json);
      return list.map((item) => CachedLocationData.fromJson(item)).toList();
    } catch (e) {
      print('❌ Error retrieving sync queue: $e');
      return [];
    }
  }

  /// Clear the sync queue after successful upload
  Future<void> clearSyncQueue() async {
    await prefs.remove(_keySyncQueue);
    print('🗑️ Cleared sync queue');
  }

  /// Remove specific items from sync queue
  Future<void> removeFromSyncQueue(List<CachedLocationData> locationsToRemove) async {
    try {
      final queue = getSyncQueue();
      
      // Remove locations that match timestamp (assuming timestamps are unique enough)
      final timestampsToRemove = locationsToRemove.map((l) => l.timestamp).toSet();
      queue.removeWhere((loc) => timestampsToRemove.contains(loc.timestamp));
      
      final jsonList = queue.map((loc) => loc.toJson()).toList();
      await prefs.setString(_keySyncQueue, jsonEncode(jsonList));
      
      print('🗑️ Removed ${locationsToRemove.length} items from sync queue. Remaining: ${queue.length}');
    } catch (e) {
      print('❌ Error removing from sync queue: $e');
    }
  }

  // Utility Methods
  /// Check if enough time has passed since last offline to trigger sync
  bool shouldTriggerSync({Duration threshold = const Duration(minutes: 15)}) {
    final lastOffline = getLastOfflineTime();
    if (lastOffline == null) return false;
    
    final timeSinceOffline = DateTime.now().difference(lastOffline);
    final shouldSync = timeSinceOffline >= threshold;
    
    print('⏱️ Time since offline: ${timeSinceOffline.inMinutes} minutes. Should sync: $shouldSync');
    return shouldSync;
  }

  /// Check if we have any location data to sync
  bool hasDataToSync() {
    final lastLocation = getLastLocation();
    final queuedLocations = getSyncQueue();
    
    final hasData = lastLocation != null || queuedLocations.isNotEmpty;
    print('📊 Has data to sync: $hasData (last location: ${lastLocation != null}, queue: ${queuedLocations.length})');
    
    return hasData;
  }

  /// Get sync status summary
  Map<String, dynamic> getSyncStatus() {
    final lastSync = getLastSyncTime();
    final lastOffline = getLastOfflineTime();
    final lastActive = getLastActiveTime();
    final lastLocation = getLastLocation();
    final queueSize = getSyncQueue().length;
    
    return {
      'lastSyncTime': lastSync?.toIso8601String(),
      'lastOfflineTime': lastOffline?.toIso8601String(),
      'lastActiveTime': lastActive?.toIso8601String(),
      'hasLastLocation': lastLocation != null,
      'lastLocationTimestamp': lastLocation?.timestamp.toIso8601String(),
      'syncQueueSize': queueSize,
      'shouldTriggerSync': shouldTriggerSync(),
      'hasDataToSync': hasDataToSync(),
      'userId': getUserId(),
    };
  }

  /// Clear all cached data (useful for logout)
  Future<void> clearAll() async {
    await Future.wait([
      prefs.remove(_keyLastLocation),
      prefs.remove(_keyLastSyncTime),
      prefs.remove(_keyLastOfflineTime),
      prefs.remove(_keyLastActiveTime),
      prefs.remove(_keySyncQueue),
      prefs.remove(_keyUserId),
    ]);
    print('🧹 Cleared all location cache data');
  }

  /// Debug method to print current cache state
  void debugPrintState() {
    final status = getSyncStatus();
    print('🔍 LocationCacheManager State:');
    print('  User ID: ${status['userId']}');
    print('  Last Sync: ${status['lastSyncTime']}');
    print('  Last Offline: ${status['lastOfflineTime']}');
    print('  Last Active: ${status['lastActiveTime']}');
    print('  Has Last Location: ${status['hasLastLocation']}');
    print('  Last Location Time: ${status['lastLocationTimestamp']}');
    print('  Sync Queue Size: ${status['syncQueueSize']}');
    print('  Should Trigger Sync: ${status['shouldTriggerSync']}');
    print('  Has Data To Sync: ${status['hasDataToSync']}');
  }
}