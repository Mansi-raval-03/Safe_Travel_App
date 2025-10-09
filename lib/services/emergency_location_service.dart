import 'package:geolocator/geolocator.dart';
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
  static final List<EmergencyService> _emergencyServices = [
    // Hospitals
    EmergencyService(
      id: 'hospital_1',
      name: 'City General Hospital',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: '456 Medical Center Blvd, Downtown',
      phone: '+1-555-0123',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 37.7749,
      longitude: -122.4194,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'hospital_2',
      name: 'Emergency Medical Center',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: '789 Health Ave, Midtown',
      phone: '+1-555-0124',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 37.7849,
      longitude: -122.4094,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'hospital_3',
      name: 'Regional Medical Hospital',
      type: 'Hospital',
      icon: Icons.local_hospital,
      address: '321 Care St, Uptown',
      phone: '+1-555-0125',
      status: 'Open 24/7',
      color: Colors.red,
      latitude: 37.7649,
      longitude: -122.4294,
      isOpen24Hours: true,
    ),

    // Police Stations
    EmergencyService(
      id: 'police_1',
      name: 'Central Police Station',
      type: 'Police',
      icon: Icons.shield,
      address: '789 Justice Ave, Downtown',
      phone: '+1-555-0911',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 37.7759,
      longitude: -122.4184,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'police_2',
      name: 'North District Police',
      type: 'Police',
      icon: Icons.shield,
      address: '456 Safety Blvd, North Side',
      phone: '+1-555-0912',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 37.7859,
      longitude: -122.4084,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'police_3',
      name: 'West Police Precinct',
      type: 'Police',
      icon: Icons.shield,
      address: '987 Law St, West End',
      phone: '+1-555-0913',
      status: 'Open 24/7',
      color: Colors.blue,
      latitude: 37.7659,
      longitude: -122.4384,
      isOpen24Hours: true,
    ),

    // Gas Stations
    EmergencyService(
      id: 'fuel_1',
      name: 'QuickFill Gas Station',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: '321 Highway 101, Main St',
      phone: '+1-555-0456',
      status: 'Open 6 AM - 11 PM',
      color: Colors.green,
      latitude: 37.7719,
      longitude: -122.4144,
      isOpen24Hours: false,
    ),
    EmergencyService(
      id: 'fuel_2',
      name: '24/7 Express Fuel',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: '654 Express Way, Highway 5',
      phone: '+1-555-0457',
      status: 'Open 24/7',
      color: Colors.green,
      latitude: 37.7819,
      longitude: -122.4044,
      isOpen24Hours: true,
    ),
    EmergencyService(
      id: 'fuel_3',
      name: 'City Gas & Services',
      type: 'Fuel',
      icon: Icons.local_gas_station,
      address: '123 Fuel Ave, Central',
      phone: '+1-555-0458',
      status: 'Open 5 AM - 12 AM',
      color: Colors.green,
      latitude: 37.7679,
      longitude: -122.4244,
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