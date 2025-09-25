import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/bottom_navigation.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
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
  final SocketIOService _socketService = SocketIOService();
  
  // Location tracking
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyUsers = [];
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _nearbyUsersSubscription;
  
  bool _isLocationServiceInitialized = false;
  bool _isSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize location and socket services
  Future<void> _initializeServices() async {
    try {
      // Initialize location service
      _isLocationServiceInitialized = await _locationService.initialize();
      if (_isLocationServiceInitialized) {
        _currentPosition = _locationService.currentPosition;
        
        // Listen to location updates
        _locationSubscription = _locationService.locationStream.listen((position) {
          setState(() {
            _currentPosition = position;
          });
        });
        
        _locationService.startLocationTracking();
      }

      // Initialize Socket.IO service
      _isSocketConnected = await _socketService.initialize(
        serverUrl: 'http://localhost:3000', // Replace with your server URL
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        userName: 'Safe Traveler',
      );

      if (_isSocketConnected) {
        // Listen to nearby users updates
        _nearbyUsersSubscription = _socketService.nearbyUsersStream.listen((users) {
          setState(() {
            _nearbyUsers = users;
          });
        });

        // Request nearby users every 30 seconds
        Timer.periodic(Duration(seconds: 30), (_) {
          if (_isSocketConnected) {
            _socketService.requestNearbyUsers(radiusInKm: 5.0);
          }
        });
      }

      setState(() {}); // Refresh UI
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  /// Handle SOS trigger with location sharing
  void _handleSOSWithLocation() {
    if (_isSocketConnected && _currentPosition != null) {
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
    
    // Call the original SOS callback
    widget.onTriggerSOS();
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

  /// Offer help to a user in need
  void _offerHelp(Map<String, dynamic> user) {
    if (_isSocketConnected) {
      // Send help offer through socket
      _socketService.updateUserStatus('offering_help', 
        message: 'Offering assistance to ${user['userName']}');
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Help offer sent to ${user['userName']}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  final List<Map<String, dynamic>> nearbyServices = [
    {
      'id': 'hospital',
      'name': 'City General Hospital',
      'type': 'Hospital',
      'icon': Icons.local_hospital,
      'distance': '2.1 km',
      'time': '8 min',
      'address': '456 Medical Center Blvd',
      'phone': '+1-555-0123',
      'status': 'Open 24/7',
      'color': Colors.red,
    },
    {
      'id': 'police',
      'name': 'Central Police Station',
      'type': 'Police',
      'icon': Icons.shield,
      'distance': '1.5 km',
      'time': '6 min',
      'address': '789 Justice Ave',
      'phone': '+1-555-0911',
      'status': 'Open 24/7',
      'color': Colors.blue,
    },
    {
      'id': 'fuel',
      'name': 'QuickFill Gas Station',
      'type': 'Fuel',
      'icon': Icons.local_gas_station,
      'distance': '0.8 km',
      'time': '3 min',
      'address': '321 Highway 101',
      'phone': '+1-555-0456',
      'status': 'Open until 11 PM',
      'color': Colors.green,
    },
  ];

  @override
  void dispose() {
    _destinationController.dispose();
    _locationSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _locationService.dispose();
    _socketService.dispose();
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
                          // Map background
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: NetworkImage('https://images.unsplash.com/photo-1499591934245-40b55745b905'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          
                          // Map overlay
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.black.withOpacity(0.1),
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

                          // Current user location pin (larger, pulsing)
                          if (_currentPosition != null)
                            Positioned(
                              top: 100,
                              left: 100,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Nearby users pins
                          ..._nearbyUsers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final user = entry.value;
                            
                            // Position users in different locations on the mock map
                            final positions = [
                              {'top': 48.0, 'left': 64.0},
                              {'top': 80.0, 'right': 80.0},
                              {'top': 130.0, 'left': 48.0},
                              {'top': 60.0, 'right': 50.0},
                              {'top': 120.0, 'right': 120.0},
                            ];
                            
                            final position = positions[index % positions.length];
                            
                            return Positioned(
                              top: position['top'],
                              left: position['left'],
                              right: position['right'],
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getUserStatusColor(user['status'] ?? 'safe'),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: user['status'] == 'in_danger' 
                                  ? Icon(
                                      Icons.warning,
                                      size: 8,
                                      color: Colors.white,
                                    )
                                  : null,
                              ),
                            );
                          }).toList(),

                          // Static location pins (keeping the original ones for services)
                          Positioned(
                            top: 48,
                            left: 64,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 80,
                            right: 80,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 48,
                            left: 48,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
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
                              children: nearbyServices.map((service) {
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
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            onPressed: () {},
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              side: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            child: Text(
                                              'Call',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {},
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF3B82F6),
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            ),
                                            child: Text(
                                              'Go',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
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
      bottomNavigationBar: BottomNavigation(
        currentIndex: 1,
        onNavigate: widget.onNavigate,
      ),
    );
  }
}