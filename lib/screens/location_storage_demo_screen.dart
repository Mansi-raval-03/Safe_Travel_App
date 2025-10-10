import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/offline_database_service.dart';

/// Demo screen to test periodic location storage functionality
class LocationStorageDemoScreen extends StatefulWidget {
  const LocationStorageDemoScreen({Key? key}) : super(key: key);

  @override
  State<LocationStorageDemoScreen> createState() => _LocationStorageDemoScreenState();
}

class _LocationStorageDemoScreenState extends State<LocationStorageDemoScreen> {
  final LocationService _locationService = LocationService();
  bool _isLocationServiceInitialized = false;
  bool _isTracking = false;
  bool _isPeriodicStorageActive = false;
  int _storedLocationCount = 0;
  List<Map<String, dynamic>> _recentLocations = [];

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
  }

  Future<void> _initializeLocationService() async {
    final initialized = await _locationService.initialize();
    setState(() {
      _isLocationServiceInitialized = initialized;
    });
    if (initialized) {
      _updateLocationStats();
    }
  }

  Future<void> _updateLocationStats() async {
    final count = await _locationService.getStoredLocationCount();
    final recent = await _locationService.getRecentStoredLocations(limit: 5);
    setState(() {
      _storedLocationCount = count;
      _recentLocations = recent;
      _isTracking = _locationService.isTracking;
      _isPeriodicStorageActive = _locationService.isPeriodicStorageActive;
    });
  }

  Future<void> _startPeriodicStorage() async {
    final success = await _locationService.startPeriodicLocationStorageOnly();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Periodic location storage started (every 5 minutes)'),
          backgroundColor: Colors.green,
        ),
      );
      _updateLocationStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to start periodic location storage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _stopPeriodicStorage() {
    _locationService.stopPeriodicLocationStorage();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛑 Periodic location storage stopped'),
        backgroundColor: Colors.orange,
      ),
    );
    _updateLocationStats();
  }

  void _startLocationTracking() {
    _locationService.startLocationTracking();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔄 Location tracking started with periodic storage'),
        backgroundColor: Colors.blue,
      ),
    );
    _updateLocationStats();
  }

  void _stopLocationTracking() {
    _locationService.stopLocationTracking();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛑 Location tracking stopped'),
        backgroundColor: Colors.grey,
      ),
    );
    _updateLocationStats();
  }

  Future<void> _clearStoredLocations() async {
    try {
      await OfflineDatabaseService.instance.clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ All stored locations cleared'),
          backgroundColor: Colors.red,
        ),
      );
      _updateLocationStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error clearing locations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Storage Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: !_isLocationServiceInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing location service...'),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isTracking ? Icons.gps_fixed : Icons.gps_off,
                                color: _isTracking ? Colors.green : Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text('Location Tracking: ${_isTracking ? 'Active' : 'Inactive'}'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _isPeriodicStorageActive ? Icons.save : Icons.save_outlined,
                                color: _isPeriodicStorageActive ? Colors.blue : Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text('Periodic Storage: ${_isPeriodicStorageActive ? 'Active (5min)' : 'Inactive'}'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.storage, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Stored Locations: $_storedLocationCount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Control Buttons
                  Text(
                    'Controls',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPeriodicStorageActive ? null : _startPeriodicStorage,
                          icon: Icon(Icons.play_arrow),
                          label: Text('Start Storage'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPeriodicStorageActive ? _stopPeriodicStorage : null,
                          icon: Icon(Icons.stop),
                          label: Text('Stop Storage'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTracking ? null : _startLocationTracking,
                          icon: Icon(Icons.gps_fixed),
                          label: Text('Start Tracking'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTracking ? _stopLocationTracking : null,
                          icon: Icon(Icons.gps_off),
                          label: Text('Stop Tracking'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _updateLocationStats,
                          icon: Icon(Icons.refresh),
                          label: Text('Refresh'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _clearStoredLocations,
                          icon: Icon(Icons.delete),
                          label: Text('Clear Data'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Recent Locations
                  Text(
                    'Recent Stored Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  
                  Expanded(
                    child: _recentLocations.isEmpty
                        ? Card(
                            child: Center(
                              child: Text(
                                'No locations stored yet.\nStart periodic storage to see data.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _recentLocations.length,
                            itemBuilder: (context, index) {
                              final location = _recentLocations[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(
                                    '${location['latitude'].toStringAsFixed(6)}, ${location['longitude'].toStringAsFixed(6)}',
                                  ),
                                  subtitle: Text(
                                    'Accuracy: ${location['accuracy'].toStringAsFixed(1)}m • '
                                    'Time: ${_formatTimestamp(location['timestamp'])}',
                                  ),
                                  trailing: Icon(
                                    location['is_synced'] == 1 ? Icons.cloud_done : Icons.cloud_queue,
                                    color: location['is_synced'] == 1 ? Colors.green : Colors.orange,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Don't dispose the LocationService here as it's a singleton used globally
    super.dispose();
  }
}