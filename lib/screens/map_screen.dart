import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';

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
                    onPressed: widget.onTriggerSOS,
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
                          'SOS',
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.black),
                                  SizedBox(width: 4),
                                  Text(
                                    'You are here',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
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

                          // Location pins
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