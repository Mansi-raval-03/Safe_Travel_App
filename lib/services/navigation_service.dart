import 'package:flutter/material.dart';
import '../screens/alert_map_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Show an emergency dialog on top of the current UI using the global navigator.
  /// Expects an `alert` map containing at least `userName`, `message`, `latitude`, `longitude`.
  static Future<void> showEmergencyDialog(Map<String, dynamic> alert) async {
    final ctx = navigatorKey.currentState?.context;
    if (ctx == null) return;

    final userName = alert['userName'] ?? alert['senderName'] ?? 'Unknown';
    final message = alert['message'] ?? '';
    final lat = alert['latitude'];
    final lng = alert['longitude'];

    // Avoid showing multiple dialogs if modal is already up
    if (ModalRoute.of(ctx)?.isCurrent != true && navigatorKey.currentState?.overlay == null) {
      // still try to show, but guard to avoid throwing
    }

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('SOS from $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isNotEmpty) Text(message),
              const SizedBox(height: 12),
              if (lat != null && lng != null)
                Text('Location: ${lat.toString()}, ${lng.toString()}'),
            ],
          ),
          actions: [
            if (lat != null && lng != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  navigatorKey.currentState?.push(MaterialPageRoute(
                    builder: (_) => AlertMapScreen(latitude: lat, longitude: lng, senderName: userName),
                  ));
                },
                child: const Text('View Live Location'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }
}
