import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'navigation_service.dart';
import '../screens/alert_map_screen.dart';

/// NotificationService: wraps `flutter_local_notifications` and exposes
/// helper methods for showing local notifications (SOS sent) and
/// displaying incoming emergency notifications from the backend (FCM).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // Android channel ids
  static const String _emergencyChannelId = 'emergency_alerts';
  static const String _emergencyChannelName = 'Emergency Alerts';

  /// Initialize the plugin and create channels. Call early in app startup.
  static Future<void> initialize() async {
    // Android initialization (use app launcher icon resource)
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS initialization — request permissions on init
    final DarwinInitializationSettings darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

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
            // Show same emergency dialog used for foreground messages
            NavigationService.showEmergencyDialog({
              'userName': payload['userName'] ?? payload['senderName'] ?? 'Unknown',
              'message': payload['message'] ?? '',
              'latitude': payload['latitude'],
              'longitude': payload['longitude'],
            });
          }
        } catch (e) {
          debugPrint('Notification response handling failed: $e');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _emergencyChannelId,
      _emergencyChannelName,
      description: 'High-priority emergency alerts (SOS)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Request Android notifications permission on Android 13+ via plugin
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (_) {}

    await androidImpl?.createNotificationChannel(channel);
  }

  /// Background-safe initialize used from FCM background handlers.
  /// This runs in a background isolate, so keep work minimal.
  @pragma('vm:entry-point')
  static Future<void> initializeInBackground() async {
    try {
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings settings = InitializationSettings(android: androidInit);
      await _plugin.initialize(settings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        description: 'High-priority emergency alerts (SOS)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      try {
        await androidImpl?.requestNotificationsPermission();
      } catch (_) {}
      await androidImpl?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('Background notification initialization failed: $e');
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Background tap handler — execution limited. Navigation will occur
    // when the app resumes and the foreground handler runs.
  }

  /// Show a simple local notification to confirm the user's SOS was sent.
  /// This should be called immediately after a successful SOS submission.
  static Future<void> showSosSentNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _emergencyChannelId,
        _emergencyChannelName,
        channelDescription: 'High-priority emergency alerts (SOS)',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'SOS Sent',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      await _plugin.show(
        0, // id 0 reserved for SOS-sent confirmation
        'SOS Sent',
        'Your emergency SOS has been sent successfully.',
        details,
        payload: jsonEncode({'type': 'sos_sent'}),
      );
    } catch (e) {
      debugPrint('Failed to show SOS Sent notification: $e');
    }
  }

  /// Show an incoming emergency notification (from FCM/backend).
  /// `alert` may contain keys: userName, message, latitude, longitude
  static Future<void> showEmergencyNotification(Map<String, dynamic> alert) async {
    try {
      final title = 'SOS from ${alert['userName'] ?? alert['senderName'] ?? 'Unknown'}';
      final body = (alert['message'] ?? '').toString();

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _emergencyChannelId,
        _emergencyChannelName,
        channelDescription: 'High-priority emergency alerts (SOS)',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Emergency Alert',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );

      final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      final payload = jsonEncode({
        'userName': alert['userName'] ?? alert['senderName'],
        'message': alert['message'] ?? '',
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
