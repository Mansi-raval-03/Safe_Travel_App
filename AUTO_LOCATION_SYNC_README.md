# Auto Location Sync Feature - Implementation Guide

## Overview

This implementation provides a comprehensive auto-sync mechanism for your Flutter app that automatically syncs location data to your Node.js backend when the device reconnects to the internet after being offline for a specified duration (default: 15+ minutes).

## Features ✨

- **Automatic Connectivity Detection**: Monitors network changes (Wi-Fi, Mobile Data) in real-time
- **Offline Duration Tracking**: Tracks how long the device has been offline
- **Intelligent Sync Triggering**: Only syncs when offline duration exceeds threshold
- **Background Sync Support**: Uses Workmanager for periodic sync when app is minimized
- **Local Caching**: Stores location data locally using SharedPreferences
- **Retry Logic**: Implements exponential backoff for failed sync attempts
- **No Native Code**: Pure Dart/Flutter implementation using established packages

## Architecture

```
┌─────────────────────────────────────────┐
│         AutoLocationSyncService         │
│  (Main orchestrator & sync logic)      │
└─────────────────┬───────────────────────┘
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Cache   │ │Connectivity│Background│
│Manager  │ │Monitor   │Sync      │
└─────────┘ └─────────┘ └─────────┘
      │           │           │
      ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│Shared   │ │connectivity│workmanager│
│Prefs    │ │_plus     │          │
└─────────┘ └─────────┘ └─────────┘
```

## Installation & Setup

### 1. Dependencies

The required packages are already added to your `pubspec.yaml`:

```yaml
dependencies:
  connectivity_plus: ^6.1.0
  geolocator: ^10.1.1
  shared_preferences: ^2.3.2
  http: ^1.2.0
  workmanager: ^0.5.2
```

### 2. Permissions (Android)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 3. iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location for auto-sync functionality.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location for auto-sync functionality.</string>
```

## Implementation

### 1. Basic Setup in Main App

```dart
import 'package:flutter/material.dart';
import 'services/auto_location_sync_service.dart';
import 'services/background_sync_worker.dart';
import 'services/location_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auto location sync
  await initializeAutoLocationSync();
  
  runApp(MyApp());
}

Future<void> initializeAutoLocationSync() async {
  try {
    final syncService = AutoLocationSyncService.instance;
    final backgroundWorker = BackgroundSyncWorker.instance;
    final cacheManager = LocationCacheManager.instance;

    // Initialize background worker first
    await backgroundWorker.initialize();

    // Initialize sync service with your configuration
    await syncService.initialize(
      config: AutoSyncConfig(
        baseUrl: 'https://your-backend-url.com',
        offlineThreshold: Duration(minutes: 15),
        syncTimeout: Duration(seconds: 30),
        maxRetries: 3,
      ),
      authToken: 'your-jwt-token', // Get from your auth system
    );

    // Set user ID for location tracking
    await cacheManager.setUserId('your-user-id');

    print('✅ Auto Location Sync initialized');
  } catch (e) {
    print('❌ Failed to initialize Auto Location Sync: $e');
  }
}
```

### 2. Authentication Token Management

```dart
class AuthManager {
  static Future<void> updateSyncAuthToken(String token) async {
    // Update token in sync service
    AutoLocationSyncService.instance.setAuthToken(token);
    
    // Store for background sync
    await BackgroundSyncPreferences.setAuthToken(token);
  }

  static Future<void> onLogout() async {
    // Clear auth token
    AutoLocationSyncService.instance.setAuthToken('');
    await BackgroundSyncPreferences.clearAuthToken();
    
    // Clear location cache
    await LocationCacheManager.instance.clearAll();
  }
}
```

### 3. Location Tracking Integration

```dart
class LocationTrackingService {
  Future<void> updateLocationWithSync(double lat, double lng) async {
    try {
      // Create location data
      final locationData = CachedLocationData(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        userId: LocationCacheManager.instance.getUserId(),
      );

      // Save to cache
      await LocationCacheManager.instance.saveLastLocation(locationData);

      // Add to sync queue
      await AutoLocationSyncService.instance.queueLocationForSync(locationData);

    } catch (e) {
      print('Error updating location: $e');
    }
  }
}
```

### 4. Monitoring Sync Events

```dart
class SyncStatusWidget extends StatefulWidget {
  @override
  _SyncStatusWidgetState createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  StreamSubscription<SyncResult>? _syncSubscription;
  StreamSubscription<ConnectivityChangeEvent>? _connectivitySubscription;
  
  String _syncStatus = 'Waiting...';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    
    // Listen for sync results
    _syncSubscription = AutoLocationSyncService.instance.onSyncResult.listen((result) {
      setState(() {
        _syncStatus = result.success 
          ? 'Synced ${result.locationsSynced} locations'
          : 'Sync failed: ${result.message}';
      });
    });

    // Listen for connectivity changes
    _connectivitySubscription = ConnectivityMonitorService.instance
        .onConnectivityChanged.listen((event) {
      setState(() {
        _isConnected = event.currentState == ConnectivityState.connected;
      });
      
      if (event.isReconnection) {
        setState(() {
          _syncStatus = 'Reconnected after ${event.offlineDuration?.inMinutes ?? 0} minutes';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            SizedBox(width: 8),
            Text(_isConnected ? 'Connected' : 'Offline'),
          ],
        ),
        Text('Sync Status: $_syncStatus'),
      ],
    );
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
```

## Backend Integration

### 1. API Endpoint

The backend endpoint `/api/v1/location/sync` is already implemented in your Node.js server. It accepts:

```javascript
POST /api/v1/location/sync
Headers: {
  "Authorization": "Bearer <jwt_token>",
  "Content-Type": "application/json"
}

Body: {
  "locations": [
    {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "timestamp": "2024-01-01T12:00:00.000Z",
      "accuracy": 10.0
    }
  ],
  "deviceInfo": {
    "offlineDuration": 20,  // minutes
    "deviceType": "mobile",
    "platform": "android"
  },
  "syncReason": "auto_reconnection"
}
```

### 2. Response Format

```javascript
{
  "success": true,
  "message": "Location sync completed (after 20 minutes offline)",
  "data": {
    "processed": 1,
    "saved": 1,
    "skipped": 0,
    "syncedAt": "2024-01-01T12:05:00.000Z",
    "syncReason": "auto_reconnection",
    "offlineDuration": 20
  }
}
```

## Configuration Options

### AutoSyncConfig

```dart
const AutoSyncConfig({
  Duration offlineThreshold = const Duration(minutes: 15),
  Duration syncTimeout = const Duration(seconds: 30),
  int maxRetries = 3,
  Duration retryDelay = const Duration(seconds: 5),
  String baseUrl = 'http://localhost:3000',
  bool enableBackgroundSync = true,
});
```

### Background Sync Preferences

```dart
// Enable/disable background sync
await BackgroundSyncPreferences.setEnabled(true);

// Set sync frequency
await BackgroundSyncPreferences.setFrequencyMinutes(15);

// Check if enabled
bool isEnabled = await BackgroundSyncPreferences.isEnabled();
```

## Testing & Debugging

### 1. Manual Testing

```dart
// Trigger manual sync
final result = await AutoLocationSyncService.instance.triggerSync(reason: 'manual_test');
print('Sync result: $result');

// Simulate reconnection
await ConnectivityMonitorService.instance.simulateReconnection(
  offlineDuration: Duration(minutes: 20),
);

// Check sync status
final status = AutoLocationSyncService.instance.getSyncStatus();
print('Sync status: $status');
```

### 2. Debug Information

```dart
// Print debug info to console
AutoLocationSyncService.instance.debugPrintStatus();
LocationCacheManager.instance.debugPrintState();
ConnectivityMonitorService.instance.debugPrintState();
```

### 3. Backend Test Endpoint

```bash
# Test backend sync endpoint
curl -X POST http://localhost:3000/api/v1/location/sync/test \
  -H "Authorization: Bearer your-jwt-token"
```

## Troubleshooting

### Common Issues

1. **Sync Not Triggering**
   - Check if offline duration exceeds threshold (default: 15 minutes)
   - Verify internet connectivity
   - Ensure auth token is valid
   - Check if location data exists in cache

2. **Background Sync Not Working**
   - Verify workmanager is initialized
   - Check device battery optimization settings
   - Ensure app has location permissions
   - Verify auth token is stored for background use

3. **Location Not Cached**
   - Check location permissions
   - Verify geolocator configuration
   - Ensure LocationCacheManager is initialized

4. **Backend Sync Failures**
   - Check server logs for errors
   - Verify API endpoint is accessible
   - Check authentication token validity
   - Ensure request format matches expected schema

### Debug Commands

```dart
// Get comprehensive status
final status = AutoLocationSyncService.instance.getSyncStatus();
print('Full status: ${JsonEncoder.withIndent('  ').convert(status)}');

// Clear all cached data
await LocationCacheManager.instance.clearAll();

// Cancel all background tasks
await BackgroundSyncWorker.instance.cancelAllTasks();
```

## Performance Considerations

1. **Battery Usage**: Background sync runs every 15 minutes by default
2. **Data Usage**: Only syncs when connected to Wi-Fi or mobile data
3. **Storage**: Cached locations are limited to last 50 entries
4. **Network**: Implements retry logic with exponential backoff

## Security Notes

1. **Auth Token Storage**: Tokens are stored in SharedPreferences (not secure storage)
2. **HTTPS Required**: Use HTTPS in production
3. **Location Privacy**: Location data is only synced when user is authenticated
4. **Background Access**: Background sync requires proper permissions

## Integration Checklist

- [ ] Add required dependencies to pubspec.yaml
- [ ] Configure Android permissions
- [ ] Configure iOS permissions  
- [ ] Initialize services in main()
- [ ] Set up authentication token management
- [ ] Integrate with existing location tracking
- [ ] Add sync status monitoring (optional)
- [ ] Configure backend URL and settings
- [ ] Test manual sync functionality
- [ ] Test automatic reconnection sync
- [ ] Verify background sync works
- [ ] Test with real offline/online scenarios

## Example Usage

See the complete working example in `lib/examples/auto_location_sync_example.dart` which demonstrates:

- Service initialization
- Manual sync triggering
- Connectivity monitoring
- Status monitoring
- Debug functionality

This implementation provides a robust, battery-efficient solution for automatically syncing location data when connectivity is restored after extended offline periods.