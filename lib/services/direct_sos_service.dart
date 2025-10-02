import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_contact_service.dart';

class DirectSOSService {
  static DirectSOSService? _instance;
  static DirectSOSService get instance {
    _instance ??= DirectSOSService._();
    return _instance!;
  }
  DirectSOSService._();

  // Offline mode settings
  bool _offlineMode = false;
  List<String> _offlineMessages = [];
  Position? _lastKnownPosition;

  bool get isOfflineMode => _offlineMode;
  
  /// Check network connectivity
  Future<bool> _isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Initialize offline mode monitoring
  Future<void> initializeOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    _offlineMode = !await _isNetworkAvailable();
    
    // Load offline messages
    _offlineMessages = prefs.getStringList('offline_messages') ?? [];
    
    // Load last known position
    final lat = prefs.getDouble('last_lat');
    final lng = prefs.getDouble('last_lng');
    if (lat != null && lng != null) {
      _lastKnownPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    
    print('🌐 Offline mode initialized: $_offlineMode');
  }

  /// Save current position for offline use
  Future<void> _saveOfflinePosition(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_lat', position.latitude);
    await prefs.setDouble('last_lng', position.longitude);
    _lastKnownPosition = position;
  }

  /// Get current or last known position
  Future<Position?> _getCurrentPosition() async {
    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        print('❌ Location permission denied');
        return _lastKnownPosition;
      }

      // Try to get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      
      // Save for offline use
      await _saveOfflinePosition(position);
      return position;
    } catch (e) {
      print('❌ Error getting position: $e');
      return _lastKnownPosition;
    }
  }

  /// Format SOS message with location
  String _formatSOSMessage(Position? position, String customMessage) {
    final timestamp = DateTime.now().toString();
    
    if (position != null) {
      final mapsUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      return '''🚨 EMERGENCY ALERT 🚨

$customMessage

📍 My Current Location:
Latitude: ${position.latitude.toStringAsFixed(6)}
Longitude: ${position.longitude.toStringAsFixed(6)}
Accuracy: ${position.accuracy.toStringAsFixed(1)}m

🗺️ View on Map: $mapsUrl

⏰ Time: $timestamp

This is an automated emergency message from Safe Travel App. Please respond immediately!

${_offlineMode ? '📵 SENT IN OFFLINE MODE - May have delays' : ''}''';
    } else {
      return '''🚨 EMERGENCY ALERT 🚨

$customMessage

📍 Location: Unable to determine current location
⏰ Time: $timestamp

This is an automated emergency message from Safe Travel App. Please respond immediately!

${_offlineMode ? '📵 SENT IN OFFLINE MODE - May have delays' : ''}''';
    }
  }

  /// Send direct SMS without opening SMS app
  Future<bool> _sendDirectSMS(String phoneNumber, String message) async {
    try {
      // Format phone number
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Create SMS URL with message
      final smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        throw 'Cannot launch SMS for $cleanPhone';
      }
    } catch (e) {
      print('❌ SMS send failed to $phoneNumber: $e');
      return false;
    }
  }

  /// Send direct WhatsApp message
  Future<bool> _sendDirectWhatsApp(String phoneNumber, String message) async {
    try {
      // Format phone number for WhatsApp
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }

      // Create WhatsApp URL
      final whatsappUri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}'
      );

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw 'Cannot launch WhatsApp for $cleanPhone';
      }
    } catch (e) {
      print('❌ WhatsApp send failed to $phoneNumber: $e');
      return false;
    }
  }

  /// Store message for offline sending
  Future<void> _storeOfflineMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    _offlineMessages.add('${DateTime.now().toIso8601String()}: $message');
    await prefs.setStringList('offline_messages', _offlineMessages);
  }

  /// Send SOS to all contacts with direct messaging
  Future<Map<String, dynamic>> sendDirectSOS({
    required List<EmergencyContact> contacts,
    String customMessage = 'Emergency! I need help. Please contact me immediately.',
    bool includeWhatsApp = true,
    bool includeSMS = true,
  }) async {
    Map<String, dynamic> results = {
      'success': false,
      'smsCount': 0,
      'whatsappCount': 0,
      'totalContacts': contacts.length,
      'errors': <String>[],
      'offlineMode': _offlineMode,
    };

    try {
      // Check network status
      _offlineMode = !await _isNetworkAvailable();
      
      // Get current position
      Position? position = await _getCurrentPosition();
      
      // Format message
      String sosMessage = _formatSOSMessage(position, customMessage);
      
      print('🚨 Sending direct SOS to ${contacts.length} contacts');
      print('📶 Network available: ${!_offlineMode}');
      print('📍 Position available: ${position != null}');

      // Send to each contact
      int smsSuccessCount = 0;
      int whatsappSuccessCount = 0;

      for (EmergencyContact contact in contacts) {
        try {
          // Send SMS
          if (includeSMS) {
            bool smsSuccess = await _sendDirectSMS(contact.phone, sosMessage);
            if (smsSuccess) {
              smsSuccessCount++;
              print('✅ SMS sent to ${contact.name}');
            } else {
              results['errors'].add('SMS failed for ${contact.name}');
            }
            
            // Small delay between messages
            await Future.delayed(Duration(milliseconds: 500));
          }

          // Send WhatsApp
          if (includeWhatsApp) {
            bool whatsappSuccess = await _sendDirectWhatsApp(contact.phone, sosMessage);
            if (whatsappSuccess) {
              whatsappSuccessCount++;
              print('✅ WhatsApp sent to ${contact.name}');
            } else {
              results['errors'].add('WhatsApp failed for ${contact.name}');
            }
            
            // Small delay between messages
            await Future.delayed(Duration(milliseconds: 1000));
          }

        } catch (e) {
          results['errors'].add('Error sending to ${contact.name}: $e');
          print('❌ Error sending to ${contact.name}: $e');
        }
      }

      // Store for offline if needed
      if (_offlineMode) {
        await _storeOfflineMessage(sosMessage);
      }

      results['smsCount'] = smsSuccessCount;
      results['whatsappCount'] = whatsappSuccessCount;
      results['success'] = (smsSuccessCount > 0 || whatsappSuccessCount > 0);

      print('📊 SOS Results: SMS: $smsSuccessCount, WhatsApp: $whatsappSuccessCount');
      
      return results;

    } catch (e) {
      results['errors'].add('Critical error: $e');
      print('❌ Critical SOS error: $e');
      return results;
    }
  }

  /// Send one-click SOS with automatic retry
  Future<Map<String, dynamic>> sendOneClickSOS() async {
    try {
      // Load contacts
      List<EmergencyContact> contacts = await EmergencyContactService.getAllContacts();
      
      if (contacts.isEmpty) {
        return {
          'success': false,
          'error': 'No emergency contacts found. Please add contacts first.',
        };
      }

      // Send direct SOS
      return await sendDirectSOS(
        contacts: contacts,
        customMessage: 'URGENT EMERGENCY! I need immediate help. This is an automated SOS alert.',
        includeWhatsApp: true,
        includeSMS: true,
      );

    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to send SOS: $e',
      };
    }
  }

  /// Retry offline messages when network is available
  Future<int> retryOfflineMessages() async {
    if (_offlineMessages.isEmpty) return 0;

    // Check if network is back
    if (!await _isNetworkAvailable()) return 0;

    // Try to send via share_plus as fallback
    int sentCount = 0;
    List<String> remainingMessages = [];

    for (String message in _offlineMessages) {
      try {
        await Share.share(message, subject: '🚨 Delayed Emergency Alert');
        sentCount++;
      } catch (e) {
        remainingMessages.add(message);
      }
    }

    // Update stored messages
    _offlineMessages = remainingMessages;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('offline_messages', _offlineMessages);

    print('📤 Sent $sentCount offline messages');
    return sentCount;
  }

  /// Get offline status info
  Map<String, dynamic> getOfflineStatus() {
    return {
      'isOffline': _offlineMode,
      'pendingMessages': _offlineMessages.length,
      'lastKnownPosition': _lastKnownPosition != null,
      'lastPositionTime': _lastKnownPosition?.timestamp.toString(),
    };
  }
}