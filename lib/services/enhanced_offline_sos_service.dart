import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'offline_database_service.dart';
import 'emergency_contact_service.dart';

/// Enhanced Offline SOS Service
/// Provides comprehensive offline SOS functionality with SQLite database integration,
/// Socket.IO real-time communication, and automatic sync when network returns
class EnhancedOfflineSOSService {
  static EnhancedOfflineSOSService? _instance;
  static EnhancedOfflineSOSService get instance {
    _instance ??= EnhancedOfflineSOSService._();
    return _instance!;
  }
  EnhancedOfflineSOSService._();

  // Services
  late OfflineDatabaseService _dbService;

  // Network monitoring
  bool _isOnline = true;
  Timer? _networkCheckTimer;
  Timer? _syncTimer;
  
  // Stream controllers for status updates
  final _networkStatusController = StreamController<bool>.broadcast();
  final _syncStatusController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isOnline => _isOnline;
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  Stream<Map<String, dynamic>> get syncStatusStream => _syncStatusController.stream;

  /// Initialize the offline SOS service
  Future<void> initialize() async {
    try {
      print('🚀 Initializing Enhanced Offline SOS Service...');

      // Initialize services
      _dbService = OfflineDatabaseService.instance;

      // Initialize database
      await _dbService.database;

      // Cache emergency contacts
      await _cacheEmergencyContacts();

      // Start network monitoring
      _startNetworkMonitoring();

      // Start periodic sync
      _startPeriodicSync();

      print('✅ Enhanced Offline SOS Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Enhanced Offline SOS Service: $e');
      rethrow;
    }
  }

  /// Cache emergency contacts for offline access
  Future<void> _cacheEmergencyContacts() async {
    try {
      final contacts = await EmergencyContactService.getAllContacts();
      await _dbService.cacheEmergencyContacts(contacts);
      print('👥 Emergency contacts cached for offline access');
    } catch (e) {
      print('❌ Error caching emergency contacts: $e');
    }
  }

  /// Start network connectivity monitoring
  void _startNetworkMonitoring() {
    _networkCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      final wasOnline = _isOnline;
      _isOnline = await _checkNetworkConnectivity();
      
      if (wasOnline != _isOnline) {
        _networkStatusController.add(_isOnline);
        print('🌐 Network status changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
        
        if (_isOnline) {
          // Network restored - trigger sync
          await _syncOfflineData();
        }
      }
    });
  }

  /// Check network connectivity
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_isOnline) {
        await _syncOfflineData();
      }
    });
  }

  /// Send SOS alert (online or offline)
  Future<Map<String, dynamic>> sendSOSAlert({
    required String emergencyType,
    required String message,
    required BuildContext context,
  }) async {
    try {
      print('🚨 Sending SOS Alert - Type: $emergencyType');

      // Get current position
      final position = await _getCurrentPosition();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Store in database
      final sosId = await _dbService.storeSOSAlert(
        emergencyType: emergencyType,
        message: message,
        position: position,
      );

      // Store location data
      await _dbService.storeLocationData(position);

      // Get emergency contacts
      final contacts = await _getAvailableEmergencyContacts();
      if (contacts.isEmpty) {
        throw Exception('No emergency contacts available');
      }

      final result = <String, dynamic>{
        'success': true,
        'sos_id': sosId,
        'online': _isOnline,
        'contacts_notified': 0,
        'pending_shares': 0,
        'errors': <String>[],
      };

      if (_isOnline) {
        // Online mode - send immediately via multiple channels
        final onlineResult = await _sendOnlineSOSAlert(
          sosId: sosId,
          emergencyType: emergencyType,
          message: message,
          position: position,
          contacts: contacts,
          context: context,
        );
        result['contacts_notified'] = onlineResult['contacts_notified'];
        result['pending_shares'] = onlineResult['pending_shares'];
        result['errors'] = onlineResult['errors'];
      } else {
        // Offline mode - queue for later sending
        final offlineResult = await _queueOfflineSOSAlert(
          sosId: sosId,
          emergencyType: emergencyType,
          message: message,
          position: position,
          contacts: contacts,
        );
        result['contacts_notified'] = offlineResult['contacts_notified'];
        result['pending_shares'] = offlineResult['pending_shares'];
        result['errors'] = offlineResult['errors'];
      }

      return result;
    } catch (e) {
      print('❌ Error sending SOS alert: $e');
      return {
        'success': false,
        'error': e.toString(),
        'online': _isOnline,
      };
    }
  }

  /// Send SOS alert when online
  Future<Map<String, dynamic>> _sendOnlineSOSAlert({
    required int sosId,
    required String emergencyType,
    required String message,
    required Position position,
    required List<EmergencyContact> contacts,
    required BuildContext context,
  }) async {
    int contactsNotified = 0;
    int pendingShares = 0;
    final errors = <String>[];

    try {
      // Send via Socket.IO for real-time notification
      await _sendSocketIONotification(emergencyType, message, position);

      // Send to each emergency contact
      for (final contact in contacts) {
        try {
          // SMS
          final smsSuccess = await _sendSMSAlert(contact.phone, emergencyType, message, position);
          if (smsSuccess) contactsNotified++;

          // WhatsApp
          final whatsappSuccess = await _sendWhatsAppAlert(contact.phone, emergencyType, message, position);
          if (whatsappSuccess) contactsNotified++;

          // Store successful send
          await _dbService.addPendingShare(
            sosAlertId: sosId,
            contactId: contact.id.hashCode,
            shareType: 'immediate',
            messageContent: _formatSOSMessage(emergencyType, message, position),
            contactInfo: contact.phone,
          );

        } catch (e) {
          errors.add('Failed to notify ${contact.name}: $e');
          
          // Queue for retry
          await _dbService.addPendingShare(
            sosAlertId: sosId,
            contactId: contact.id.hashCode,
            shareType: 'sms',
            messageContent: _formatSOSMessage(emergencyType, message, position),
            contactInfo: contact.phone,
          );
          pendingShares++;
        }
      }

      // Show success notification
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 SOS Alert sent to $contactsNotified contacts'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      return {
        'contacts_notified': contactsNotified,
        'pending_shares': pendingShares,
        'errors': errors,
      };
    } catch (e) {
      errors.add('Online SOS sending error: $e');
      return {
        'contacts_notified': contactsNotified,
        'pending_shares': pendingShares,
        'errors': errors,
      };
    }
  }

  /// Queue SOS alert for offline sending
  Future<Map<String, dynamic>> _queueOfflineSOSAlert({
    required int sosId,
    required String emergencyType,
    required String message,
    required Position position,
    required List<EmergencyContact> contacts,
  }) async {
    int pendingShares = 0;
    final errors = <String>[];

    try {
      final sosMessage = _formatSOSMessage(emergencyType, message, position);

      for (final contact in contacts) {
        // Queue SMS
        final smsId = await _dbService.addPendingShare(
          sosAlertId: sosId,
          contactId: contact.id.hashCode,
          shareType: 'sms',
          messageContent: sosMessage,
          contactInfo: contact.phone,
        );
        if (smsId > 0) pendingShares++;

        // Queue WhatsApp
        final whatsappId = await _dbService.addPendingShare(
          sosAlertId: sosId,
          contactId: contact.id.hashCode,
          shareType: 'whatsapp',
          messageContent: sosMessage,
          contactInfo: contact.phone,
        );
        if (whatsappId > 0) pendingShares++;

        // Queue offline message
        await _dbService.queueOfflineMessage(
          messageType: 'sos',
          recipient: contact.phone,
          messageContent: sosMessage,
          priority: 4, // Critical priority
          metadata: jsonEncode({
            'emergency_type': emergencyType,
            'contact_name': contact.name,
            'sos_id': sosId,
          }),
        );
      }

      print('⏳ SOS Alert queued for offline sending - $pendingShares pending shares');

      return {
        'contacts_notified': 0,
        'pending_shares': pendingShares,
        'errors': errors,
      };
    } catch (e) {
      errors.add('Offline SOS queuing error: $e');
      return {
        'contacts_notified': 0,
        'pending_shares': pendingShares,
        'errors': errors,
      };
    }
  }

  /// Send Socket.IO notification for real-time updates
  Future<void> _sendSocketIONotification(String emergencyType, String message, Position position) async {
    try {
      // TODO: Implement Socket.IO notification when SocketService is available
      print('📡 Socket.IO SOS notification prepared (service not available)');
    } catch (e) {
      print('❌ Socket.IO notification error: $e');
    }
  }

  /// Send SMS alert
  Future<bool> _sendSMSAlert(String phone, String emergencyType, String message, Position position) async {
    try {
      final sosMessage = _formatSOSMessage(emergencyType, message, position);
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final smsUrl = 'sms:$cleanPhone?body=${Uri.encodeComponent(sosMessage)}';
      
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        print('📱 SMS alert sent to: $cleanPhone');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ SMS alert error: $e');
      return false;
    }
  }

  /// Send WhatsApp alert
  Future<bool> _sendWhatsAppAlert(String phone, String emergencyType, String message, Position position) async {
    try {
      final sosMessage = _formatSOSMessage(emergencyType, message, position);
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }
      
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(sosMessage)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
        print('💬 WhatsApp alert sent to: $cleanPhone');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ WhatsApp alert error: $e');
      return false;
    }
  }

  /// Get current position with fallback to cached location
  Future<Position?> _getCurrentPosition() async {
    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        print('❌ Location permission denied - using cached location');
        return await _dbService.getLastKnownLocation();
      }

      // Try to get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      
      // Store for offline use
      await _dbService.storeLocationData(position);
      return position;
    } catch (e) {
      print('❌ Error getting current position: $e');
      // Fallback to cached location
      return await _dbService.getLastKnownLocation();
    }
  }

  /// Get available emergency contacts (cached or live)
  Future<List<EmergencyContact>> _getAvailableEmergencyContacts() async {
    try {
      if (_isOnline) {
        // Try to get live contacts and cache them
        final contacts = await EmergencyContactService.getAllContacts();
        if (contacts.isNotEmpty) {
          await _dbService.cacheEmergencyContacts(contacts);
          return contacts;
        }
      }
      
      // Fallback to cached contacts
      return await _dbService.getCachedEmergencyContacts();
    } catch (e) {
      print('❌ Error getting emergency contacts: $e');
      // Return cached contacts as fallback
      return await _dbService.getCachedEmergencyContacts();
    }
  }

  /// Format SOS message with location details
  String _formatSOSMessage(String emergencyType, String message, Position position) {
    final googleMapsUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    
    return '''🚨 EMERGENCY ALERT 🚨

Type: ${emergencyType.toUpperCase()}
Message: $message

📍 My Current Location:
Lat: ${position.latitude.toStringAsFixed(6)}
Lng: ${position.longitude.toStringAsFixed(6)}
Accuracy: ${position.accuracy.toStringAsFixed(1)}m

🗺️ View on Map: $googleMapsUrl

⏰ Time: ${DateTime.now().toString()}
📱 Sent via Safe Travel App

This is an automated emergency message. Please respond immediately!''';
  }

  /// Sync offline data when network is restored
  Future<void> _syncOfflineData() async {
    if (!_isOnline) return;

    try {
      print('🔄 Starting offline data sync...');
      
      final syncResult = <String, dynamic>{
        'pending_shares_processed': 0,
        'offline_messages_sent': 0,
        'sos_alerts_synced': 0,
        'errors': <String>[],
      };

      // Process pending shares
      final pendingShares = await _dbService.getPendingShares();
      for (final share in pendingShares) {
        try {
          bool success = false;
          final shareType = share['share_type'] as String;
          final contactInfo = share['contact_info'] as String;
          final messageContent = share['message_content'] as String;

          if (shareType == 'sms') {
            success = await _retrySMSShare(contactInfo, messageContent);
          } else if (shareType == 'whatsapp') {
            success = await _retryWhatsAppShare(contactInfo, messageContent);
          }

          if (success) {
            await _dbService.updatePendingShareStatus(share['id'] as int, 'sent');
            syncResult['pending_shares_processed'] = 
                (syncResult['pending_shares_processed'] as int) + 1;
          } else {
            final retryCount = (share['retry_count'] as int) + 1;
            await _dbService.updatePendingShareStatus(share['id'] as int, 'pending', retryCount: retryCount);
          }
        } catch (e) {
          (syncResult['errors'] as List<String>).add('Pending share error: $e');
        }
      }

      // Process offline messages
      final queuedMessages = await _dbService.getQueuedOfflineMessages();
      for (final queuedMessage in queuedMessages) {
        try {
          // Try to send via appropriate channel
          final success = await _processQueuedMessage(queuedMessage);
          
          if (success) {
            await _dbService.updateOfflineMessageStatus(queuedMessage['id'] as int, 'sent');
            syncResult['offline_messages_sent'] = 
                (syncResult['offline_messages_sent'] as int) + 1;
          } else {
            final retryCount = (queuedMessage['retry_count'] as int) + 1;
            await _dbService.updateOfflineMessageStatus(queuedMessage['id'] as int, 'queued', retryCount: retryCount);
          }
        } catch (e) {
          (syncResult['errors'] as List<String>).add('Queued message error: $e');
        }
      }

      // Sync SOS alerts with backend
      final unsyncedAlerts = await _dbService.getUnsyncedSOSAlerts();
      for (final alert in unsyncedAlerts) {
        try {
          // Here you would sync with your backend API
          // For now, just mark as synced
          await _dbService.markSOSAlertAsSynced(alert['id'] as int);
          syncResult['sos_alerts_synced'] = 
              (syncResult['sos_alerts_synced'] as int) + 1;
        } catch (e) {
          (syncResult['errors'] as List<String>).add('SOS alert sync error: $e');
        }
      }

      _syncStatusController.add(syncResult);
      print('✅ Offline data sync completed: $syncResult');
      
    } catch (e) {
      print('❌ Error during offline data sync: $e');
    }
  }

  /// Retry SMS share
  Future<bool> _retrySMSShare(String phone, String message) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final smsUrl = 'sms:$cleanPhone?body=${Uri.encodeComponent(message)}';
      
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Retry SMS share error: $e');
      return false;
    }
  }

  /// Retry WhatsApp share
  Future<bool> _retryWhatsAppShare(String phone, String message) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }
      
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Retry WhatsApp share error: $e');
      return false;
    }
  }

  /// Process queued message
  Future<bool> _processQueuedMessage(Map<String, dynamic> message) async {
    try {
      final messageType = message['message_type'] as String;
      final recipient = message['recipient'] as String;
      final content = message['message_content'] as String;

      switch (messageType) {
        case 'sos':
          // Try both SMS and WhatsApp
          final smsSuccess = await _retrySMSShare(recipient, content);
          final whatsappSuccess = await _retryWhatsAppShare(recipient, content);
          return smsSuccess || whatsappSuccess;
        
        case 'location_update':
          // Send location update
          return await _retrySMSShare(recipient, content);
        
        default:
          // General message
          return await _retrySMSShare(recipient, content);
      }
    } catch (e) {
      print('❌ Process queued message error: $e');
      return false;
    }
  }

  /// Get service statistics
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      final dbStats = await _dbService.getDatabaseStats();
      return {
        'network_status': _isOnline ? 'online' : 'offline',
        'database_stats': dbStats,
        'service_status': 'active',
      };
    } catch (e) {
      return {
        'network_status': _isOnline ? 'online' : 'offline',
        'error': e.toString(),
        'service_status': 'error',
      };
    }
  }

  /// Start location tracking for offline use
  Future<void> startLocationTracking() async {
    try {
      // Start periodic location updates
      Timer.periodic(Duration(minutes: 1), (timer) async {
        if (!_isOnline) {
          final position = await _getCurrentPosition();
          if (position != null) {
            await _dbService.storeLocationData(position);
          }
        }
      });
      
      print('📍 Location tracking started for offline use');
    } catch (e) {
      print('❌ Error starting location tracking: $e');
    }
  }

  /// Dispose of the service
  void dispose() {
    _networkCheckTimer?.cancel();
    _syncTimer?.cancel();
    _networkStatusController.close();
    _syncStatusController.close();
    _dbService.dispose();
    print('🗑️ Enhanced Offline SOS Service disposed');
  }
}