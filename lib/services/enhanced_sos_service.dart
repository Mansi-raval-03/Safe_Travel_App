import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_contact_service.dart';

class EnhancedSOSService {
  static const String baseUrl = 'http://192.168.1.4:3000/api/v1';
  static EnhancedSOSService? _instance;
  
  // Timer settings
  int _sosTimerDuration = 10; // seconds
  bool _autoSendEnabled = true;
  Timer? _sosTimer;
  Function(int)? _onTimerTick;
  Function()? _onTimerComplete;
  Function()? _onTimerCancelled;

  static EnhancedSOSService get instance {
    _instance ??= EnhancedSOSService._();
    return _instance!;
  }

  EnhancedSOSService._();

  // Initialize and load settings
  Future<void> initialize() async {
    await _loadSettings();
    print('🚨 Enhanced SOS Service initialized');
    print('⏱️ Timer duration: $_sosTimerDuration seconds');
    print('🔄 Auto-send enabled: $_autoSendEnabled');
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sosTimerDuration = prefs.getInt('sos_timer_duration') ?? 10;
      _autoSendEnabled = prefs.getBool('sos_auto_send') ?? true;
    } catch (e) {
      print('❌ Error loading SOS settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sos_timer_duration', _sosTimerDuration);
      await prefs.setBool('sos_auto_send', _autoSendEnabled);
      print('✅ SOS settings saved');
    } catch (e) {
      print('❌ Error saving SOS settings: $e');
    }
  }

  // Getters
  int get timerDuration => _sosTimerDuration;
  bool get autoSendEnabled => _autoSendEnabled;
  bool get isTimerRunning => _sosTimer?.isActive ?? false;

  // Setters
  void setTimerDuration(int seconds) {
    _sosTimerDuration = seconds;
    saveSettings();
  }

  void setAutoSendEnabled(bool enabled) {
    _autoSendEnabled = enabled;
    saveSettings();
  }

  // Start SOS timer
  void startSOSTimer({
    required Function(int) onTick,
    required Function() onComplete,
    required Function() onCancelled,
  }) {
    _onTimerTick = onTick;
    _onTimerComplete = onComplete;
    _onTimerCancelled = onCancelled;

    int remainingSeconds = _sosTimerDuration;
    
    _sosTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      remainingSeconds--;
      _onTimerTick?.call(remainingSeconds);

      if (remainingSeconds <= 0) {
        timer.cancel();
        _onTimerComplete?.call();
      }
    });

    // Initial tick
    _onTimerTick?.call(remainingSeconds);
    print('⏱️ SOS Timer started: $_sosTimerDuration seconds');
  }

  // Cancel SOS timer
  void cancelSOSTimer() {
    if (_sosTimer?.isActive ?? false) {
      _sosTimer?.cancel();
      _onTimerCancelled?.call();
      print('❌ SOS Timer cancelled by user');
    }
  }

  // Send comprehensive SOS alert
  Future<bool> sendComprehensiveSOSAlert({
    required String emergencyType,
    required String message,
    required Position currentPosition,
    required List<EmergencyContact> emergencyContacts,
  }) async {
    try {
      print('🚨 Sending comprehensive SOS alert...');

      // 1. Create SOS alert in backend
      bool backendSuccess = await _createSOSAlert(
        emergencyType: emergencyType,
        message: message,
        position: currentPosition,
      );

      // 2. Send via multiple channels
      bool smsSuccess = await _sendSOSviaSMS(
        emergencyType: emergencyType,
        message: message,
        position: currentPosition,
        contacts: emergencyContacts,
      );

      bool whatsappSuccess = await _sendSOSviaWhatsApp(
        emergencyType: emergencyType,
        message: message,
        position: currentPosition,
        contacts: emergencyContacts,
      );

      // 3. Fallback to general sharing if specific channels fail
      if (!smsSuccess && !whatsappSuccess) {
        await _sendSOSviaGeneralShare(
          emergencyType: emergencyType,
          message: message,
          position: currentPosition,
          contacts: emergencyContacts,
        );
      }

      print('✅ SOS Alert sent successfully');
      print('📱 Backend: $backendSuccess, SMS: $smsSuccess, WhatsApp: $whatsappSuccess');
      
      return true;
    } catch (e) {
      print('❌ Error sending comprehensive SOS alert: $e');
      return false;
    }
  }

  // Create SOS alert in backend
  Future<bool> _createSOSAlert({
    required String emergencyType,
    required String message,
    required Position position,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token');

      if (token == null) {
        print('❌ No auth token found');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': emergencyType,
          'message': message,
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 201) {
        print('✅ SOS alert created in backend');
        return true;
      } else {
        print('❌ Backend SOS creation failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error creating backend SOS alert: $e');
      return false;
    }
  }

  // Send SOS via SMS using url_launcher
  Future<bool> _sendSOSviaSMS({
    required String emergencyType,
    required String message,
    required Position position,
    required List<EmergencyContact> contacts,
  }) async {
    try {
      if (contacts.isEmpty) {
        print('❌ No emergency contacts for SMS');
        return false;
      }

      String sosMessage = _formatSOSMessage(emergencyType, message, position);
      
      // Send to first contact via direct SMS
      String primaryContact = contacts.first.phone.replaceAll(RegExp(r'[^\d+]'), '');
      String smsUrl = 'sms:$primaryContact?body=${Uri.encodeComponent(sosMessage)}';
      
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        print('✅ SMS sent to primary contact: $primaryContact');
        
        // Send to additional contacts if any
        for (int i = 1; i < contacts.length; i++) {
          String contact = contacts[i].phone.replaceAll(RegExp(r'[^\d+]'), '');
          String additionalSmsUrl = 'sms:$contact?body=${Uri.encodeComponent(sosMessage)}';
          
          if (await canLaunchUrl(Uri.parse(additionalSmsUrl))) {
            await launchUrl(Uri.parse(additionalSmsUrl));
            await Future.delayed(Duration(milliseconds: 500)); // Small delay between sends
          }
        }
        
        return true;
      } else {
        print('❌ Cannot launch SMS');
        return false;
      }
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  // Send SOS via WhatsApp using url_launcher
  Future<bool> _sendSOSviaWhatsApp({
    required String emergencyType,
    required String message,
    required Position position,
    required List<EmergencyContact> contacts,
  }) async {
    try {
      if (contacts.isEmpty) {
        print('❌ No emergency contacts for WhatsApp');
        return false;
      }

      String sosMessage = _formatSOSMessage(emergencyType, message, position);
      
      // Send to first contact via WhatsApp
      String primaryContact = contacts.first.phone.replaceAll(RegExp(r'[^\d+]'), '');
      // Remove leading + for WhatsApp URL
      if (primaryContact.startsWith('+')) {
        primaryContact = primaryContact.substring(1);
      }
      
      String whatsappUrl = 'https://wa.me/$primaryContact?text=${Uri.encodeComponent(sosMessage)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
        print('✅ WhatsApp message sent to primary contact: $primaryContact');
        
        // Send to additional contacts if any
        for (int i = 1; i < contacts.length; i++) {
          String contact = contacts[i].phone.replaceAll(RegExp(r'[^\d+]'), '');
          if (contact.startsWith('+')) {
            contact = contact.substring(1);
          }
          
          String additionalWhatsappUrl = 'https://wa.me/$contact?text=${Uri.encodeComponent(sosMessage)}';
          
          if (await canLaunchUrl(Uri.parse(additionalWhatsappUrl))) {
            await launchUrl(
              Uri.parse(additionalWhatsappUrl),
              mode: LaunchMode.externalApplication,
            );
            await Future.delayed(Duration(seconds: 1)); // Delay between WhatsApp sends
          }
        }
        
        return true;
      } else {
        print('❌ Cannot launch WhatsApp');
        return false;
      }
    } catch (e) {
      print('❌ Error sending WhatsApp message: $e');
      return false;
    }
  }

  // Send SOS via general share (fallback)
  Future<bool> _sendSOSviaGeneralShare({
    required String emergencyType,
    required String message,
    required Position position,
    required List<EmergencyContact> contacts,
  }) async {
    try {
      String sosMessage = _formatSOSMessage(emergencyType, message, position);
      String contactList = contacts.map((c) => '${c.name}: ${c.phone}').join('\n');
      
      String fullMessage = '$sosMessage\n\n📞 Emergency Contacts:\n$contactList';
      
      final result = await Share.share(
        fullMessage,
        subject: '🚨 EMERGENCY ALERT - $emergencyType',
      );
      
      if (result.status == ShareResultStatus.success) {
        print('✅ SOS shared via general share');
        return true;
      } else {
        print('❌ General share failed or dismissed');
        return false;
      }
    } catch (e) {
      print('❌ Error with general share: $e');
      return false;
    }
  }

  // Format SOS message with location
  String _formatSOSMessage(String emergencyType, String message, Position position) {
    String googleMapsUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    
    return '''🚨 EMERGENCY ALERT 🚨

Type: ${emergencyType.toUpperCase()}
Message: $message

📍 My Current Location:
Latitude: ${position.latitude.toStringAsFixed(6)}
Longitude: ${position.longitude.toStringAsFixed(6)}
Accuracy: ${position.accuracy.toStringAsFixed(1)}m

🗺️ View on Map: $googleMapsUrl

⏰ Time: ${DateTime.now().toString()}

This is an automated emergency message from Safe Travel App. Please respond immediately!''';
  }

  // One-click SOS with timer
  Future<void> triggerOneClickSOS({
    required BuildContext context,
    required String emergencyType,
    required String message,
    required Position currentPosition,
    required List<EmergencyContact> emergencyContacts,
  }) async {
    if (!_autoSendEnabled) {
      // Immediate send without timer
      await sendComprehensiveSOSAlert(
        emergencyType: emergencyType,
        message: message,
        currentPosition: currentPosition,
        emergencyContacts: emergencyContacts,
      );
      return;
    }

    // Show timer dialog
    _showSOSTimerDialog(
      context: context,
      emergencyType: emergencyType,
      message: message,
      currentPosition: currentPosition,
      emergencyContacts: emergencyContacts,
    );
  }

  // Show SOS timer dialog
  void _showSOSTimerDialog({
    required BuildContext context,
    required String emergencyType,
    required String message,
    required Position currentPosition,
    required List<EmergencyContact> emergencyContacts,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            int remainingSeconds = _sosTimerDuration;
            bool isCancelled = false;

            startSOSTimer(
              onTick: (seconds) {
                if (!isCancelled) {
                  setState(() {
                    remainingSeconds = seconds;
                  });
                }
              },
              onComplete: () async {
                if (!isCancelled) {
                  Navigator.of(context).pop();
                  await sendComprehensiveSOSAlert(
                    emergencyType: emergencyType,
                    message: message,
                    currentPosition: currentPosition,
                    emergencyContacts: emergencyContacts,
                  );
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🚨 Emergency alert sent to all contacts!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              onCancelled: () {
                if (!isCancelled) {
                  Navigator.of(context).pop();
                }
              },
            );

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Text('Emergency Alert'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: remainingSeconds / _sosTimerDuration,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    strokeWidth: 8,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Sending in $remainingSeconds seconds',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Emergency Type: $emergencyType',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Contacts: ${emergencyContacts.length}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Your location and emergency message will be sent via SMS and WhatsApp to all emergency contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    isCancelled = true;
                    cancelSOSTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    isCancelled = true;
                    cancelSOSTimer();
                    Navigator.of(context).pop();
                    
                    await sendComprehensiveSOSAlert(
                      emergencyType: emergencyType,
                      message: message,
                      currentPosition: currentPosition,
                      emergencyContacts: emergencyContacts,
                    );
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🚨 Emergency alert sent immediately!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Send Now', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dispose
  void dispose() {
    _sosTimer?.cancel();
  }
}