import 'dart:async';
import 'dart:convert';
import '../models/sos_alert.dart';
import 'socket_service.dart';
import 'api_service.dart';
import 'notification_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal() {
    // subscribe to socket emergency alerts
    _socket.emergencyAlertStream.listen((data) {
      final alert = SosAlert.fromJson(data);
      _addAlert(alert);
      // trigger local notification
      try {
        NotificationService.showEmergencyNotification(data);
      } catch (e) {
        // ignore
      }
    }, onError: (e) => print('AlertService: socket stream error: $e'));
  }

  final SocketIOService _socket = SocketIOService();

  // Internal list controller
  final StreamController<List<SosAlert>> _alertsController = StreamController<List<SosAlert>>.broadcast();
  final List<SosAlert> _alerts = [];

  Stream<List<SosAlert>> get alertsStream => _alertsController.stream;

  Future<void> fetchInitialAlerts() async {
    try {
      final resp = await ApiService.get('/sos/alerts');
      if (resp.statusCode == 200) {
        try {
          final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
          final parsed = data.map((e) => SosAlert.fromJson(e as Map<String, dynamic>)).toList();
          _alerts.clear();
          _alerts.addAll(parsed);
          _alertsController.add(List.unmodifiable(_alerts));
        } catch (e) {
          print('AlertService: parse error: $e');
        }
      } else {
        print('AlertService: failed to fetch alerts: ${resp.statusCode}');
      }
    } catch (e) {
      print('AlertService: fetchInitialAlerts error: $e');
    }
  }

  void _addAlert(SosAlert alert) {
    _alerts.insert(0, alert);
    _alertsController.add(List.unmodifiable(_alerts));
  }

  void dispose() {
    _alertsController.close();
  }
}
