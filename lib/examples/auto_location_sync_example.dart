import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auto_location_sync_service.dart';
import '../services/background_sync_worker.dart';
import '../services/connectivity_monitor_service.dart';
import '../services/location_cache_manager.dart';

/// Example widget demonstrating auto location sync integration
class AutoLocationSyncExample extends StatefulWidget {
  const AutoLocationSyncExample({Key? key}) : super(key: key);

  @override
  State<AutoLocationSyncExample> createState() => _AutoLocationSyncExampleState();
}

class _AutoLocationSyncExampleState extends State<AutoLocationSyncExample> {
  final AutoLocationSyncService _syncService = AutoLocationSyncService.instance;
  final BackgroundSyncWorker _backgroundWorker = BackgroundSyncWorker.instance;
  final ConnectivityMonitorService _connectivityMonitor = ConnectivityMonitorService.instance;
  final LocationCacheManager _cacheManager = LocationCacheManager.instance;

  bool _isInitialized = false;
  String _status = 'Not initialized';
  String _lastSyncResult = 'No sync performed yet';
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all auto location sync services
  Future<void> _initializeServices() async {
    try {
      setState(() => _status = 'Initializing services...');

      // Initialize background worker first
      await _backgroundWorker.initialize();

      // Initialize sync service with configuration
      await _syncService.initialize(
        config: const AutoSyncConfig(
          baseUrl: 'http://localhost:3000', // Replace with your backend URL
          offlineThreshold: Duration(minutes: 15),
          syncTimeout: Duration(seconds: 30),
          maxRetries: 3,
        ),
        authToken: 'your-jwt-token-here', // Replace with actual token
      );

      // Set user ID for location tracking
      await _cacheManager.setUserId('user-123'); // Replace with actual user ID

      // Listen for sync results
      _syncService.onSyncResult.listen((result) {
        setState(() {
          _lastSyncResult = result.toString();
        });
      });

      // Listen for connectivity changes
      _connectivityMonitor.onConnectivityChanged.listen((event) {
        if (mounted) {
          _updateStatus();
          if (event.isReconnection) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reconnected after ${event.offlineDuration?.inMinutes ?? 0} minutes'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      });

      setState(() {
        _isInitialized = true;
        _status = 'All services initialized successfully';
      });

      _updateStatus();

    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  /// Update sync status display
  void _updateStatus() {
    setState(() {
      _syncStatus = _syncService.getSyncStatus();
    });
  }

  /// Manually trigger sync
  Future<void> _triggerManualSync() async {
    try {
      setState(() => _status = 'Starting manual sync...');
      
      final result = await _syncService.triggerSync(reason: 'manual');
      
      setState(() {
        _status = result.success ? 'Manual sync completed' : 'Manual sync failed';
        _lastSyncResult = result.toString();
      });

      _updateStatus();

    } catch (e) {
      setState(() => _status = 'Manual sync error: $e');
    }
  }

  /// Simulate offline/online cycle for testing
  Future<void> _simulateReconnection() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulating reconnection after 20 minutes offline...'),
          duration: Duration(seconds: 2),
        ),
      );

      await _connectivityMonitor.simulateReconnection(
        offlineDuration: const Duration(minutes: 20),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulation error: $e')),
      );
    }
  }

  /// Schedule immediate background sync
  Future<void> _scheduleBackgroundSync() async {
    await _backgroundWorker.scheduleImmediateSync(
      delay: const Duration(seconds: 10),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Background sync scheduled in 10 seconds'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Location Sync Demo'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _isInitialized ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controls',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isInitialized ? _triggerManualSync : null,
                          child: const Text('Manual Sync'),
                        ),
                        ElevatedButton(
                          onPressed: _isInitialized ? _simulateReconnection : null,
                          child: const Text('Simulate Reconnection'),
                        ),
                        ElevatedButton(
                          onPressed: _isInitialized ? _scheduleBackgroundSync : null,
                          child: const Text('Schedule Background Sync'),
                        ),
                        ElevatedButton(
                          onPressed: _updateStatus,
                          child: const Text('Refresh Status'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Last Sync Result
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Sync Result',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_lastSyncResult),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Detailed Status
            if (_syncStatus != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detailed Status',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _syncStatus.toString()),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _formatStatusJson(_syncStatus!),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Debug Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _syncService.debugPrintStatus();
                            _cacheManager.debugPrintState();
                            _connectivityMonitor.debugPrintState();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('Print Debug Info'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _cacheManager.clearAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cache cleared')),
                            );
                            _updateStatus();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Clear Cache'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _backgroundWorker.cancelAllTasks();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Background tasks cancelled')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Cancel Background Tasks'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format JSON for display
  String _formatStatusJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  @override
  void dispose() {
    // Note: Don't dispose services here as they might be used elsewhere
    super.dispose();
  }
}

/// Simple usage example for integration in main app
class SimpleAutoLocationSyncExample extends StatelessWidget {
  const SimpleAutoLocationSyncExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeAutoSync(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const SimpleAutoLocationSyncExample(),
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Auto Sync Enabled'),
            backgroundColor: Colors.green,
          ),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text(
                  'Auto Location Sync is Active',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Your location will automatically sync when\nreconnecting after being offline for 15+ minutes',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Initialize auto sync services
  Future<void> _initializeAutoSync() async {
    final syncService = AutoLocationSyncService.instance;
    final backgroundWorker = BackgroundSyncWorker.instance;
    final cacheManager = LocationCacheManager.instance;

    // Initialize background worker
    await backgroundWorker.initialize();

    // Initialize sync service
    await syncService.initialize(
      config: const AutoSyncConfig(
        baseUrl: 'http://your-backend-url.com',
        offlineThreshold: Duration(minutes: 15),
      ),
      authToken: 'your-jwt-token',
    );

    // Set user ID
    await cacheManager.setUserId('your-user-id');

    print('✅ Auto Location Sync initialized successfully');
  }
}