import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'emergency_contact_service.dart';
import 'location_service.dart';
import 'native_location_sharing_service.dart';

/// Service for handling SOS emergency alerts with automatic location sharing
class SOSEmergencyService {
  static final SOSEmergencyService _instance = SOSEmergencyService._internal();
  factory SOSEmergencyService() => _instance;
  SOSEmergencyService._internal();

  final LocationService _locationService = LocationService();
  final NativeLocationSharingService _nativeSharing = NativeLocationSharingService();
  
  bool _isEmergencyActive = false;
  DateTime? _emergencyStartTime;
  List<EmergencyContact> _emergencyContacts = [];

  /// Trigger SOS emergency alert with automatic location sharing
  Future<SOSEmergencyResult> triggerSOSEmergency({
    String? customMessage,
    bool shareViaWhatsApp = true,
    bool shareViaSMS = true,
  }) async {
    try {
      print('🚨 SOS Emergency triggered - starting automatic location sharing...');
      
      _isEmergencyActive = true;
      _emergencyStartTime = DateTime.now();
      
      // Get current location
      Position? currentPosition = _locationService.currentPosition;
      if (currentPosition == null) {
        print('📍 Getting current location for emergency...');
        currentPosition = await _locationService.getCurrentLocation();
        if (currentPosition == null) {
          return SOSEmergencyResult(
            success: false,
            message: 'Could not get current location for emergency alert',
            contactsNotified: 0,
          );
        }
      }

      // Get emergency contacts
      print('📞 Loading emergency contacts...');
      try {
        _emergencyContacts = await EmergencyContactService.getAllContacts();
        if (_emergencyContacts.isEmpty) {
          return SOSEmergencyResult(
            success: false,
            message: 'No emergency contacts found. Please add emergency contacts first.',
            contactsNotified: 0,
          );
        }
        print('✅ Found ${_emergencyContacts.length} emergency contacts');
      } catch (e) {
        print('❌ Error loading emergency contacts: $e');
        return SOSEmergencyResult(
          success: false,
          message: 'Failed to load emergency contacts: $e',
          contactsNotified: 0,
        );
      }

      // Create emergency message
      final emergencyMessage = _createEmergencyMessage(currentPosition, customMessage);
      
      int successfulNotifications = 0;
      List<String> failedContacts = [];
      List<ContactNotificationResult> notificationResults = [];

      // Send notifications to each emergency contact
      for (final contact in _emergencyContacts) {
        print('📱 Notifying ${contact.name} (${contact.phone})...');
        
        final contactResult = await _notifyEmergencyContact(
          contact: contact,
          position: currentPosition,
          message: emergencyMessage,
          shareViaWhatsApp: shareViaWhatsApp,
          shareViaSMS: shareViaSMS,
        );
        
        notificationResults.add(contactResult);
        
        if (contactResult.success) {
          successfulNotifications++;
          print('✅ Successfully notified ${contact.name}');
        } else {
          failedContacts.add(contact.name);
          print('❌ Failed to notify ${contact.name}: ${contactResult.error}');
        }
      }

      final overallSuccess = successfulNotifications > 0;
      final resultMessage = overallSuccess
          ? 'SOS Alert sent! ${successfulNotifications}/${_emergencyContacts.length} contacts notified'
          : 'Failed to notify any emergency contacts';

      print(overallSuccess ? '✅ SOS Emergency completed successfully' : '❌ SOS Emergency failed');
      
      return SOSEmergencyResult(
        success: overallSuccess,
        message: resultMessage,
        contactsNotified: successfulNotifications,
        totalContacts: _emergencyContacts.length,
        failedContacts: failedContacts,
        notificationResults: notificationResults,
        emergencyLocation: currentPosition,
        emergencyTime: _emergencyStartTime,
      );

    } catch (e) {
      print('❌ Error during SOS emergency: $e');
      return SOSEmergencyResult(
        success: false,
        message: 'Emergency alert failed: $e',
        contactsNotified: 0,
      );
    }
  }

  /// Notify a single emergency contact via multiple channels
  Future<ContactNotificationResult> _notifyEmergencyContact({
    required EmergencyContact contact,
    required Position position,
    required String message,
    required bool shareViaWhatsApp,
    required bool shareViaSMS,
  }) async {
    bool whatsappSuccess = false;
    bool smsSuccess = false;
    String? error;

    try {
      // Try WhatsApp first (if enabled and available)
      if (shareViaWhatsApp) {
        try {
          whatsappSuccess = await _nativeSharing.shareLocationViaWhatsApp(
            position,
            message: message,
          );
          if (whatsappSuccess) {
            print('✅ WhatsApp location sent to ${contact.name}');
          }
        } catch (e) {
          print('❌ WhatsApp sharing failed for ${contact.name}: $e');
        }
      }

      // Try SMS (if enabled)
      if (shareViaSMS) {
        try {
          smsSuccess = await _nativeSharing.shareLocationViaSMS(
            position,
            message: message,
            phoneNumber: contact.phone,
          );
          if (smsSuccess) {
            print('✅ SMS location sent to ${contact.name} (${contact.phone})');
          }
        } catch (e) {
          print('❌ SMS sharing failed for ${contact.name}: $e');
          error = e.toString();
        }
      }

      final success = whatsappSuccess || smsSuccess;
      return ContactNotificationResult(
        contact: contact,
        success: success,
        whatsappSent: whatsappSuccess,
        smsSent: smsSuccess,
        error: success ? null : (error ?? 'All sharing methods failed'),
      );

    } catch (e) {
      return ContactNotificationResult(
        contact: contact,
        success: false,
        whatsappSent: false,
        smsSent: false,
        error: e.toString(),
      );
    }
  }

  /// Create emergency message with location details
  String _createEmergencyMessage(Position position, String? customMessage) {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    final accuracy = position.accuracy.toStringAsFixed(0);
    final timestamp = DateTime.now().toString().substring(0, 19);
    
    final mapsUrl = 'https://maps.google.com/maps?q=$lat,$lng&z=15';
    
    return '''🚨 EMERGENCY ALERT 🚨

${customMessage ?? 'I need immediate help! This is an emergency situation.'}

📍 MY CURRENT LOCATION:
Coordinates: $lat, $lng
Accuracy: ${accuracy}m
Time: $timestamp

🗺️ View my location on map:
$mapsUrl

⚠️ This is an automated emergency alert from Safe Travel App. Please respond immediately or contact emergency services if needed.

🚨 EMERGENCY - PLEASE HELP 🚨''';
  }

  /// Get current emergency status
  Map<String, dynamic> getEmergencyStatus() {
    return {
      'isEmergencyActive': _isEmergencyActive,
      'emergencyStartTime': _emergencyStartTime?.toIso8601String(),
      'emergencyContactsCount': _emergencyContacts.length,
    };
  }

  /// Clear emergency status
  void clearEmergencyStatus() {
    _isEmergencyActive = false;
    _emergencyStartTime = null;
    print('🔄 Emergency status cleared');
  }

  /// Check if emergency contacts are available
  Future<bool> hasEmergencyContacts() async {
    try {
      final contacts = await EmergencyContactService.getAllContacts();
      return contacts.isNotEmpty;
    } catch (e) {
      print('❌ Error checking emergency contacts: $e');
      return false;
    }
  }

  /// Get count of emergency contacts
  Future<int> getEmergencyContactsCount() async {
    try {
      print('🔄 Getting emergency contacts count...');
      final contacts = await EmergencyContactService.getAllContacts();
      print('📊 Emergency contacts count: ${contacts.length}');
      if (contacts.isNotEmpty) {
        print('📋 Emergency contacts list:');
        for (int i = 0; i < contacts.length; i++) {
          final contact = contacts[i];
          print('   ${i + 1}. ${contact.name} (${contact.phone}) - ${contact.relationship}');
        }
      }
      return contacts.length;
    } catch (e) {
      print('❌ Error getting emergency contacts count: $e');
      return 0;
    }
  }
}

/// Result of SOS emergency alert
class SOSEmergencyResult {
  final bool success;
  final String message;
  final int contactsNotified;
  final int? totalContacts;
  final List<String>? failedContacts;
  final List<ContactNotificationResult>? notificationResults;
  final Position? emergencyLocation;
  final DateTime? emergencyTime;

  SOSEmergencyResult({
    required this.success,
    required this.message,
    required this.contactsNotified,
    this.totalContacts,
    this.failedContacts,
    this.notificationResults,
    this.emergencyLocation,
    this.emergencyTime,
  });
}

/// Result of notifying a single contact
class ContactNotificationResult {
  final EmergencyContact contact;
  final bool success;
  final bool whatsappSent;
  final bool smsSent;
  final String? error;

  ContactNotificationResult({
    required this.contact,
    required this.success,
    required this.whatsappSent,
    required this.smsSent,
    this.error,
  });
}