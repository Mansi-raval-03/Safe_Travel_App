import 'package:flutter/material.dart';
import '../services/enhanced_offline_sos_service.dart';
import '../services/offline_database_service.dart';

/// Offline SOS Dashboard Widget
/// Displays offline SOS functionality, database statistics, and sync status
class OfflineSOSDashboard extends StatefulWidget {
  const OfflineSOSDashboard({Key? key}) : super(key: key);

  @override
  State<OfflineSOSDashboard> createState() => _OfflineSOSDashboardState();
}

class _OfflineSOSDashboardState extends State<OfflineSOSDashboard> {
  late EnhancedOfflineSOSService _sosService;
  late OfflineDatabaseService _dbService;
  
  bool _isInitialized = false;
  bool _isOnline = true;
  Map<String, int> _dbStats = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _sosService = EnhancedOfflineSOSService.instance;
    _dbService = OfflineDatabaseService.instance;
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _sosService.initialize();
      await _updateDashboard();
      
      // Listen to network status changes
      _sosService.networkStatusStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
        }
      });

      // Listen to sync status changes
      _sosService.syncStatusStream.listen((syncResult) {
        if (mounted) {
          _updateDashboard();
          _showSyncNotification(syncResult);
        }
      });

      setState(() {
        _isInitialized = true;
        _isOnline = _sosService.isOnline;
      });
    } catch (e) {
      print('❌ Error initializing offline SOS dashboard: $e');
    }
  }

  Future<void> _updateDashboard() async {
    try {
      final stats = await _dbService.getDatabaseStats();
      if (mounted) {
        setState(() {
          _dbStats = stats;
        });
      }
    } catch (e) {
      print('❌ Error updating dashboard: $e');
    }
  }

  void _showSyncNotification(Map<String, dynamic> syncResult) {
    final pendingProcessed = syncResult['pending_shares_processed'] as int;
    final messagesSent = syncResult['offline_messages_sent'] as int;
    final alertsSynced = syncResult['sos_alerts_synced'] as int;

    if (pendingProcessed > 0 || messagesSent > 0 || alertsSynced > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔄 Sync completed: $pendingProcessed shares, $messagesSent messages, $alertsSynced alerts',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendTestSOS(String emergencyType) async {
    setState(() {
      _isSending = true;
    });

    try {
      final result = await _sosService.sendSOSAlert(
        emergencyType: emergencyType,
        message: 'Test SOS alert from Safe Travel App',
        context: context,
      );

      if (result['success'] == true) {
        final contactsNotified = result['contacts_notified'] as int;
        final pendingShares = result['pending_shares'] as int;
        final isOnline = result['online'] as bool;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('SOS Alert Sent'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${isOnline ? 'Online' : 'Offline'}'),
                SizedBox(height: 8),
                Text('Contacts Notified: $contactsNotified'),
                Text('Pending Shares: $pendingShares'),
                if (!isOnline) ...[
                  SizedBox(height: 8),
                  Text(
                    'Alert queued for offline sending. It will be sent when network is restored.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ SOS Alert failed: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sending SOS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
      await _updateDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing Offline SOS System...'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Offline SOS Dashboard'),
        backgroundColor: _isOnline ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.wifi : Icons.wifi_off),
            onPressed: _updateDashboard,
            tooltip: _isOnline ? 'Online' : 'Offline',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _updateDashboard,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetworkStatusCard(),
              SizedBox(height: 16),
              _buildDatabaseStatsCard(),
              SizedBox(height: 16),
              _buildSOSActionsCard(),
              SizedBox(height: 16),
              _buildOfflineCapabilitiesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _isOnline ? Colors.green : Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Network Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (_isOnline ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isOnline ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                _isOnline ? 'ONLINE - Real-time sending' : 'OFFLINE - Queued for later',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isOnline ? Colors.green[700] : Colors.orange[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Database Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatItem('SOS Alerts', _dbStats['sos_alerts'] ?? 0, Icons.warning),
            _buildStatItem('Location Records', _dbStats['locations'] ?? 0, Icons.location_on),
            _buildStatItem('Emergency Contacts', _dbStats['emergency_contacts'] ?? 0, Icons.contacts),
            _buildStatItem('Pending Shares', _dbStats['pending_shares'] ?? 0, Icons.share, 
                color: (_dbStats['pending_shares'] ?? 0) > 0 ? Colors.orange : null),
            _buildStatItem('Queued Messages', _dbStats['queued_messages'] ?? 0, Icons.message,
                color: (_dbStats['queued_messages'] ?? 0) > 0 ? Colors.red : null),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSActionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text(
                  'Test SOS Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Test the offline SOS functionality with different emergency types:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            _buildSOSButton('Medical Emergency', Icons.local_hospital, Colors.red),
            SizedBox(height: 8),
            _buildSOSButton('Police Help', Icons.local_police, Colors.blue),
            SizedBox(height: 8),
            _buildSOSButton('Fire Emergency', Icons.local_fire_department, Colors.orange),
            SizedBox(height: 8),
            _buildSOSButton('General Help', Icons.help, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : () => _sendTestSOS(label.toLowerCase()),
        icon: _isSending 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineCapabilitiesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.offline_bolt, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Offline Capabilities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildCapabilityItem(
              'SQLite Database Storage',
              'All SOS alerts and location data stored locally',
              Icons.storage,
            ),
            _buildCapabilityItem(
              'Emergency Contact Cache',
              'Contacts stored offline for immediate access',
              Icons.contacts,
            ),
            _buildCapabilityItem(
              'Message Queue System',
              'SMS and WhatsApp messages queued for sending',
              Icons.queue,
            ),
            _buildCapabilityItem(
              'Location Tracking',
              'GPS coordinates cached for offline use',
              Icons.location_on,
            ),
            _buildCapabilityItem(
              'Auto-Sync on Network Restore',
              'Automatic synchronization when online',
              Icons.sync,
            ),
            _buildCapabilityItem(
              'Real-time Status Updates',
              'Live network and sync status monitoring',
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityItem(String title, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Don't dispose the singleton services
    super.dispose();
  }
}