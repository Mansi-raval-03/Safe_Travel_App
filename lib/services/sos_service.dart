import 'package:flutter/material.dart';
import 'fcm_service.dart';
import 'socket_service.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();
  factory SOSService() => _instance;
  SOSService._internal();

  final FCMService _fcm = FCMService();
  final SocketIOService _socket = SocketIOService();

  /// Send an SOS alert. This uses Socket.IO to notify nearby users via the backend.
  void sendSOS({required String message, required String alertType}) {
    final data = {
      'alertType': alertType,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Emit through socket - backend should broadcast and/or trigger FCM to recipients
    _socket.sendEmergencyAlert(alertType: alertType, message: message, additionalData: data);
  }

  /// Listen to incoming SOS alerts via existing SocketIO nearbyUsers stream
  Stream<List<Map<String, dynamic>>> listenToSOS() => _socket.nearbyUsersStream;
}
