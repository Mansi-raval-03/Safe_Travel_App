import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/integrated_offline_emergency_service.dart';

class EnhancedOfflineSOSScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const EnhancedOfflineSOSScreen({
    Key? key,
    this.onNavigate,
  }) : super(key: key);

  @override
  State<EnhancedOfflineSOSScreen> createState() => _EnhancedOfflineSOSScreenState();
}

class _EnhancedOfflineSOSScreenState extends State<EnhancedOfflineSOSScreen> {
  final IntegratedOfflineEmergencyService _emergencyService = IntegratedOfflineEmergencyService.instance;
  
  String _selectedEmergencyType = 'emergency';
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = false;
  bool _isOnline = false;
  bool _enableLiveLocation = true;
  int _liveLocationHours = 2;
  
  List<OfflineEmergencyContact> _contacts = [];
  bool _locationPermissionGranted = false;

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

  /// Initialize the emergency service
  Future<void> _initializeService() async {
    try {
      await _emergencyService.initialize();
      
      // Listen to contacts stream
      _emergencyService.contactsStream.listen((contacts) {
        if (mounted) {
          setState(() {
            _contacts = contacts;
          });
        }
      });
      
      // Listen to network status
      _emergencyService.networkStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
        }
      });
      
      // Listen to location updates
      _emergencyService.locationStream.listen((location) {
        // Location updates are handled by the service for live location sharing
        if (mounted) {
          // Update location permission status based on successful location updates
          setState(() {
            _locationPermissionGranted = true;
          });
        }
      });
      
      // Load initial data
      _loadData();
      _checkLocationPermission();
      
    } catch (e) {
      _showError('Failed to initialize emergency service: $e');
    }
  }

  /// Load initial data
  Future<void> _loadData() async {
    try {
      final contacts = await _emergencyService.getAllEmergencyContacts();
      setState(() {
        _contacts = contacts;
      });
    } catch (e) {
      _showError('Failed to load contacts: $e');
    }
  }

  /// Check location permission
  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      setState(() {
        _locationPermissionGranted = permission == LocationPermission.whileInUse || 
                                   permission == LocationPermission.always;
      });
    } catch (e) {
      setState(() {
        _locationPermissionGranted = false;
      });
    }
  }

  /// Send SOS alert
  Future<void> _sendSOSAlert() async {
    if (_contacts.isEmpty) {
      _showError('No emergency contacts found. Please add contacts first.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final sosId = await _emergencyService.sendSOSAlertOffline(
        emergencyType: _selectedEmergencyType,
        message: _messageController.text.trim().isEmpty 
            ? null 
            : _messageController.text.trim(),
        enableLiveLocationSharing: _enableLiveLocation && _locationPermissionGranted,
        liveLocationDuration: Duration(hours: _liveLocationHours),
      );

      if (mounted) {
        _showSuccessDialog(sosId);
      }
    } catch (e) {
      _showError('Failed to send SOS alert: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Show success dialog
  void _showSuccessDialog(int sosId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              'Your emergency alert has been sent to all emergency contacts.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              'Alert ID: $sosId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Type: ${_selectedEmergencyType.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_messageController.text.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Message: ${_messageController.text}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            Text(
              'Contacts notified: ${_contacts.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_enableLiveLocation && _locationPermissionGranted) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Live Location Sharing Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your location will be shared every 2 minutes for $_liveLocationHours hours',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Keep the app running for continuous updates',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_isOnline) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Messages will be sent when internet connection is restored',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _messageController.clear();
                _selectedEmergencyType = 'emergency';
              });
            },
            child: const Text('OK'),
          ),
          if (widget.onNavigate != null)
            ElevatedButton(
              onPressed: () {
              Navigator.of(context).pop();
              widget.onNavigate!(5); // Navigate to emergency contacts
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Contacts'),
          ),
        ],
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          // Network status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status cards
            _buildStatusCards(),
            
            const SizedBox(height: 24),
            
            // Emergency type selection
            _buildEmergencyTypeSelection(),
            
            const SizedBox(height: 20),
            
            // Message input
            _buildMessageInput(),
            
            const SizedBox(height: 20),
            
            // Live location settings
            _buildLiveLocationSettings(),
            
            const SizedBox(height: 30),
            
            // SOS button
            _buildSOSButton(),
            
            const SizedBox(height: 20),
            
            // Info text
            _buildInfoText(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            icon: Icons.contacts,
            title: 'Contacts',
            value: _contacts.length.toString(),
            color: Colors.blue.shade600,
            onTap: _contacts.isEmpty 
                ? () => widget.onNavigate?.call(5) // Navigate to add contacts
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            icon: _locationPermissionGranted ? Icons.location_on : Icons.location_off,
            title: 'Location',
            value: _locationPermissionGranted ? 'Ready' : 'Disabled',
            color: _locationPermissionGranted ? Colors.green.shade600 : Colors.orange.shade600,
            onTap: !_locationPermissionGranted ? _checkLocationPermission : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedEmergencyType,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.emergency),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: const [
            DropdownMenuItem(value: 'emergency', child: Text('🚨 General Emergency')),
            DropdownMenuItem(value: 'medical', child: Text('🏥 Medical Emergency')),
            DropdownMenuItem(value: 'fire', child: Text('🔥 Fire Emergency')),
            DropdownMenuItem(value: 'police', child: Text('👮 Police Emergency')),
            DropdownMenuItem(value: 'accident', child: Text('🚗 Traffic Accident')),
            DropdownMenuItem(value: 'crime', child: Text('🚔 Crime/Safety')),
            DropdownMenuItem(value: 'natural', child: Text('🌪️ Natural Disaster')),
            DropdownMenuItem(value: 'other', child: Text('❓ Other Emergency')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedEmergencyType = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Message (Optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Describe your situation, location details, or specific help needed...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.message),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveLocationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Location Sharing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Live Location Updates'),
                subtitle: Text(
                  _locationPermissionGranted 
                      ? 'Share your location every 2 minutes'
                      : 'Location permission required',
                ),
                value: _enableLiveLocation && _locationPermissionGranted,
                onChanged: _locationPermissionGranted 
                    ? (value) {
                        setState(() {
                          _enableLiveLocation = value;
                        });
                      }
                    : null,
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableLiveLocation && _locationPermissionGranted) ...[
                const Divider(),
                ListTile(
                  title: const Text('Duration'),
                  subtitle: Text('Share location for $_liveLocationHours hour${_liveLocationHours == 1 ? '' : 's'}'),
                  trailing: DropdownButton<int>(
                    value: _liveLocationHours,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 hour')),
                      DropdownMenuItem(value: 2, child: Text('2 hours')),
                      DropdownMenuItem(value: 4, child: Text('4 hours')),
                      DropdownMenuItem(value: 6, child: Text('6 hours')),
                      DropdownMenuItem(value: 8, child: Text('8 hours')),
                      DropdownMenuItem(value: 12, child: Text('12 hours')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _liveLocationHours = value;
                        });
                      }
                    },
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        if (!_locationPermissionGranted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Location permission is required for live location sharing',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: _checkLocationPermission,
                  child: const Text('Enable'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSOSButton() {
    return SizedBox(
      height: 70,
      child: ElevatedButton(
        onPressed: _isLoading || _contacts.isEmpty ? null : _sendSOSAlert,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          shadowColor: Colors.red.shade300,
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'SENDING SOS...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, size: 36),
                  SizedBox(width: 16),
                  Text(
                    'SEND SOS ALERT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoText() {
    if (_contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'No Emergency Contacts Found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add emergency contacts before sending SOS alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => widget.onNavigate?.call(5), // Navigate to contacts
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Contacts'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(height: 8),
              const Text(
                'How SOS Alerts Work',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Alerts are sent to all ${_contacts.length} emergency contacts\n'
                '• Messages include your location and emergency details\n'
                '• Works offline - messages sent when connection returns\n'
                '• Live location updates every 2 minutes when enabled',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (!_isOnline) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Currently offline - SOS alerts will be queued and sent when internet connection is restored',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}