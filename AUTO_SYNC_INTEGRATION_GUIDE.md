# Auto Location Sync Integration Guide

## Overview

The auto location sync feature has been successfully integrated into the Safe Travel App! This feature automatically syncs location data to your backend when the device reconnects to the internet after being offline for 15+ minutes.

## 🚀 What's Been Added

### 1. Core Services
- **AutoLocationSyncService**: Main orchestrator for location syncing
- **LocationCacheManager**: Handles local location storage using SharedPreferences
- **ConnectivityMonitorService**: Monitors network connectivity changes
- **BackgroundSyncWorker**: Manages background sync using Workmanager
- **AutoSyncAuthManager**: Integrates auto-sync with app authentication

### 2. Main App Integration
The auto-sync feature is automatically initialized in `main.dart` and integrates with:
- **User Login/Signup**: Auto-sync starts when user authenticates
- **User Logout**: Auto-sync data is cleared when user logs out
- **Location Tracking**: All location updates are cached for sync

### 3. UI Integration
- **Settings Screen**: Added auto-sync status indicator
- **Real-time Status**: Shows sync state (Ready, Syncing, Off, No Auth)

## 📱 How It Works

### Automatic Operation
1. **App Startup**: Auto-sync initializes automatically
2. **User Login**: Sync service activates with user credentials
3. **Location Tracking**: All location updates are cached locally
4. **Connectivity Loss**: Service detects when device goes offline
5. **Reconnection**: When back online after 15+ minutes, locations sync automatically
6. **Background Sync**: Periodic sync continues even when app is minimized

### Manual Triggers
- Tap the Auto-Sync status card in Settings to refresh status
- Location updates trigger immediate sync attempts if connected

## 🔧 Configuration

### Current Settings
```dart
AutoSyncConfig(
  baseUrl: 'your-backend-url',           // Uses ApiConfig.currentBaseUrl
  offlineThreshold: Duration(minutes: 15), // Minimum offline time before sync
  syncTimeout: Duration(seconds: 30),      // Max time for sync requests
  maxRetries: 3,                           // Retry attempts for failed syncs
  retryDelay: Duration(seconds: 5),        // Delay between retries
  enableBackgroundSync: true,              // Background sync enabled
)
```

### Backend Integration
The feature syncs to: `POST /api/v1/location/sync`

**Expected Request:**
```json
{
  "locations": [
    {
      "latitude": 40.7128,
      "longitude": -74.0060,
      "timestamp": "2024-01-15T10:30:00.000Z",
      "accuracy": 10.0,
      "userId": "user123"
    }
  ]
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Locations synced successfully",
  "data": {
    "syncedCount": 1,
    "skippedCount": 0
  }
}
```

## 🎯 User Experience

### Status Indicators
The auto-sync status appears in Settings screen with these states:

- 🟢 **Ready**: Sync is active and ready
- 🟡 **Syncing**: Currently syncing data
- 🔴 **No Auth**: User not logged in or token expired
- ⚫ **Off**: Sync service not initialized

### Notifications
- Sync results are logged to console (development)
- Future versions can add user-facing notifications

## 🧪 Testing the Feature

### Test Offline→Online Sync
1. **Enable Location Tracking**: Use the map screen or location features
2. **Simulate Offline**: Turn off WiFi/cellular data
3. **Move Around**: Change location while offline (15+ minutes)
4. **Reconnect**: Turn data back on
5. **Check Logs**: Look for auto-sync messages in console
6. **Verify Backend**: Check if locations appeared in your database

### Test Manual Sync
1. **Go to Settings**: Open the settings screen
2. **Check Status**: View the auto-sync status card
3. **Tap to Refresh**: Tap the status card to update status
4. **Monitor Changes**: Watch status change as sync occurs

### Test Background Sync
1. **Minimize App**: Put app in background
2. **Wait 15 Minutes**: Background task should run
3. **Check Logs**: Background sync logs appear in console

## 🐛 Troubleshooting

### Sync Not Working
1. **Check Authentication**: Ensure user is logged in
2. **Verify Connectivity**: Confirm internet connection
3. **Check Permissions**: Ensure location permissions granted
4. **Review Logs**: Look for error messages in console
5. **Backend Status**: Verify backend `/api/v1/location/sync` endpoint works

### Debug Information
Use these methods for debugging:
```dart
// Get detailed sync status
final status = AutoSyncAuthManager.instance.getSyncStatus();
print(status);

// Force sync attempt
await AutoLocationSyncService.instance.triggerSync(reason: 'manual_test');

// Check cached locations
final cacheManager = LocationCacheManager.instance;
final queue = await cacheManager.getSyncQueue();
print('Locations to sync: ${queue.length}');
```

### Common Issues

**Issue**: "Auto-sync shows 'Off'"
**Solution**: Check if auto-sync initialized in main.dart

**Issue**: "Status shows 'No Auth'"  
**Solution**: Log out and log back in to refresh tokens

**Issue**: "Locations not syncing"
**Solution**: Check backend endpoint and network connectivity

**Issue**: "Background sync not working"
**Solution**: Check Android battery optimization settings

## 🔄 Code Integration Points

### Adding Custom Logic
You can integrate with the auto-sync system at these points:

**Listen to Sync Events:**
```dart
AutoLocationSyncService.instance.onSyncResult.listen((result) {
  if (result.success) {
    print('Synced ${result.locationsSynced} locations');
  } else {
    print('Sync failed: ${result.message}');
  }
});
```

**Queue Additional Data:**
```dart
final locationData = CachedLocationData(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: accuracy,
  userId: userId,
);
await LocationCacheManager.instance.saveLastLocation(locationData);
```

**Check Sync Status:**
```dart
final syncStatus = AutoSyncAuthManager.instance.getSyncStatus();
bool hasDataToSync = syncStatus['cache']['hasDataToSync'];
bool isConnected = syncStatus['connectivity']['isConnected'];
```

## 📊 Performance Notes

- **Storage**: Uses SharedPreferences for lightweight local caching
- **Memory**: Minimal memory footprint with singleton pattern
- **Battery**: Optimized background sync frequency (15-minute intervals)
- **Network**: Only syncs when connected, with retry logic for failed attempts

## 🔐 Security Notes

- **Token Management**: Auth tokens securely stored and automatically updated
- **Data Privacy**: Location data cached locally until sync, then removed
- **Authentication**: All sync requests include JWT authentication headers
- **Cleanup**: Complete data cleanup on user logout

## 🎉 Success!

Your Safe Travel App now automatically syncs location data when reconnecting after being offline! The feature works seamlessly in the background while respecting user privacy and device resources.

For any issues or questions, check the console logs for detailed debugging information.