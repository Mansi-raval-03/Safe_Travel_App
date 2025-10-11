import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class EmergencyService {
  final String id;
  final String name;
  final String type;
  final IconData icon;
  final String address;
  final String phone;
  final String status;
  final Color color;
  final double latitude;
  final double longitude;
  final bool isOpen24Hours;

  const EmergencyService({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.address,
    required this.phone,
    required this.status,
    required this.color,
    required this.latitude,
    required this.longitude,
    this.isOpen24Hours = false,
  });
}

class EmergencyLocationService {
  // Atmiya University, Rajkot location (22.2897° N, 70.7783° E)
  static const double atmiyaLatitude = 22.2897;
  static const double atmiyaLongitude = 70.7783;
  
  static final List<EmergencyService> _emergencyServices = [
    // Hospitals near Atmiya University, Rajkot
    EmergencyService(
      id: 'hospital_1',
      name: 'Civil Hospital Rajkot',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: 'Lal Bungalow Road, Rajkot',
      phone: '+91-281-2441992',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 22.3039,
      longitude: 70.8022,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'hospital_2',
      name: 'Marwadi Hospital',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: 'Mavdi Circle, Rajkot',
      phone: '+91-281-2440199',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 22.2850,
      longitude: 70.7650,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'hospital_3',
      name: 'Sterling Hospital',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: 'Near Raiya Circle, Rajkot',
      phone: '+91-281-2440444',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 22.2750,
      longitude: 70.7850,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'hospital_4',
      name: 'HCG Hospital Rajkot',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: 'Kalawad Road, Rajkot',
      phone: '+91-281-6619999',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 22.2950,
      longitude: 70.7950,
      isOpen24Hours: true,
    ),

    // Police Stations near Atmiya University, Rajkot
    EmergencyService(
      id: 'police_1',
      name: 'University Road Police Station',
      type: 'Police',
      icon: Icons.shield,
      address: 'University Road, Rajkot',
      phone: '100',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 22.2900,
      longitude: 70.7800,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'police_2',
      name: 'Aji Dam Police Station',
      type: 'Police',
      icon: Icons.shield,
      address: 'Aji Dam Road, Rajkot',
      phone: '100',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 22.2800,
      longitude: 70.7700,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'police_3',
      name: 'Gondal Road Police Station',
      type: 'Police',
      icon: Icons.shield,
      address: 'Gondal Road, Rajkot',
      phone: '100',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 22.3000,
      longitude: 70.7700,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'police_4',
      name: 'Rajkot City Police Control Room',
      type: 'Police',
      icon: Icons.shield,
      address: 'Police Headquarters, Rajkot',
      phone: '+91-281-2450101',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 22.3050,
      longitude: 70.8000,
      isOpen24Hours: true,
    ),

    // Fuel Pumps near Atmiya University, Rajkot
    EmergencyService(
      id: 'fuel_1',
      name: 'Indian Oil Petrol Pump',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: 'University Road, Near Atmiya University',
      phone: '+91-281-2471234',
      status: 'Open 6 AM - 11 PM',
      color: Colors.green,
      latitude: 22.2920,
      longitude: 70.7760,
      isOpen24Hours: false,
    ),
    EmergencyService(
      id: 'fuel_2',
      name: 'HP Petrol Pump',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: 'Kalawad Road, Rajkot',
      phone: '+91-281-2475678',
      status: 'Open 24/7',
      color: Colors.green,
      latitude: 22.2870,
      longitude: 70.7820,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'fuel_3',
      name: 'Bharat Petroleum',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: 'Gondal Road, Rajkot',
      phone: '+91-281-2478901',
      status: 'Open 6 AM - 10 PM',
      color: Colors.green,
      latitude: 22.2950,
      longitude: 70.7700,
      isOpen24Hours: false,
    ),
    EmergencyService(
      id: 'fuel_4',
      name: 'Reliance Petrol Pump',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: 'Aji Dam Road, Rajkot',
      phone: '+91-281-2472345',
      status: 'Open 24/7',
      color: Colors.green,
      latitude: 22.2820,
      longitude: 70.7750,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'fuel_5',
      name: 'Shell Petrol Pump',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: '150 Feet Ring Road, Rajkot',
      phone: '+91-281-2476789',
      status: 'Open 5 AM - 12 AM',
      color: Colors.green,
      latitude: 22.2980,
      longitude: 70.7880,
      isOpen24Hours: false,
    ),
  ];

  /// Get nearby emergency services based on user location
  static List<Map<String, dynamic>> getNearbyServices({
    required double userLatitude,
    required double userLongitude,
    int maxResults = 6,
  }) {
    List<Map<String, dynamic>> servicesWithDistance = [];

    for (var service in _emergencyServices) {
      double distance = _calculateDistance(
        userLatitude,
        userLongitude,
        service.latitude,
        service.longitude,
      );

      int estimatedTime = _calculateEstimatedTime(distance);

      servicesWithDistance.add({
        'id': service.id,
        'name': service.name,
        'type': service.type,
        'icon': service.icon,
        'distance': '${distance.toStringAsFixed(1)} km',
        'time': '${estimatedTime} min',
        'address': service.address,
        'phone': service.phone,
        'status': service.status,
        'color': service.color,
        'latitude': service.latitude,
        'longitude': service.longitude,
        'isOpen24Hours': service.isOpen24Hours,
        'distanceValue': distance,
      });
    }

    // Sort by distance and return closest ones
    servicesWithDistance.sort((a, b) => 
        (a['distanceValue'] as double).compareTo(b['distanceValue'] as double));
    
    return servicesWithDistance.take(maxResults).toList();
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calculate estimated travel time based on distance
  static int _calculateEstimatedTime(double distanceKm) {
    // Assume average city speed of 30 km/h
    double timeHours = distanceKm / 30.0;
    return (timeHours * 60).round(); // Convert to minutes
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Make a phone call to the emergency service
  static Future<void> makeCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw Exception('Could not launch phone dialer');
      }
    } catch (e) {
      print('Error making phone call: $e');
      // You might want to show a snackbar or dialog here
    }
  }

  /// Open navigation to the emergency service location
  static Future<void> navigateToLocation({
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    // Try Google Maps first
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$locationName'
    );
    
    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to generic maps URL
        final Uri fallbackUri = Uri.parse(
          'https://maps.google.com/?q=$latitude,$longitude'
        );
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening navigation: $e');
      // You might want to show a snackbar or dialog here
    }
  }

  /// Get specific service by ID
  static EmergencyService? getServiceById(String id) {
    try {
      return _emergencyServices.firstWhere((service) => service.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get services by type (Hospital, Police, Fuel)
  static List<EmergencyService> getServicesByType(String type) {
    return _emergencyServices.where((service) => service.type == type).toList();
  }

  /// Check if service is currently open (simplified logic)
  static bool isServiceOpen(EmergencyService service) {
    if (service.isOpen24Hours) return true;
    
    final now = DateTime.now();
    final hour = now.hour;
    
    // Simple logic for gas stations (6 AM - 11 PM or 5 AM - 12 AM)
    if (service.type == 'Fuel') {
      if (service.status.contains('6 AM - 11 PM')) {
        return hour >= 6 && hour < 23;
      } else if (service.status.contains('5 AM - 12 AM')) {
        return hour >= 5 && hour < 24;
      }
    }
    
    return true; // Default to open for hospitals and police
  }
}