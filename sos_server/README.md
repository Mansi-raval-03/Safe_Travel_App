# Offline SOS Alert System

## Overview
The Offline SOS Alert System enables emergency communication on local networks without internet connectivity. It consists of a Flutter mobile client and a Node.js Socket.IO server that can run on any device with WiFi hotspot capability.

## System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│  SOS Server      │◄──►│   Flutter App   │
│   (Client 1)    │    │  (Node.js +      │    │   (Client 2)    │
│                 │    │   Socket.IO)     │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                        │                        ▲
         │                        ▼                        │
         │              ┌──────────────────┐              │
         └──────────────►│   SQLite DB      │◄─────────────┘
                        │  (Alert Storage) │
                        └──────────────────┘
```

## Features

### Flutter Client Features
- 📡 **Auto Server Discovery**: Scans local network for SOS servers
- 🔗 **Real-time Connection**: Socket.IO connection with status monitoring
- 🚨 **SOS Alert Types**: Emergency, Medical, Fire, Police, Accident
- 📍 **GPS Location**: Automatic location tagging with accuracy
- 💬 **Custom Messages**: Optional emergency descriptions
- 📱 **Responsive UI**: Material Design with connection indicators

### Server Features  
- 🌐 **Web Dashboard**: Real-time HTML dashboard at server URL
- 📡 **Socket.IO Broadcast**: Real-time alert distribution to all clients
- 💾 **SQLite Storage**: Persistent alert storage with full metadata
- 📊 **Statistics API**: Connection counts and alert statistics
- 🔧 **RESTful API**: HTTP endpoints for data access and management
- 🖥️ **Cross-Platform**: Runs on Windows, Mac, Linux

## Quick Start

### 1. Start the SOS Server
```bash
cd sos_server
npm install
npm start
```
Or use the batch file on Windows:
```bash
start_server.bat
```

### 2. Configure Network
- Server runs on port 3001
- Connect all devices to the same WiFi network
- For offline use, create a WiFi hotspot on the server device

### 3. Use Flutter App
- Open the Safe Travel App
- Navigate to Offline SOS screen (screen index 8)
- App will automatically discover the server
- Connect and send SOS alerts

## Server Endpoints

### Socket.IO Events
- `user_init` - Client registration
- `sos_alert` - Send emergency alert
- `sos_alert_broadcast` - Receive emergency broadcasts

### HTTP API
- `GET /` - Web dashboard
- `GET /stats` - Server statistics
- `GET /alerts` - All stored alerts
- `DELETE /alerts` - Clear all alerts

## Installation & Setup

### Prerequisites
- Node.js 14+ for server
- Flutter 3.0+ for mobile app
- WiFi network or hotspot capability

### Server Installation
```bash
cd safe_travel_app_Frontend/sos_server
npm install
```

### Flutter Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  socket_io_client: ^3.1.2
  geolocator: ^10.1.1
```

## Usage Scenarios

### 1. Home/Office Network
- Run server on a computer/laptop
- All mobile devices connect to same WiFi
- Server provides central communication hub

### 2. Mobile Hotspot (Offline)
- Run server on laptop with mobile hotspot
- Mobile devices connect to hotspot WiFi
- No internet required - pure local communication

### 3. Camping/Remote Areas
- Portable device (laptop + power bank) runs server
- Create WiFi hotspot for emergency communication
- GPS coordinates shared for rescue coordination

## Technical Details

### Network Discovery
The Flutter app uses IP scanning to discover SOS servers:
```dart
// Scans network range 192.168.1.1-254 on port 3001
for (int i = 1; i <= 254; i++) {
  final ip = '192.168.1.$i';
  // Test Socket.IO connection
}
```

### Alert Data Structure
```json
{
  "id": "unique-alert-id",
  "alertType": "emergency|medical|fire|police|accident", 
  "message": "Optional custom message",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "user": {
    "id": "user-id",
    "name": "User Name",
    "phone": "+1234567890"
  },
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 5.0
  },
  "device": {
    "platform": "android|ios",
    "model": "Device Model",
    "version": "OS Version"
  }
}
```

### Database Schema (SQLite)
```sql
CREATE TABLE sos_alerts (
  id TEXT PRIMARY KEY,
  alert_type TEXT NOT NULL,
  message TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  user_id TEXT,
  user_name TEXT,
  user_phone TEXT,
  latitude REAL,
  longitude REAL,
  location_accuracy REAL,
  device_platform TEXT,
  device_model TEXT,
  device_version TEXT
);
```

## Security Considerations

### Network Security
- System designed for trusted local networks
- No authentication implemented (trust-based)
- Consider WPA2/WPA3 WiFi encryption
- Firewall rules may need adjustment for port 3001

### Data Privacy
- All data stored locally on server device
- No cloud storage or external transmission
- Alerts contain location data - handle appropriately
- Clear alert history regularly if needed

## Troubleshooting

### Common Issues

**Server Discovery Fails**
- Check all devices on same network subnet
- Verify port 3001 is open and accessible
- Test manual connection: `http://server-ip:3001`
- Check firewall settings

**Connection Drops**
- Ensure WiFi signal strength is adequate
- Check server device power/sleep settings
- Monitor server logs for error messages

**Location Not Available**
- Enable location permissions in Flutter app
- Check GPS signal availability
- Fallback: Manual location input

### Debug Tools
- Server logs: Check console output
- Web dashboard: Monitor real-time status
- Flutter debug: Use `flutter run` in debug mode
- Network tools: Use `ping` and `telnet` for connectivity

## Performance

### Scalability
- Tested with 10+ concurrent clients
- SQLite handles thousands of alerts
- Memory usage scales with connected clients
- Consider server hardware for large deployments

### Battery Optimization
- Flutter app uses minimal background processing
- Server discovery runs periodically, not continuously
- Socket.IO connection is efficient for mobile devices

## Development

### Adding Features
- Extend `/lib/services/offline_sos_service.dart` for client features
- Modify `/sos_server/server.js` for server capabilities
- Update database schema in server startup code

### Testing
```bash
# Test server endpoints
curl http://localhost:3001/stats
curl http://localhost:3001/alerts

# Test Flutter app
flutter test
flutter run
```

### Contributing
1. Fork the repository
2. Create feature branch
3. Test on multiple devices
4. Submit pull request

## License
This offline SOS system is part of the Safe Travel App project and follows the same licensing terms.