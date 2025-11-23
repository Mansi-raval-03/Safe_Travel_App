import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'integrated_offline_emergency_service.dart';
import 'contact_adapter.dart';

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
      // Prefer local offline contacts (single source of truth while migrating)
      try {
        final local = await IntegratedOfflineEmergencyService.instance.getAllEmergencyContacts();
        if (local.isNotEmpty) {
          // Map to legacy model for existing callers
          return local.map((o) => EmergencyContact.fromOffline(o)).toList();
        }
      } catch (e) {
        // Ignore local lookup failures and fall back to API
        print('⚠️ Failed to read local contacts: $e');
      }

      print('🔄 Fetching emergency contacts from API...');
      print('🌐 API URL: $baseUrl/emergency-contacts');

      final headers = await _getAuthHeaders();
      print('🔑 Auth headers: ${headers.keys.join(', ')}');

      final response = await http.get(
        Uri.parse('$baseUrl/emergency-contacts'),
        headers: headers,
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📄 API Response Body: ${response.body}');

      final responseData = _handleResponse(response);
      final List<dynamic> contactsJson = responseData['data']['contacts'];

      print('📊 Raw contacts data: $contactsJson');

      final contacts = contactsJson
          .map((json) => EmergencyContact.fromJson(json))
          .toList();

      print('✅ Successfully parsed ${contacts.length} emergency contacts');
      return contacts;
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
      final contact = EmergencyContact.fromJson(responseData['data']['contact']);

      // Also ensure the contact is available offline (best-effort)
      try {
        final offline = contact.toOffline();
        await IntegratedOfflineEmergencyService.instance.addEmergencyContact(offline);
      } catch (e) {
        print('⚠️ Failed to cache contact locally: $e');
      }

      return contact;
      
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
      final updated = EmergencyContact.fromJson(responseData['data']['contact']);

      // Best-effort: update local cache to keep offline store in sync
      try {
        final offline = updated.toOffline();
        final service = IntegratedOfflineEmergencyService.instance;
        final localList = await service.getAllEmergencyContacts();
        // Try to find a match by phone or name
        final match = localList.firstWhere(
          (c) => c.phone == updated.phone || c.name == updated.name,
          orElse: () => OfflineEmergencyContact(id: null, name: '', phone: '', createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
        );

        if (match.id != null) {
          // Preserve id on update
          final toUpdate = offline.copyWith(id: match.id);
          await service.updateEmergencyContact(toUpdate);
        } else {
          await service.addEmergencyContact(offline);
        }
      } catch (e) {
        print('⚠️ Failed to sync updated contact to local cache: $e');
      }

      return updated;
      
    } catch (e) {
      print('Error updating emergency contact: $e');
      throw Exception('Failed to update emergency contact: $e');
    }
  }
  
  /// Delete an emergency contact
  static Future<void> deleteContact(String contactId) async {
    try {
      final headers = await _getAuthHeaders();

      // Try to fetch contact details before deletion to sync local cache
      String? phoneToRemove;
      try {
        final getResp = await http.get(
          Uri.parse('$baseUrl/emergency-contacts/$contactId'),
          headers: headers,
        );
        final getData = _handleResponse(getResp);
        if (getData['data'] != null && getData['data']['contact'] != null) {
          phoneToRemove = getData['data']['contact']['phone'];
        }
      } catch (e) {
        print('⚠️ Could not fetch contact details before delete: $e');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/emergency-contacts/$contactId'),
        headers: headers,
      );

      _handleResponse(response);

      // Best-effort: delete local cached contact(s) with matching phone
      if (phoneToRemove != null && phoneToRemove.trim().isNotEmpty) {
        try {
          final service = IntegratedOfflineEmergencyService.instance;
          final local = await service.getAllEmergencyContacts();
          final matches = local.where((c) => c.phone == phoneToRemove).toList();
          for (final m in matches) {
            if (m.id != null) await service.deleteEmergencyContact(m.id!);
          }
        } catch (e) {
          print('⚠️ Failed to delete local cached contact(s): $e');
        }
      }
      
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

  /// Convert from an offline contact to the legacy/remote model
  factory EmergencyContact.fromOffline(OfflineEmergencyContact offline) {
    final String id = offline.id != null ? offline.id!.toString() : 'local-${offline.createdAt}';
    return EmergencyContact(
      id: id,
      name: offline.name,
      phone: offline.phone,
      relationship: offline.relationship ?? '',
      isPrimary: offline.isPrimary,
      createdAt: DateTime.fromMillisecondsSinceEpoch(offline.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(offline.updatedAt),
    );
  }

  /// Convert legacy/remote model to offline model for caching
  OfflineEmergencyContact toOffline() {
    return OfflineEmergencyContact(
      id: null,
      name: name,
      phone: phone,
      email: null,
      relationship: relationship,
      isPrimary: isPrimary,
      isActive: true,
      createdAt: createdAt?.millisecondsSinceEpoch,
      updatedAt: updatedAt?.millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact{id: $id, name: $name, phone: $phone, relationship: $relationship, isPrimary: $isPrimary}';
  }
}