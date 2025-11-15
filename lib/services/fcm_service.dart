import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'navigation_service.dart';
import 'notification_service.dart';
import 'socket_service.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import '../config/api_config.dart';
import 'auth_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, initialize Firebase.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  print('FCM Background message received: ${message.messageId}');
  try {
    // Ensure local notifications are initialized in this background isolate
    await NotificationService.initializeInBackground();

    final alert = _buildAlertFromRemoteMessage(message);
    if (alert != null) {
      await NotificationService.showEmergencyNotification(alert);
    }
  } catch (e) {
    print('Failed to show local notification in background: $e');
  }
}

/// Convert a RemoteMessage into the alert map used by NotificationService and NavigationService
Map<String, dynamic>? _buildAlertFromRemoteMessage(RemoteMessage message) {
  try {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

    // If the message has notification fields, prefer them for title/body
    final title = message.notification?.title ?? data['title'] ?? data['userName'] ?? 'SOS';
    final body = message.notification?.body ?? data['body'] ?? data['message'] ?? '';

    // Normalize latitude/longitude to doubles when possible
    double? latitude;
    double? longitude;
    if (data.containsKey('latitude')) {
      latitude = double.tryParse(data['latitude'].toString());
    }
    if (data.containsKey('longitude')) {
      longitude = double.tryParse(data['longitude'].toString());
    }

    final alert = <String, dynamic>{
      'title': title,
      'message': body,
      'userName': data['userName'] ?? data['senderName'] ?? data['userId'] ?? title,
      'alertId': data['alertId'] ?? '',
      'latitude': latitude,
      'longitude': longitude,
    };

    return alert;
  } catch (e) {
    print('Error building alert from RemoteMessage: $e');
    return null;
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SocketIOService _socket = SocketIOService();

  Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions on iOS / Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('FCM permission status: ${settings.authorizationStatus}');

    // Get token
    final token = await _fcm.getToken();
    print('FCM token: $token');
    // Upload token to backend (if authenticated)
    if (token != null) {
      await _uploadTokenToBackend(token);
    }

    // Listen for token refreshes and re-upload
    _fcm.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _uploadTokenToBackend(newToken);
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('FCM foreground message: ${message.messageId}');
      // Show notification via flutter_local_notifications
      try {
        final alert = _buildAlertFromRemoteMessage(message);
        if (alert != null) await NotificationService.showEmergencyNotification(alert);
      } catch (e) {
        print('Error showing local notification from FCM foreground: $e');
      }

      // If app is foreground show in-app popup for SOS data payloads
      try {
        final alert = _buildAlertFromRemoteMessage(message);
        if (alert != null) NavigationService.showEmergencyDialog(alert);
      } catch (e) {
        print('Error showing emergency dialog from FCM foreground: $e');
      }
    });

    // When user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('FCM message opened app: ${message.messageId}');
      try {
        final alert = _buildAlertFromRemoteMessage(message);
        if (alert != null) NavigationService.showEmergencyDialog(alert);
      } catch (e) {
        print('Error handling notification tap: $e');
      }
    });

    // Handle case where app was launched from a terminated state via a notification
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('FCM initial message (app opened from terminated): ${initialMessage.messageId}');
        final alert = _buildAlertFromRemoteMessage(initialMessage);
        if (alert != null) NavigationService.showEmergencyDialog(alert);
      }
    } catch (e) {
      print('Error checking initial FCM message: $e');
    }
  }

  Future<void> _uploadTokenToBackend(String token) async {
    try {
      final authToken = await AuthService.getAuthToken();
      final uri = Uri.parse('${ApiConfig.currentBaseUrl}/user/device-token');

      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final body = {
        'token': token,
        'platform': Platform.operatingSystem,
      };

      final response = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ FCM token uploaded to backend');
      } else {
        print('⚠️ Failed to upload FCM token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Error uploading FCM token to backend: $e');
    }
  }

  // Send SOS via existing Socket.IO service (backend should broadcast to recipients and/or send FCM)
  void sendSOS({required String alertType, String? message, Map<String, dynamic>? additionalData}) {
    _socket.sendEmergencyAlert(alertType: alertType, message: message, additionalData: additionalData);
  }

  // Listen to SOS via Socket.IO stream; the SocketIOService already handles incoming alerts and will call NotificationService and NavigationService
  Stream<List<Map<String, dynamic>>> get sosStream => _socket.nearbyUsersStream;
}
