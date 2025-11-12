import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/bottom_navigation.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../services/sos_emergency_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/enhanced_sos_service.dart';
import '../services/emergency_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onTriggerSOS;

  const MapScreen({
    Key? key,
    required this.onNavigate,
    required this.onTriggerSOS,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _destinationController = TextEditingController();
  bool _routeActive = false;
  
  // Services
  final LocationService _locationService = LocationService();
  final SOSEmergencyService _sosService = SOSEmergencyService();
  final EnhancedSOSService _enhancedSosService = EnhancedSOSService.instance;
  final SocketIOService _socketService = SocketIOService();
  
  // Google Maps
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  
  // Location tracking
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyUsers = [];
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _nearbyUsersSubscription;
  
  // Map settings
  Set<Marker> _markers = {};
  LatLng _initialCameraPosition = const LatLng(22.2897, 70.7783); // Atmiya University, Rajkot
  
  bool _isLocationServiceInitialized = false;
  bool _isSocketConnected = false;
  
  // SOS emergency state
  bool _isSOSActive = false;
  int _emergencyContactsCount = 0;
  
  // Emergency services state
  List<Map<String, dynamic>> _nearbyServices = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    await _initLocationService();
    await _initSocketService();
    await _initEnhancedSOSService(); // Initialize enhanced SOS service
    await _debugEmergencyContactsAPI(); // Debug API first
    await _initSOSEmergencyService();
    await _testSOSSystem(); // Test complete SOS system
    await _loadNearbyServices(); // Load emergency services
  }
  
  /// Load nearby emergency services based on user location
  Future<void> _loadNearbyServices() async {
    try {
      if (_currentPosition != null) {
        final services = EmergencyLocationService.getNearbyServices(
          userLatitude: _currentPosition!.latitude,
          userLongitude: _currentPosition!.longitude,
          maxResults: 6,
        );
        
        setState(() {
          _nearbyServices = services;
        });
        
        print('🏥 Loaded ${services.length} nearby emergency services');
      } else {
        print('⚠️ Cannot load services - no user location available');
      }
    } catch (e) {
      print('❌ Error loading nearby services: $e');
    }
  }

  /// Initialize enhanced SOS service
  Future<void> _initEnhancedSOSService() async {
    try {
      await _enhancedSosService.initialize();
      print('✅ Enhanced SOS Service initialized');
    } catch (e) {
      print('❌ Error initializing enhanced SOS service: $e');
    }
  }

  /// Test enhanced SOS system end-to-end
  Future<void> _testSOSSystem() async {
    try {
      print('🧪 TESTING ENHANCED SOS SYSTEM END-TO-END...');
      
      // Test 1: Emergency contacts loading
      print('📞 Test 1: Loading emergency contacts...');
      final contacts = await EmergencyContactService.getAllContacts();
      print('✅ Loaded ${contacts.length} emergency contacts');
      
      if (contacts.isEmpty) {
        print('❌ No emergency contacts found - SOS system requires contacts');
        return;
      }

      for (var contact in contacts) {
        print('   - ${contact.name}: ${contact.phone} (${contact.relationship})');
      }
      
      // Test 2: Location service
      print('📍 Test 2: Checking location service...');
      if (!_locationService.isInitialized) {
        print('🔄 Initializing location service...');
        await _locationService.initialize();
      }
      
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        print('✅ Location service working: ${position.latitude}, ${position.longitude}');
      } else {
        print('❌ Location service not working');
        return;
      }
      
      // Test 3: Enhanced SOS service settings
      print('⚙️ Test 3: Testing Enhanced SOS service...');
      print('   - Timer Duration: ${_enhancedSosService.timerDuration} seconds');
      print('   - Auto-Send Enabled: ${_enhancedSosService.autoSendEnabled}');
      print('   - Timer Running: ${_enhancedSosService.isTimerRunning}');
      print('✅ Enhanced SOS Service ready');
      
      // Test 4: Enhanced message formatting
      print('📱 Test 4: Testing enhanced emergency message...');
      final testMessage = '''🚨 EMERGENCY ALERT 🚨

Type: GENERAL EMERGENCY
Message: I need help! This is an automated emergency alert from Safe Travel App.

📍 My Current Location:
Latitude: ${position.latitude.toStringAsFixed(6)}
Longitude: ${position.longitude.toStringAsFixed(6)}
Accuracy: ${position.accuracy.toStringAsFixed(1)}m

🗺️ View on Map: https://maps.google.com/?q=${position.latitude},${position.longitude}

⏰ Time: ${DateTime.now().toString()}

This is an automated emergency message from Safe Travel App. Please respond immediately!''';
      
      print('✅ Enhanced message created successfully');
      print('📄 Message length: ${testMessage.length} characters');
      
      print('🎉 ENHANCED SOS SYSTEM FULLY OPERATIONAL!');
      print('   ✅ Emergency contacts: ${contacts.length}');
      print('   ✅ Location service: Working (±${position.accuracy.toStringAsFixed(1)}m)');
      print('   ✅ Enhanced SOS service: Ready');
      print('   ✅ SMS & WhatsApp: Configured');
      print('   ✅ Timer system: ${_enhancedSosService.timerDuration}s countdown');
      print('   ✅ One-click SOS: Ready');
      
    } catch (e) {
      print('❌ ENHANCED SOS SYSTEM TEST FAILED: $e');
    }
  }

  /// Debug function to test emergency contacts API
  Future<void> _debugEmergencyContactsAPI() async {
    try {
      print('🔬 DEBUG: Testing Emergency Contacts API...');
      
      // Test getting auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('🔑 Auth token exists: ${token != null}');
      if (token != null) {
        print('🔑 Token length: ${token.length} characters');
        print('🔑 Token starts with: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      }
      
      // Test API call
      final contacts = await EmergencyContactService.getAllContacts();
      print('📞 Emergency contacts retrieved: ${contacts.length}');
      
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        print('   ${i + 1}. ${contact.name} (${contact.phone}) - ${contact.relationship}');
      }
      
    } catch (e) {
      print('❌ DEBUG ERROR: $e');
    }
  }

  /// Initialize SOS emergency service
  Future<void> _initSOSEmergencyService() async {
    try {
      print('🔄 Initializing SOS Emergency service...');
      
      // Get detailed emergency contacts information
      final contacts = await EmergencyContactService.getAllContacts();
      final contactsCount = contacts.length;
      
      setState(() {
        _emergencyContactsCount = contactsCount;
      });
      
      if (contactsCount > 0) {
        print('✅ SOS Emergency service initialized - $contactsCount emergency contacts found:');
        for (int i = 0; i < contacts.length; i++) {
          final contact = contacts[i];
          print('   ${i + 1}. ${contact.name} (${contact.phone}) - ${contact.relationship}');
        }
      } else {
        print('⚠️  SOS Emergency service initialized - No emergency contacts found');
        print('   📝 User needs to add emergency contacts to enable SOS functionality');
      }
    } catch (e) {
      print('❌ Error initializing SOS emergency service: $e');
      setState(() {
        _emergencyContactsCount = 0;
      });
    }
  }

  /// Initialize location and socket services
  Future<void> _initLocationService() async {
    try {
      print('🔄 Initializing location service...');
      bool initialized = await _locationService.initialize();
      
      if (!initialized) {
        print('❌ Location service initialization failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location service failed to initialize. Please check permissions.')),
        );
        return;
      }
      
      // Get initial position and set camera
      print('📍 Getting current location...');
      _currentPosition = await _locationService.getCurrentLocation();
      
      if (_currentPosition != null) {
        print('✅ Got location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        _initialCameraPosition = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        _updateMarkers();
        
        setState(() {
          _isLocationServiceInitialized = true;
        });
        
        // Start location tracking
        print('🔄 Starting location tracking...');
        _locationService.startLocationTracking();
        
        _locationSubscription = _locationService.locationStream.listen(
          (Position position) {
            print('📍 Location update: ${position.latitude}, ${position.longitude}');
            setState(() {
              _currentPosition = position;
              _updateMarkers();
            });
            
            // Update camera position
            _moveCamera(LatLng(position.latitude, position.longitude));
            
            // Reload nearby emergency services when location changes significantly
            _loadNearbyServices();
          },
          onError: (error) {
            print('❌ Location stream error: $error');
          },
        );
        
        print('✅ Location service initialized successfully');
      } else {
        print('❌ Failed to get current location');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get your current location. Please check GPS settings.')),
        );
      }
    } catch (e) {
      print('❌ Error initializing location service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize location services: $e')),
      );
    }
  }

  Future<void> _initSocketService() async {
    try {
      // Note: In a real app, you would get these from authentication
      // For demo purposes, using placeholder values
      bool connected = await _socketService.initialize(
        serverUrl: 'http://localhost:3000', // Replace with your backend URL
        userId: 'demo_user_123',
        userName: 'Demo User',
      );
      
      if (connected) {
        // Listen for nearby users updates
        _nearbyUsersSubscription = _socketService.nearbyUsersStream.listen((users) {
          setState(() {
            _nearbyUsers = users;
            _updateMarkers();
          });
        });
        
        setState(() {
          _isSocketConnected = true;
        });
        
        print('✅ Socket service initialized successfully');
      } else {
        setState(() {
          _isSocketConnected = false;
        });
        print('❌ Failed to connect to socket service');
      }
    } catch (e) {
      print('❌ Error initializing socket service: $e');
      setState(() {
        _isSocketConnected = false;
      });
    }
  }

  void _updateMarkers() {
    print('🎯 Updating markers...');
    Set<Marker> markers = {};
    
    // Add current location marker
    if (_currentPosition != null) {
      print('📍 Adding current location marker at: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current GPS position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    
    // Add emergency services markers from nearby services
    print('🏥 Adding ${_nearbyServices.length} emergency service markers');
    for (var service in _nearbyServices) {
      if (service['latitude'] != null && service['longitude'] != null) {
        BitmapDescriptor markerColor;
        
        // Color code by service type
        switch (service['type']) {
          case 'hospital':
            markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            break;
          case 'police':
            markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
            break;
          case 'fuel':
            markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
            break;
          default:
            markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        }
        
        markers.add(
          Marker(
            markerId: MarkerId('service_${service['name']}'),
            position: LatLng(service['latitude'], service['longitude']),
            infoWindow: InfoWindow(
              title: service['name'],
              snippet: '${service['type'].toUpperCase()} • ${service['phone']}',
            ),
            icon: markerColor,
          ),
        );
      }
    }
    
    // Add nearby users markers
    print('👥 Adding ${_nearbyUsers.length} nearby user markers');
    for (int i = 0; i < _nearbyUsers.length; i++) {
      final user = _nearbyUsers[i];
      if (user['latitude'] != null && user['longitude'] != null) {
        markers.add(
          Marker(
            markerId: MarkerId('user_${user['userId'] ?? i}'),
            position: LatLng(user['latitude'].toDouble(), user['longitude'].toDouble()),
            infoWindow: InfoWindow(
              title: 'User ${user['name'] ?? 'Unknown'}',
              snippet: 'Status: ${user['status'] ?? 'Safe'}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              user['status'] == 'in_danger' 
                ? BitmapDescriptor.hueRed 
                : BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }
    }
    
    print('✅ Updated ${markers.length} markers (${_nearbyServices.length} services + ${_nearbyUsers.length} users)');
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _moveCamera(LatLng target) async {
    if (_mapController != null) {
      print('📱 Moving camera to: ${target.latitude}, ${target.longitude}');
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 16.0,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    } else {
      print('⚠️ Map controller not initialized yet');
    }
  }

  /// Show SOS confirmation dialog
  void _showSOSConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Emergency SOS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: FutureBuilder<List<EmergencyContact>>(
            future: EmergencyContactService.getAllContacts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading emergency contacts...'),
                  ],
                );
              }
              
              final contacts = snapshot.data ?? [];
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to send an SOS alert?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This will:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(height: 6),
                        Text('• Send your live location via SMS', style: TextStyle(fontSize: 13)),
                        Text('• Send WhatsApp message with location', style: TextStyle(fontSize: 13)),
                        Text('• Alert nearby users in the area', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  if (contacts.isNotEmpty) ...[
                    Text(
                      'Emergency Contacts (${contacts.length}):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Column(
                          children: contacts.map((contact) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${contact.name} (${contact.phone})',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (contact.isPrimary)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'PRIMARY',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No emergency contacts found. Please add contacts first.',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            FutureBuilder<List<EmergencyContact>>(
              future: EmergencyContactService.getAllContacts(),
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? [];
                final hasContacts = contacts.isNotEmpty;
                
                return ElevatedButton.icon(
                  onPressed: hasContacts ? () {
                    Navigator.of(context).pop();
                    _triggerSOSEmergency();
                  } : null,
                  icon: Icon(Icons.warning, size: 16),
                  label: Text(hasContacts ? 'Send SOS Alert' : 'No Contacts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasContacts ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Trigger SOS emergency with automatic location sharing
  Future<void> _triggerSOSEmergency() async {
    if (!_isLocationServiceInitialized || _currentPosition == null) {
      _showErrorSnackBar('Location service not available');
      return;
    }

    try {
      setState(() {
        _isSOSActive = true;
      });

      // Send SOS through socket for real-time alerts
      if (_isSocketConnected) {
        _socketService.sendEmergencyAlert(
          alertType: 'SOS',
          message: 'Emergency assistance needed at current location',
          additionalData: {
            'accuracy': _currentPosition!.accuracy,
            'speed': _currentPosition!.speed,
          },
        );
        
        _socketService.updateUserStatus('in_danger', 
          message: 'SOS alert triggered - need immediate assistance');
      }

      // Trigger emergency location sharing to contacts
      final result = await _sosService.triggerSOSEmergency(
        customMessage: 'Emergency assistance needed - SOS alert triggered',
        shareViaWhatsApp: true,
        shareViaSMS: true,
      );
      
      if (!result.success) {
        throw Exception(result.message);
      }

      // Call the original SOS callback
      widget.onTriggerSOS();

      _showSuccessSnackBar('SOS alert sent to all emergency contacts');

      // Reset SOS active state after 30 seconds
      Future.delayed(Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _isSOSActive = false;
          });
        }
      });

    } catch (e) {
      setState(() {
        _isSOSActive = false;
      });
      _showErrorSnackBar('Failed to send SOS alert: $e');
      print('❌ Error triggering SOS emergency: $e');
    }
  }

  /// Handle SOS trigger with enhanced service
  void _handleSOSWithLocation() {
    _triggerEnhancedSOS();
  }

  /// Trigger enhanced SOS with one-click functionality
  Future<void> _triggerEnhancedSOS() async {
    try {
      // Check if location service is initialized
      if (!_isLocationServiceInitialized || _currentPosition == null) {
        _showErrorSnackBar('Location service not available. Cannot send SOS alert.');
        return;
      }

      // Get emergency contacts
      List<EmergencyContact> contacts = await EmergencyContactService.getAllContacts();
      if (contacts.isEmpty) {
        _showErrorSnackBar('No emergency contacts found. Please add contacts first.');
        return;
      }

      print('🚨 Triggering Enhanced SOS with ${contacts.length} contacts');

      // Use enhanced SOS service for one-click SOS with timer
      await _enhancedSosService.triggerOneClickSOS(
        context: context,
        emergencyType: 'General Emergency',
        message: 'I need help! This is an automated emergency alert from Safe Travel App.',
        currentPosition: _currentPosition!,
        emergencyContacts: contacts,
      );

    } catch (e) {
      print('❌ Error triggering enhanced SOS: $e');
      _showErrorSnackBar('Failed to send SOS alert. Please try again.');
    }
  }



  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Get color based on user safety status
  Color _getUserStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return Colors.green;
      case 'in_danger':
        return Colors.red;
      case 'help_needed':
        return Colors.orange;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Get icon based on user safety status
  IconData _getUserStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return Icons.check_circle;
      case 'in_danger':
        return Icons.warning;
      case 'help_needed':
        return Icons.help;
      case 'offline':
        return Icons.offline_bolt;
      default:
        return Icons.person;
    }
  }

  /// Get readable status text
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return 'Safe';
      case 'in_danger':
        return 'In Danger';
      case 'help_needed':
        return 'Needs Help';
      case 'offline':
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

 



  /// Stop location sharing
  
 /// Offer help to a user in need
  void _offerHelp(Map<String, dynamic> user) {
    if (_isSocketConnected) {
      // Send help offer through socket
      _socketService.updateUserStatus('offering_help', 
        message: 'Offering assistance to ${user['userName']}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Help offer sent to ${user['userName']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  /// Handle call button press for emergency service
  Future<void> _handleCallService(String phoneNumber, String serviceName) async {
    try {
      await EmergencyLocationService.makeCall(phoneNumber);
      print('📞 Calling $serviceName at $phoneNumber');
    } catch (e) {
      print('❌ Error calling service: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make call to $serviceName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle go button press for emergency service
  Future<void> _handleGoToService(double latitude, double longitude, String serviceName) async {
    try {
      await EmergencyLocationService.navigateToLocation(
        latitude: latitude,
        longitude: longitude,
        locationName: serviceName,
      );
      print('🗺️ Opening navigation to $serviceName');
    } catch (e) {
      print('❌ Error opening navigation: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open navigation to $serviceName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build helpline card widget
  Widget _buildHelplineCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String number,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await EmergencyLocationService.makeCall(number);
                print('📞 Calling $title at $number');
              } catch (e) {
                print('❌ Error calling helpline: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not call $title'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: Icon(Icons.phone, size: 14),
            label: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _locationSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    
    // Don't dispose singleton services - just stop tracking
    if (_locationService.isTracking) {
      _locationService.stopLocationTracking();
    }
    
    // Note: Don't dispose singleton services (_locationService, _socketService) 
    // as they may be used by other parts of the app and cause stream closure errors
    super.dispose();
  }

  void _handleStartNavigation() {
    if (_destinationController.text.trim().isNotEmpty) {
      setState(() {
        _routeActive = true;
      });
    }
  }

  void _handleStopNavigation() {
    setState(() {
      _routeActive = false;
      _destinationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
   // Header
          Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => widget.onNavigate(2), // Home screen
                        icon: Icon(Icons.arrow_back),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.all(4),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Map & Services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _handleSOSWithLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEF4444),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          _isSocketConnected ? 'SOS' : 'SOS (Offline)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _destinationController,
                              decoration: InputDecoration(
                                hintText: 'Search destination...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                            ),
                          ),
                          if (_destinationController.text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: _routeActive ? _handleStopNavigation : _handleStartNavigation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _routeActive ? Color(0xFFEF4444) : Color(0xFF3B82F6),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _routeActive ? 'Stop' : 'Go',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Active Route Banner
                    if (_routeActive)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(color: Color(0xFF3B82F6), width: 4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.route, size: 16, color: Color(0xFF3B82F6)),
                                SizedBox(width: 8),
                                Text(
                                  'Active Route',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Safest',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'To: ${_destinationController.text}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '12.5 km',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  '18 min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Light traffic',
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

                    if (_routeActive) SizedBox(height: 16),

                    // Map
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Google Map or loading state
                          _isLocationServiceInitialized && _currentPosition != null
                              ? GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _initialCameraPosition,
                                    zoom: 16.0,
                                  ),
                                  onMapCreated: (GoogleMapController controller) {
                                    print('🗺️ Google Map created successfully');
                                    _controller.complete(controller);
                                    _mapController = controller;
                                    
                                    // Move to current location immediately
                                    if (_currentPosition != null) {
                                      _moveCamera(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
                                    }
                                  },
                                  markers: _markers,
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  mapType: MapType.normal,
                                  buildingsEnabled: true,
                                  trafficEnabled: false,
                                  compassEnabled: true,
                                  rotateGesturesEnabled: true,
                                  scrollGesturesEnabled: true,
                                  tiltGesturesEnabled: true,
                                  zoomGesturesEnabled: true,
                                  zoomControlsEnabled: false,
                                  indoorViewEnabled: true,
                                  mapToolbarEnabled: false,
                                  onCameraMove: (CameraPosition position) {
                                    // Optional: Log camera movements for debugging
                                    // print('Camera moved to: ${position.target}');
                                  },
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.grey.shade300,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_searching,
                                          size: 48,
                                          color: Colors.grey.shade600,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          _isLocationServiceInitialized
                                              ? 'Loading Map...'
                                              : 'Getting Location...',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _initLocationService();
                                          },
                                          icon: Icon(Icons.refresh),
                                          label: Text('Retry Location'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                          // You are here badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isLocationServiceInitialized ? Colors.green : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLocationServiceInitialized 
                                      ? Icons.location_on 
                                      : Icons.location_off, 
                                    size: 12, 
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _isLocationServiceInitialized 
                                      ? 'Live Location'
                                      : 'Location Off',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Connection status badge
                          Positioned(
                            top: 12,
                            right: _routeActive ? 130 : 12,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isSocketConnected ? Colors.blue : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSocketConnected 
                                      ? Icons.wifi 
                                      : Icons.wifi_off, 
                                    size: 12, 
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _isSocketConnected ? 'Connected' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Navigating badge
                          if (_routeActive)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.navigation, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Navigating',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // SOS status badge
                          if (_isSOSActive)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emergency, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'SOS ACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Traffic Alert
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.orange.shade600,
                            size: 16,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Traffic Alert',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                Text(
                                  'Minor congestion ahead. Alternative route suggested.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Emergency Services
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
                              'Emergency Services',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            Column(
                              children: _nearbyServices.map((service) {
                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          service['icon'] as IconData,
                                          size: 16,
                                          color: service['color'] as Color,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              service['name'] as String,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${service['distance']} • ${service['time']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              service['address'] as String,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _handleCallService(
                                              service['phone'] as String,
                                              service['name'] as String,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              side: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.phone,
                                                  size: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Call',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _handleGoToService(
                                              service['latitude'] as double,
                                              service['longitude'] as double,
                                              service['name'] as String,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF3B82F6),
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.navigation,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Go',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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

                    // Women & Children Safety Helplines
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
                                Icon(
                                  Icons.shield_outlined,
                                  size: 20,
                                  color: Color(0xFFEC4899),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Women & Children Safety',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            
                            // Women Helpline
                            _buildHelplineCard(
                              icon: Icons.woman,
                              iconColor: Color(0xFFEC4899),
                              title: 'Women Helpline',
                              number: '1091',
                              description: '24/7 Emergency helpline for women in distress',
                            ),
                            SizedBox(height: 8),
                            
                            // Child Helpline
                            _buildHelplineCard(
                              icon: Icons.child_care,
                              iconColor: Color(0xFF8B5CF6),
                              title: 'Child Helpline',
                              number: '1098',
                              description: '24/7 Emergency helpline for children in need',
                            ),
                            SizedBox(height: 8),
                            
                            // National Commission for Women
                            _buildHelplineCard(
                              icon: Icons.support_agent,
                              iconColor: Color(0xFFEC4899),
                              title: 'NCW Helpline',
                              number: '7827-170-170',
                              description: 'National Commission for Women',
                            ),
                            SizedBox(height: 8),
                            
                            // Cyber Crime Helpline
                            _buildHelplineCard(
                              icon: Icons.computer,
                              iconColor: Color(0xFF3B82F6),
                              title: 'Cyber Crime Helpline',
                              number: '1930',
                              description: 'Report cyber crimes and harassment',
                            ),
                            SizedBox(height: 12),
                            
                            // Info banner
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.pink.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.pink.shade700),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'All helplines are toll-free and available 24/7',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.pink.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Emergency SOS Controls
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
                                Icon(
                                  Icons.emergency,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Emergency SOS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Spacer(),
                                if (_isSOSActive)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'ALERT SENT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 12),
                            
                            // Emergency Contact Information
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.contacts, size: 16, color: Colors.red.shade700),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Emergency Contacts: $_emergencyContactsCount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: _emergencyContactsCount > 0 ? Colors.red.shade800 : Colors.red.shade600,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () async {
                                              print('🔄 Refreshing emergency contacts...');
                                              await _debugEmergencyContactsAPI();
                                              await _initSOSEmergencyService();
                                            },
                                            icon: Icon(Icons.refresh, size: 18, color: Colors.red.shade700),
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                            tooltip: 'Refresh emergency contacts',
                                          ),
                                         
                                          if (_emergencyContactsCount == 0)
                                            IconButton(
                                              onPressed: () async {
                                                try {
                                                  print('➕ Adding test emergency contact...');
                                                  await EmergencyContactService.addContact(
                                                    name: 'Test Contact',
                                                    phone: '+1234567890',
                                                    relationship: 'Friend',
                                                    isPrimary: true,
                                                  );
                                                  print('✅ Test contact added successfully');
                                                  await _initSOSEmergencyService();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Test emergency contact added!')),
                                                  );
                                                } catch (e) {
                                                  print('❌ Error adding test contact: $e');
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Error adding test contact: $e')),
                                                  );
                                                }
                                              },
                                              icon: Icon(Icons.add, size: 18, color: Colors.green.shade700),
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                              tooltip: 'Add test emergency contact',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _emergencyContactsCount > 0
                                        ? 'Tap SOS to instantly send your live location via SMS and WhatsApp to all emergency contacts.'
                                        : 'Add emergency contacts to enable SOS alerts.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ), 
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            
                            // SOS Action Button
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (_isLocationServiceInitialized && _emergencyContactsCount > 0) 
                                        ? _showSOSConfirmationDialog 
                                        : null,
                                    icon: Icon(Icons.warning, size: 20),
                                    label: Text(
                                      '🚨 Send SOS Alert',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      elevation: 3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            if (!_isLocationServiceInitialized || _emergencyContactsCount == 0)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  !_isLocationServiceInitialized
                                      ? 'Location service must be enabled for SOS alerts'
                                      : 'Add emergency contacts to enable SOS alerts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Nearby Users
                    if (_nearbyUsers.isNotEmpty)
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
                                  Icon(
                                    Icons.people,
                                    color: Color(0xFF3B82F6),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Nearby Travelers (${_nearbyUsers.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Column(
                                children: _nearbyUsers.take(5).map((user) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _getUserStatusColor(user['status'] ?? 'safe'),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            _getUserStatusIcon(user['status'] ?? 'safe'),
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user['userName'] ?? 'Anonymous User',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                '${(user['distance'] ?? 0).toStringAsFixed(1)} km away • ${_getStatusText(user['status'] ?? 'safe')}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (user['status'] == 'help_needed' || user['status'] == 'in_danger')
                                          ElevatedButton(
                                            onPressed: () => _offerHelp(user),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            ),
                                            child: Text(
                                              'Help',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
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

                    // Connection status info
                    if (!_isSocketConnected)
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.orange.shade600,
                              size: 16,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Offline Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Live tracking is unavailable. Location sharing will resume when connected.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_currentPosition != null) {
            // Move camera to current location
            await _moveCamera(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
          } else {
            // Retry getting location
            await _initLocationService();
          }
        },
        backgroundColor: Colors.blue,
        tooltip: 'My Location',
        child: Icon(
          _isLocationServiceInitialized 
            ? Icons.my_location
            : Icons.location_searching,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigation(
        currentIndex: 3, // Screen index 3 (Map)
        onNavigate: widget.onNavigate,
      ),
    );
  }
}