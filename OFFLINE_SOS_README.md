# Offline SOS System - SQLite Integration

## 🚨 Overview

This comprehensive offline SOS system provides emergency assistance capabilities with full offline support using SQLite database, network monitoring, automatic synchronization, and integration with Socket.IO and Google Maps Flutter.

## 📋 Features

### ✅ Core Features Implemented
- **SQLite Database**: Complete persistent storage with 5-table schema
- **Network-Aware SOS**: Automatic online/offline mode detection and handling
- **Offline Queuing**: Emergency alerts stored locally when network unavailable
- **Automatic Sync**: Seamless data synchronization when network restored
- **Location Tracking**: Persistent location storage with timestamps and accuracy
- **Emergency Contact Caching**: Offline access to emergency contacts
- **Real-time Status**: Stream-based network and sync status updates
- **Socket.IO Ready**: Integration points for real-time communication
- **Google Maps Compatible**: Location sharing and display integration

### 🗄️ Database Schema

#### Table Structure
```sql
1. sos_alerts - Emergency SOS alerts with location and status
   ├── id, alert_id, emergency_type, message, status
   ├── latitude, longitude, accuracy, timestamp
   └── sync_status, created_at, updated_at

2. locations - Location tracking with timestamps
   ├── id, latitude, longitude, accuracy
   ├── altitude, heading, speed, timestamp
   └── is_synced, created_at

3. emergency_contacts - Cached emergency contacts
   ├── id, name, phone, relationship
   ├── is_primary, is_active, created_at
   └── updated_at

4. pending_shares - Queued location shares
   ├── id, contact_id, message, share_type
   ├── latitude, longitude, scheduled_at
   ├── retry_count, max_retries, priority
   └── created_at

5. offline_messages - Message queue with retry logic
   ├── id, message_type, content, priority
   ├── retry_count, max_retries, scheduled_at
   └── status, created_at, updated_at
```

#### Database Features
- **Foreign Key Constraints**: Referential integrity across tables
- **WAL Mode**: Concurrent read/write operations
- **Automatic Maintenance**: Periodic cleanup and optimization
- **Indexing**: Optimized queries for performance
- **Version Management**: Database schema migrations

## 🔧 Implementation

### Core Services

#### 1. OfflineDatabaseService
```dart
// Singleton SQLite service
OfflineDatabaseService.instance

Key Methods:
- database: Get database instance
- storeSOS(): Save SOS alert offline
- storeLocation(): Track location data
- cacheEmergencyContacts(): Store contacts for offline access
- addPendingShare(): Queue location sharing
- getServiceStats(): Database statistics
```

#### 2. EnhancedOfflineSOSService
```dart
// Network-aware SOS service
EnhancedOfflineSOSService.instance

Key Methods:
- initialize(): Set up service and monitoring
- sendSOSAlert(): Send emergency alert (online/offline)
- startLocationTracking(): Begin location monitoring
- networkStatusStream: Real-time network status
- syncStatusStream: Synchronization progress
- getServiceStats(): Service statistics
```

#### 3. OfflineSOSDashboard (Widget)
```dart
// UI component for monitoring offline SOS system
OfflineSOSDashboard()

Features:
- Real-time network status display
- Database statistics and sync progress
- Test SOS functionality
- Offline capabilities overview
```

## 🚀 Integration Guide

### Basic Setup
```dart
// 1. Initialize services
final dbService = OfflineDatabaseService.instance;
await dbService.database;

final sosService = EnhancedOfflineSOSService.instance;
await sosService.initialize();

// 2. Monitor network status
sosService.networkStatusStream.listen((isOnline) {
  print('Network: ${isOnline ? 'Online' : 'Offline'}');
});

// 3. Send SOS alert (handles online/offline automatically)
await sosService.sendSOSAlert(
  emergencyType: 'emergency',
  message: 'Need immediate help!',
  context: context,
);
```

### Socket.IO Integration
```dart
// In your socket service
socket.on('sos_alert', (data) {
  // Handle incoming SOS alerts
  // Integration point for real-time notifications
});

// Send SOS via Socket.IO when online
if (sosService.isOnline) {
  socket.emit('sos_alert', sosData);
}
```

### Google Maps Integration
```dart
// Display SOS location on map
final position = await Geolocator.getCurrentPosition();

GoogleMap(
  markers: {
    Marker(
      markerId: MarkerId('sos_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(title: 'Emergency Alert'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
  },
)
```

### Network-Aware Operations
```dart
// The system automatically handles:
// ✅ Online: Direct API calls + database storage
// ✅ Offline: Local storage + queuing for sync
// ✅ Network Restore: Automatic sync of pending data

// Example: Location sharing
await sosService.sendSOSAlert(
  emergencyType: 'medical',
  message: 'Medical emergency at current location',
  context: context,
);
// → Online: Immediate SMS/WhatsApp + API call
// → Offline: Queued in SQLite, sent when network returns
```

## 📊 Monitoring & Debugging

### Dashboard Integration
```dart
// Add to your app for monitoring
Scaffold(
  body: Column(
    children: [
      // Network and sync status
      OfflineSOSDashboard(),
      
      // Your app content
      YourAppContent(),
    ],
  ),
)
```

### Service Statistics
```dart
// Get detailed service statistics
final stats = await sosService.getServiceStats();
print('Pending SOS: ${stats['pendingSOS']}');
print('Offline Messages: ${stats['offlineMessages']}');
print('Last Sync: ${stats['lastSync']}');
```

### Real-time Status Monitoring
```dart
// Network status
sosService.networkStatusStream.listen((isOnline) {
  print('Network: ${isOnline ? '🟢 Online' : '🔴 Offline'}');
});

// Sync progress
sosService.syncStatusStream.listen((status) {
  print('Sync Status: ${status['message']}');
  print('Progress: ${status['progress']}%');
});
```

## 🔄 Offline Capabilities

### What Works Offline
- ✅ Send SOS alerts (stored in SQLite)
- ✅ Track location (persistent storage)
- ✅ Access emergency contacts (cached)
- ✅ Queue location sharing
- ✅ Store emergency messages
- ✅ View service statistics

### What Syncs When Online
- 📤 Pending SOS alerts → Backend API
- 📤 Location data → Server storage  
- 📤 Queued shares → SMS/WhatsApp
- 📤 Offline messages → Real-time notifications
- 📥 Emergency contacts → Local cache update

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Safe Travel App                       │
├─────────────────────────────────────────────────────────┤
│  UI Layer: OfflineSOSDashboard, Integration Examples    │
├─────────────────────────────────────────────────────────┤
│  Service Layer: EnhancedOfflineSOSService               │
│  ├── Network Monitoring (Timer-based)                  │
│  ├── SOS Alert Processing (Online/Offline)             │
│  ├── Location Tracking & Sharing                       │
│  └── Automatic Synchronization                         │
├─────────────────────────────────────────────────────────┤
│  Data Layer: OfflineDatabaseService                     │
│  ├── SQLite Database (5 tables)                        │
│  ├── Foreign Key Constraints                           │
│  ├── WAL Mode & Indexing                               │
│  └── Automatic Maintenance                             │
├─────────────────────────────────────────────────────────┤
│  Integration Points                                     │
│  ├── Socket.IO (Real-time communication)               │
│  ├── Google Maps Flutter (Location display)            │
│  ├── Emergency Contact Service (Contact management)    │
│  └── SMS/WhatsApp (Native sharing)                     │
└─────────────────────────────────────────────────────────┘
```

## 📦 Dependencies

```yaml
dependencies:
  sqflite: ^2.4.2          # SQLite database
  geolocator: ^10.1.1      # Location services
  connectivity_plus: ^6.1.0 # Network monitoring
  path: ^1.8.3             # Database path utilities
  url_launcher: ^6.3.2     # SMS/WhatsApp sharing
  permission_handler: ^12.0.1 # Location permissions
```

## 🛠️ Troubleshooting

### Common Issues

1. **Database Access Errors**
   ```dart
   // Ensure singleton pattern usage
   final db = OfflineDatabaseService.instance; // ✅ Correct
   final db = OfflineDatabaseService();        // ❌ Wrong
   ```

2. **Network Detection Issues**
   ```dart
   // Service automatically handles network changes
   // Manual check if needed:
   final isOnline = sosService.isOnline;
   ```

3. **Sync Not Working**
   ```dart
   // Check service initialization
   await sosService.initialize(); // Required before use
   ```

4. **Location Permission Issues**
   ```dart
   // Service handles permissions automatically
   // Manual check if needed:
   await sosService.startLocationTracking();
   ```

### Debug Information
```dart
// Enable debug logging (already included in services)
print('📱 SOS Service Status: ${sosService.isOnline ? 'Online' : 'Offline'}');
final stats = await sosService.getServiceStats();
print('📊 Service Stats: $stats');
```

## 🎯 Usage Examples

### Emergency Scenarios

1. **Medical Emergency (Offline)**
   ```dart
   await sosService.sendSOSAlert(
     emergencyType: 'medical',
     message: 'Medical emergency - need ambulance',
     context: context,
   );
   // → Stored in SQLite, sent when network available
   ```

2. **Location Sharing (Online)**
   ```dart
   await sosService.sendSOSAlert(
     emergencyType: 'general',
     message: 'Sharing my current location',
     context: context,
   );
   // → Immediate SMS/WhatsApp + real-time notification
   ```

3. **Network Restore Sync**
   ```dart
   // Automatic when network detected
   // Manual sync available through service stats
   ```

## 🚀 Future Enhancements

- [ ] Push notification integration
- [ ] Encrypted message storage
- [ ] Batch sync optimization
- [ ] Background location tracking
- [ ] Emergency contact priority levels
- [ ] Custom retry logic per message type
- [ ] Export/import database functionality

## 📝 Implementation Status

✅ **Completed**
- SQLite database with complete schema
- Network-aware SOS service
- Automatic sync and offline queuing  
- Real-time status monitoring
- Integration examples and documentation
- Dashboard widget for monitoring

🔄 **Ready for Integration**
- Socket.IO real-time communication
- Google Maps location display
- SMS/WhatsApp native sharing
- Emergency contact management
- Location tracking and sharing

---

**Note**: This system provides a complete foundation for offline SOS functionality with SQLite persistence, network awareness, and automatic synchronization. All core components are implemented and ready for integration with Socket.IO and Google Maps Flutter as requested.