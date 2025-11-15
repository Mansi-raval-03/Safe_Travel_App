import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'navigation_service.dart';
import '../screens/alert_map_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Initialize notification plugin and channels. Call early in app startup.
  static Future<void> initialize() async {
    // Request runtime notification permission on Android 13+ (POST_NOTIFICATIONS)
    try {
      await _requestNotificationPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }

    // Use the app launcher icon resource to avoid missing resource errors
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings darwinInit = DarwinInitializationSettings();

    final InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        try {
          if (response.payload != null && response.payload!.isNotEmpty) {
            final Map<String, dynamic> payload = jsonDecode(response.payload!);
            // Navigate to alert map when notification tapped
            NavigationService.navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => AlertMapScreen(
                latitude: (payload['latitude'] as num).toDouble(),
                longitude: (payload['longitude'] as num).toDouble(),
                senderName: payload['userName'] ?? payload['senderName'] ?? 'Unknown',
              ),
            ));
          }
        } catch (e) {
          debugPrint('Notification response handling failed: $e');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Android channel for emergency alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_alerts',
      'Emergency Alerts',
      description: 'High-priority emergency alerts (SOS)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Background-safe initialize used from FCM background handlers (runs in separate isolate)
  @pragma('vm:entry-point')
  static Future<void> initializeInBackground() async {
    try {
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings settings = InitializationSettings(android: androidInit);
      await _plugin.initialize(settings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'emergency_alerts',
        'Emergency Alerts',
        description: 'High-priority emergency alerts (SOS)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('Background notification initialization failed: $e');
    }
  }

  /// Request the platform notification permission (Android 13+: POST_NOTIFICATIONS)
  static Future<bool> _requestNotificationPermission() async {
    try {
      // On Android below 13, this permission is not required and will be handled by the system.
      final status = await Permission.notification.status;
      if (status.isGranted) return true;

      final result = await Permission.notification.request();
      if (result.isGranted) {
        debugPrint('Notification permission granted');
        return true;
      } else if (result.isPermanentlyDenied) {
        debugPrint('Notification permission permanently denied - user must enable in settings');
        return false;
      } else {
        debugPrint('Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // This runs in background isolate when notification action is tapped
    // We do not perform heavy work here; navigation will occur when app resumes.
    // Keep as a VM entry point per plugin docs.
  }

  /// Show an emergency notification. Payload should contain latitude & longitude.
  static Future<void> showEmergencyNotification(Map<String, dynamic> alert) async {
    try {
      final title = 'SOS from ${alert['userName'] ?? alert['senderName'] ?? 'Unknown'}';
      final body = (alert['message'] ?? '').toString();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'emergency_alerts',
        'Emergency Alerts',
        channelDescription: 'High-priority emergency alerts (SOS)',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Emergency Alert',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        ongoing: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      // Pass payload so tapping notification can navigate
      final payload = jsonEncode({
        'userName': alert['userName'] ?? alert['senderName'],
        'latitude': alert['latitude'],
        'longitude': alert['longitude'],
      });

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body.isNotEmpty ? body : null,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show emergency notification: $e');
    }
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();
}
