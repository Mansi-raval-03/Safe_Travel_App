import 'package:flutter/material.dart';
import 'package:safe_travel_app/services/offline_sos_service.dart';

class OfflineSOSScreen extends StatefulWidget {
  const OfflineSOSScreen({Key? key}) : super(key: key);

  @override
  State<OfflineSOSScreen> createState() => _OfflineSOSScreenState();
}

class _OfflineSOSScreenState extends State<OfflineSOSScreen> {
  final OfflineSOSService _sosService = OfflineSOSService();
  String _selectedAlertType = 'emergency';
  final TextEditingController _messageController = TextEditingController();
  bool _isConnecting = false;
  bool _alertSent = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _initializeService() {
    _sosService.startServerDiscovery();
  }

  void _connectToServer() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _sosService.connectToServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to SOS server successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _sendSOSAlert() async {
    if (!_sosService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to SOS server. Please connect first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _sosService.sendSOSAlert(
        alertType: _selectedAlertType,
        customMessage: _messageController.text.trim(),
      );

      setState(() {
        _alertSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS Alert sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Show confirmation dialog
        _showSOSConfirmationDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSOSConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text('SOS Alert Sent'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your emergency alert has been broadcast to all connected devices on the local network.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),
              Text(
                'Alert Type: ${_selectedAlertType.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_messageController.text.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  'Message: ${_messageController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 15),
              const Text(
                'Keep this screen open to receive updates and maintain connection.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _alertSent = false;
                  _messageController.clear();
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offline SOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[600]!,
              Colors.red[400]!,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Connection Status Card
                _buildConnectionStatusCard(),
                
                const SizedBox(height: 20),
                
                // Server Discovery Info
                _buildServerDiscoveryCard(),
                
                const SizedBox(height: 30),
                
                // SOS Alert Form
                Expanded(
                  child: _buildSOSForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return StreamBuilder<bool>(
      stream: _sosService.connectionStatusStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;
        
        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Server Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConnected ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (!isConnected) ...[
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connectToServer,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isConnecting ? 'Connecting...' : 'Connect to Server'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerDiscoveryCard() {
    return StreamBuilder<List<String>>(
      stream: _sosService.discoveredServersStream,
      builder: (context, snapshot) {
        final servers = snapshot.data ?? [];
        
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.search, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Server Discovery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (servers.isEmpty)
                  const Text(
                    'Scanning local network for SOS servers...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    'Found ${servers.length} server(s): ${servers.join(", ")}',
                    style: const TextStyle(color: Colors.green),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSOSForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Emergency SOS Alert',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 25),
            
            // Alert Type Selection
            const Text(
              'Alert Type:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            
            DropdownButtonFormField<String>(
              value: _selectedAlertType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'emergency', child: Text('🚨 Emergency')),
                DropdownMenuItem(value: 'medical', child: Text('🏥 Medical')),
                DropdownMenuItem(value: 'fire', child: Text('🔥 Fire')),
                DropdownMenuItem(value: 'police', child: Text('👮 Police')),
                DropdownMenuItem(value: 'accident', child: Text('🚗 Accident')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAlertType = value!;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Message Input
            const Text(
              'Additional Message (Optional):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            
            TextFormField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your emergency situation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(15),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // SOS Button
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _sendSOSAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, size: 30),
                    SizedBox(width: 15),
                    Text(
                      'SEND SOS ALERT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Info Text
            const Text(
              'This will broadcast your emergency alert to all devices connected to the local SOS server.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (_alertSent) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'SOS Alert sent successfully!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}