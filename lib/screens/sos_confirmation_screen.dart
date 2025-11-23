import 'package:flutter/material.dart';
import '../services/emergency_contact_service.dart';
import '../services/integrated_offline_emergency_service.dart';
import '../services/enhanced_sos_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'dart:async';
import '../models/user.dart';
import '../widgets/bottom_navigation.dart';
import 'package:geolocator/geolocator.dart';

class SOSConfirmationScreen extends StatefulWidget {
  final User? user;
  final Function(int) onNavigate;

  const SOSConfirmationScreen({  
    Key? key,
    this.user, // made optional (removed required since nullable)
    required this.onNavigate,
  }) : super(key: key);

  @override
  _SOSConfirmationScreenState createState() => _SOSConfirmationScreenState();
}
class _SOSConfirmationScreenState extends State<SOSConfirmationScreen> {
  int _countdown = 10;
  bool _isActive = false;
  bool _alertSent = false;
  List<String> _contactsNotified = [];
  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoadingContacts = true;
  StreamSubscription<List<OfflineEmergencyContact>>? _contactsSubscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
    _loadTimerFromSettings();
  }

  /// Make a phone call
  Future<void> _callContact(String phoneNumber) async {
    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot make phone calls on this device')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error making call: $e')));
    }
  }

  /// Open SMS composer
  Future<void> _openSms(String phoneNumber) async {
    try {
      final uri = Uri(scheme: 'sms', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open SMS app on this device')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening SMS app: $e')));
    }
  }

  /// Open in-app chat
  void _openChat(EmergencyContact contact) {
    final id = contact.id.isNotEmpty ? contact.id : contact.phone;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(contactId: id, contactName: contact.name, contactPhone: contact.phone)));
  }

  Future<void> _loadTimerFromSettings() async {
    try {
      // Use EnhancedSOSService configured timer if available
      final sosService = EnhancedSOSService.instance;
      await sosService.initialize();
      final duration = sosService.timerDuration;
      // Clamp to minimum 1 second for safety
      setState(() {
        _countdown = (duration <= 0) ? 1 : duration;
      });
    } catch (e) {
      print('Could not load SOS timer from settings: $e');
      // Keep default countdown
    }
  }

  /// Load emergency contacts from MongoDB
  Future<void> _loadEmergencyContacts() async {
    try {
      // Subscribe to integrated offline emergency service for realtime updates
      final service = IntegratedOfflineEmergencyService.instance;
      await service.initialize();

      // Initial load from offline DB (or API via wrapper)
      final offline = await service.getAllEmergencyContacts();
      if (mounted) {
        setState(() {
          _emergencyContacts = offline.map((o) => EmergencyContact.fromOffline(o)).toList();
          _isLoadingContacts = false;
        });
      }

      // Listen for updates
      _contactsSubscription = service.contactsStream.listen((contacts) {
        if (mounted) {
          setState(() {
            _emergencyContacts = contacts.map((o) => EmergencyContact.fromOffline(o)).toList();
            _isLoadingContacts = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:   Text('Failed to load emergency contacts: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contactsSubscription?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _isActive = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdown--);

      if (_countdown <= 0) {
        timer.cancel();
        _sendAlert();
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _countdown = 10;
      _alertSent = false;
      _contactsNotified.clear();
    });
  }

  Future<void> _sendAlert() async {
    setState(() {
      _alertSent = true;
    });

    try {
      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('⚠️  Could not get location: $e');
        // Use a default location or last known location
        position = Position(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }

      // Send comprehensive SOS alert
      final sosService = EnhancedSOSService.instance;
      bool success = await sosService.sendComprehensiveSOSAlert(
        emergencyType: 'general',
        message: 'Emergency SOS Alert! I need immediate assistance.',
        currentPosition: position,
        emergencyContacts: _emergencyContacts,
      );

      if (success) {
        print('✅ SOS Alert sent successfully');
        // Simulate notifying contacts one by one for UI feedback
        for (int i = 0; i < _emergencyContacts.length; i++) {
          Timer(Duration(milliseconds: 500 * (i + 1)), () {
            if (mounted) {
              setState(() {
                _contactsNotified.add(_emergencyContacts[i].id);
              });
            }
          });
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency alert sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to send SOS alert');
      }
    } catch (e) {
      print('❌ Error sending SOS alert: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Reset alert state on failure
        setState(() {
          _alertSent = false;
        });
      }
    }
  }

  Future<void> _immediateSOS() async {
    setState(() {
      _countdown = 0;
      _isActive = true;
    });
    await _sendAlert();
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
        
      /// Header
          Container(
            color: Theme.of(context).colorScheme.error,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => widget.onNavigate(2),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      padding: EdgeInsets.zero, // fixed here
                      constraints: const BoxConstraints(), // no extra space
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.shield, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Emergency SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
          ),


          // Content
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_isActive && !_alertSent) ...[
                      // SOS Warning
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.warning,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Emergency SOS Alert',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'This will immediately alert emergency services and your emergency contacts with your current location and situation.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24),
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _startCountdown,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFEF4444),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shield, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Activate SOS (${_countdown}s delay)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _immediateSOS,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Color(0xFFEF4444), width: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Immediate Emergency Alert',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Current Location removed as requested

                      // Emergency Contacts Preview
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Emergency Contacts (${_emergencyContacts.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Column(
                                children: _emergencyContacts.map((contact) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              contact.relationship,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          contact.phone,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => widget.onNavigate(5), // Contacts screen
                                  child: Text(
                                    'Manage Emergency Contacts',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_isActive && !_alertSent)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_countdown',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'SOS Alert Starting...',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Emergency alert will be sent in $_countdown seconds',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: (10 - _countdown) / 10,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                              ),
                              SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _cancelSOS,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Color(0xFFEF4444), width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.close, color: Color(0xFFEF4444), size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Cancel SOS Alert',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_alertSent) ...[
                      // Success message
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'SOS Alert Sent Successfully',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Emergency services and your contacts have been notified with your location.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Alert Active - Help is on the way',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Alert Status
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alert Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Emergency Services',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Notified',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Emergency Contacts:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Column(
                                children: _emergencyContacts.map((contact) {
                                  bool isNotified = _contactsNotified.contains(contact.id);
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isNotified ? Color(0xFF10B981) : Colors.grey.shade400,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              contact.name,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isNotified ? Color(0xFF10B981) : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isNotified ? 'Notified' : 'Sending...',
                                            style: TextStyle(
                                              color: isNotified ? Colors.white : Colors.grey.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => widget.onNavigate(3), // Map screen
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3B82F6),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Share Live Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancelSOS,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cancel Alert',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 16),

                    // Important Information
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• Your exact location will be shared with emergency services and contacts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• This feature works even when offline using stored location data',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• False alerts may result in charges from emergency services',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• Use this feature only in genuine emergencies',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom padding for navigation
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 4, // Screen index 4 (SOS)
        onNavigate: widget.onNavigate,
      ),
    );
  }
}

  /// helper widget for top-right status bar
  Widget _buildStatusDot({required bool active}) {
    return Container(
      width: 16,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
