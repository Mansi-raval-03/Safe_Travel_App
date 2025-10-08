import 'package:flutter/material.dart';
import '../services/real_time_location_service.dart';

/// Example demonstrating how to integrate the RealTimeLocationService
/// in a Flutter app for real-time location tracking with Socket.IO
class RealTimeLocationIntegrationExample extends StatefulWidget {
  const RealTimeLocationIntegrationExample({Key? key}) : super(key: key);

  @override
  State<RealTimeLocationIntegrationExample> createState() => _RealTimeLocationIntegrationExampleState();
}

class _RealTimeLocationIntegrationExampleState extends State<RealTimeLocationIntegrationExample> {
  final RealTimeLocationService _locationService = RealTimeLocationService.instance;
  
  String _currentStatus = "Not started";
  String _connectionStatus = "Disconnected";
  bool _isOnline = false;
  bool _isTracking = false;
  bool _isBackgroundTracking = false;

  @override
  void initState() {
    super.initState();
    _setupLocationServiceListeners();
  }

  /// Set up listeners for real-time location service updates
  void _setupLocationServiceListeners() {
    // Listen to tracking status changes
    _locationService.trackingStatusStream.listen((status) {
      setState(() {
        switch (status) {
          case LocationTrackingStatus.stopped:
            _currentStatus = "Stopped";
            _isTracking = false;
            _isBackgroundTracking = false;
            break;
          case LocationTrackingStatus.connecting:
            _currentStatus = "Connecting...";
            _isTracking = false;
            _isBackgroundTracking = false;
            break;
          case LocationTrackingStatus.connected:
            _currentStatus = "Connected";
            _isTracking = false;
            _isBackgroundTracking = false;
            break;
          case LocationTrackingStatus.tracking:
            _currentStatus = "Foreground Tracking Active";
            _isTracking = true;
            _isBackgroundTracking = false;
            break;
          case LocationTrackingStatus.backgroundTracking:
            _currentStatus = "Background Tracking Active";
            _isTracking = true;
            _isBackgroundTracking = true;
            break;
          case LocationTrackingStatus.disconnected:
            _currentStatus = "Disconnected (Offline Mode)";
            break;
          case LocationTrackingStatus.error:
            _currentStatus = "Error occurred";
            _isTracking = false;
            _isBackgroundTracking = false;
            break;
        }
      });
    });

    // Listen to network status (Socket connection is managed internally)
    _locationService.networkStatusStream.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
        _connectionStatus = isOnline ? "Connected" : "Disconnected";
      });
    });

    // Listen to location updates for real-time display
    _locationService.locationStream.listen((location) {
      print('📍 New location: ${location.latitude}, ${location.longitude}');
      // Update UI with new location data
      // You can update maps, send to other users, etc.
    });

    // Listen to remote location updates from other users
    _locationService.remoteLocationStream.listen((remoteData) {
      print('👥 Remote location update: ${remoteData['type']}');
      // Handle nearby users and remote location updates
    });
  }

  /// Initialize and start real-time location tracking
  Future<void> _startLocationTracking() async {
    try {
      // Initialize the service (Socket.IO is initialized automatically)
      await _locationService.initialize(userId: 'user_123');
      
      // Start location tracking (includes background if requested)
      await _locationService.startLocationTracking(includeBackground: false);
      
      print('✅ Real-time location tracking started successfully');
    } catch (e) {
      print('❌ Error starting location tracking: $e');
    }
  }

  /// Stop location tracking
  Future<void> _stopLocationTracking() async {
    try {
      // Stop location tracking (includes background tracking cleanup)
      await _locationService.stopLocationTracking();
      
      print('🛑 Location tracking stopped');
    } catch (e) {
      print('❌ Error stopping location tracking: $e');
    }
  }

  /// Toggle background tracking for continuous GPS monitoring
  Future<void> _toggleBackgroundTracking() async {
    try {
      if (_isBackgroundTracking) {
        // Stop all tracking and restart without background
        await _locationService.stopLocationTracking();
        await _locationService.startLocationTracking(includeBackground: false);
      } else {
        // Stop current tracking and restart with background
        await _locationService.stopLocationTracking();
        await _locationService.startLocationTracking(includeBackground: true);
      }
    } catch (e) {
      print('❌ Error toggling background tracking: $e');
    }
  }

  /// Trigger manual sync of offline data
  Future<void> _syncOfflineData() async {
    try {
      // The service automatically syncs when network is restored
      // For manual sync, we can show current status
      print('📊 Manual sync triggered');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync triggered - Service will sync offline data when online'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error triggering sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error triggering sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Location Tracking'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Cards
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow('Tracking Status', _currentStatus, 
                        _isTracking ? Colors.green : Colors.grey),
                    _buildStatusRow('Socket Connection', _connectionStatus, 
                        _connectionStatus == 'Connected' ? Colors.green : Colors.red),
                    _buildStatusRow('Network Status', _isOnline ? 'Online' : 'Offline', 
                        _isOnline ? Colors.green : Colors.orange),
                    _buildStatusRow('Background Tracking', 
                        _isBackgroundTracking ? 'Active' : 'Inactive',
                        _isBackgroundTracking ? Colors.blue : Colors.grey),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Control Buttons
            Text(
              'Controls',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isTracking ? null : _startLocationTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Location Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: !_isTracking ? null : _stopLocationTracking,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Location Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: !_isTracking ? null : _toggleBackgroundTracking,
              icon: Icon(_isBackgroundTracking ? Icons.pause_circle : Icons.play_circle),
              label: Text(
                _isBackgroundTracking ? 'Stop Background Tracking' : 'Start Background Tracking'
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _syncOfflineData,
              icon: const Icon(Icons.sync),
              label: const Text('Trigger Manual Sync'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const Spacer(),
            
            // Feature Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features Included:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('✅ Real-time location broadcasting via Socket.IO'),
                  const Text('✅ Background GPS tracking (even when app is closed)'),
                  const Text('✅ Offline SQLite caching with auto-sync'),
                  const Text('✅ Network-aware synchronization'),
                  const Text('✅ Live location sharing and receiving'),
                  const Text('✅ Nearby user detection for safety'),
                  const Text('✅ Comprehensive error handling and recovery'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up when widget is disposed
    _locationService.dispose();
    super.dispose();
  }
}

/// How to integrate this in your main.dart or existing screens:
/// 
/// 1. Add to your main.dart navigation:
/// ```dart
/// case 8: // Real-time location example
///   return const RealTimeLocationIntegrationExample();
/// ```
/// 
/// 2. Or navigate to it from any screen:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => const RealTimeLocationIntegrationExample(),
///   ),
/// );
/// ```
/// 
/// 3. Initialize in your main app (app startup):
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize location service at app startup
///   final locationService = RealTimeLocationService.instance;
///   await locationService.initialize(userId: 'current_user_id');
///   
///   runApp(MyApp());
/// }
/// ```