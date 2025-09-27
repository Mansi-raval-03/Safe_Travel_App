import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class EmergencyContactService {
  static String get baseUrl => ApiConfig.currentBaseUrl;
  
  // Get JWT token from shared preferences
  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  // Get authorization headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Handle API response errors
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Request failed with status: ${response.statusCode}');
    }
  }
  
  /// Get all emergency contacts for the authenticated user
  static Future<List<EmergencyContact>> getAllContacts() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/emergency-contacts'),
        headers: headers,
      );
      
      final responseData = _handleResponse(response);
      final List<dynamic> contactsJson = responseData['data']['contacts'];
      
      return contactsJson
          .map((json) => EmergencyContact.fromJson(json))
          .toList();
          
    } catch (e) {
      print('Error getting emergency contacts: $e');
      throw Exception('Failed to load emergency contacts: $e');
    }
  }
  
  /// Add a new emergency contact
  static Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relationship,
    bool isPrimary = false,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'isPrimary': isPrimary,
      });
      
      final response = await http.post(
        Uri.parse('$baseUrl/emergency-contacts'),
        headers: headers,
        body: body,
      );
      
      final responseData = _handleResponse(response);
      return EmergencyContact.fromJson(responseData['data']['contact']);
      
    } catch (e) {
      print('Error adding emergency contact: $e');
      throw Exception('Failed to add emergency contact: $e');
    }
  }
  
  /// Update an existing emergency contact
  static Future<EmergencyContact> updateContact({
    required String contactId,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (relationship != null) updateData['relationship'] = relationship;
      if (isPrimary != null) updateData['isPrimary'] = isPrimary;
      
      final body = json.encode(updateData);
      
      final response = await http.put(
        Uri.parse('$baseUrl/emergency-contacts/$contactId'),
        headers: headers,
        body: body,
      );
      
      final responseData = _handleResponse(response);
      return EmergencyContact.fromJson(responseData['data']['contact']);
      
    } catch (e) {
      print('Error updating emergency contact: $e');
      throw Exception('Failed to update emergency contact: $e');
    }
  }
  
  /// Delete an emergency contact
  static Future<void> deleteContact(String contactId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/emergency-contacts/$contactId'),
        headers: headers,
      );
      
      _handleResponse(response);
      
    } catch (e) {
      print('Error deleting emergency contact: $e');
      throw Exception('Failed to delete emergency contact: $e');
    }
  }
  
  /// Send SOS alert to all emergency contacts
  static Future<void> sendSOSAlert({
    required double latitude,
    required double longitude,
    String? customMessage,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'latitude': latitude,
        'longitude': longitude,
        'message': customMessage ?? 'Emergency! I need help. My location is attached.',
        'alertType': 'emergency',
      });
      
      final response = await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: headers,
        body: body,
      );
      
      _handleResponse(response);
      
    } catch (e) {
      print('Error sending SOS alert: $e');
      throw Exception('Failed to send SOS alert: $e');
    }
  }
}

// Updated EmergencyContact Model to match backend
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isPrimary': isPrimary,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['_id'] ?? json['id'], // Handle both _id and id
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
      isPrimary: json['isPrimary'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact{id: $id, name: $name, phone: $phone, relationship: $relationship, isPrimary: $isPrimary}';
  }
}