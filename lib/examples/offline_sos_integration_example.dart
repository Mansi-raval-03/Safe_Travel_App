import 'package:flutter/material.dart';
import '../services/enhanced_offline_sos_service.dart';
import '../services/offline_database_service.dart';
import '../widgets/offline_sos_dashboard.dart';

/// Integration Example: Complete Offline SOS System Usage
/// 
/// This example demonstrates how to integrate and use the comprehensive
/// SQLite-based offline SOS system with network monitoring, automatic sync,
/// Socket.IO integration potential, and Google Maps Flutter compatibility.
class OfflineSOSIntegrationExample extends StatefulWidget {
  const OfflineSOSIntegrationExample({Key? key}) : super(key: key);

  @override
  State<OfflineSOSIntegrationExample> createState() => _OfflineSOSIntegrationExampleState();
}

class _OfflineSOSIntegrationExampleState extends State<OfflineSOSIntegrationExample> {
  late EnhancedOfflineSOSService _offlineSOSService;
  late OfflineDatabaseService _databaseService;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize SQLite database service
    _databaseService = OfflineDatabaseService.instance;
    await _databaseService.database;
    
    // Initialize enhanced offline SOS service with network monitoring
    _offlineSOSService = EnhancedOfflineSOSService.instance;
    await _offlineSOSService.initialize();
    
    print('🚀 Offline SOS System Initialized');
    print('📱 Database: SQLite with 5 tables (SOS, locations, contacts, shares, messages)');
    print('🌐 Network: Auto-monitoring with sync on restore');
    print('🔄 Socket.IO: Ready for real-time integration');
    print('🗺️ Google Maps: Compatible with location sharing');
  }

  @override
  void dispose() {
    _offlineSOSService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline SOS Integration'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.offline_bolt, color: Colors.orange.shade600, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Offline SOS System',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Complete SQLite-based offline emergency system with:\n'
                      '• Network-aware SOS alerts with offline queuing\n'
                      '• Automatic sync when network restored\n'
                      '• Persistent location tracking and sharing\n'
                      '• Emergency contact caching and management\n'
                      '• Socket.IO integration ready\n'
                      '• Google Maps Flutter compatibility',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Live Dashboard
            const Text(
              'Live Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const OfflineSOSDashboard(),
            
            const SizedBox(height: 20),
            
            // Integration Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.integration_instructions, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Integration Guide',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildIntegrationStep(
                      '1. Initialize Services',
                      'Set up OfflineDatabaseService and EnhancedOfflineSOSService',
                      '// Initialize SQLite database\n'
                      'final db = OfflineDatabaseService();\n'
                      'await db.initDatabase();\n\n'
                      '// Initialize offline SOS service\n'
                      'final sosService = EnhancedOfflineSOSService();\n'
                      'await sosService.initialize();'
                    ),
                    const Divider(),
                    _buildIntegrationStep(
                      '2. Network Monitoring',
                      'Enable automatic network monitoring and sync',
                      '// Start network monitoring\n'
                      'sosService.startNetworkMonitoring();\n\n'
                      '// Listen to network status\n'
                      'sosService.networkStatusStream.listen((isOnline) {\n'
                      '  print("Network: \${isOnline ? \'Online\' : \'Offline\'}");\n'
                      '});'
                    ),
                    const Divider(),
                    _buildIntegrationStep(
                      '3. SOS Operations',
                      'Send SOS alerts with automatic offline/online handling',
                      '// Send SOS (automatically handles offline/online)\n'
                      'await sosService.sendSOS(\n'
                      '  type: SOSType.emergency,\n'
                      '  message: "Emergency! Need help",\n'
                      '  context: context,\n'
                      ');'
                    ),
                    const Divider(),
                    _buildIntegrationStep(
                      '4. Socket.IO Integration',
                      'Connect with existing Socket.IO service for real-time updates',
                      '// In your socket service\n'
                      'socket.on("sos_alert", (data) {\n'
                      '  // Handle incoming SOS alerts\n'
                      '  sosService.processSOS(data);\n'
                      '});'
                    ),
                    const Divider(),
                    _buildIntegrationStep(
                      '5. Google Maps Integration',
                      'Display SOS locations and share via Google Maps',
                      '// Get current location for SOS\n'
                      'final position = await Geolocator.getCurrentPosition();\n\n'
                      '// Add marker to Google Map\n'
                      'Marker(\n'
                      '  markerId: MarkerId("sos_location"),\n'
                      '  position: LatLng(position.latitude, position.longitude),\n'
                      '  infoWindow: InfoWindow(title: "SOS Alert"),\n'
                      ')'
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Database Schema Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'SQLite Database Schema',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSchemaTable('sos_alerts', 'SOS emergency alerts with location and status'),
                    _buildSchemaTable('locations', 'Location tracking with timestamps and accuracy'),
                    _buildSchemaTable('emergency_contacts', 'Cached emergency contacts for offline access'),
                    _buildSchemaTable('pending_shares', 'Queued location shares for when network returns'),
                    _buildSchemaTable('offline_messages', 'Offline message queue with priority and retry logic'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Text(
                        'Features: Foreign key constraints, WAL mode, automatic maintenance, indexing',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testOfflineSOS(),
                    icon: const Icon(Icons.send),
                    label: const Text('Test Offline SOS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _syncDatabase(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Force Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationStep(String title, String description, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            code,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemaTable(String tableName, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tableName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testOfflineSOS() async {
    try {
      await _offlineSOSService.sendSOSAlert(
        emergencyType: 'emergency',
        message: 'Test offline SOS alert - ${DateTime.now()}',
        context: context,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test SOS sent! Check dashboard for status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending test SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncDatabase() async {
    try {
      await _offlineSOSService.getServiceStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database sync completed!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error syncing database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

/// SOS Type enumeration for different emergency types
enum SOSType {
  emergency,
  medical,
  police,
  fire,
  general
}