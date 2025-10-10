import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/user.dart';
import 'location_service.dart';
import 'auth_service.dart';

/// Service for sending SOS alerts offline using a local Node.js server
/// Works without internet, only requires local WiFi or hotspot connection
class OfflineSOSService {
  static final OfflineSOSService _instance = OfflineSOSService._internal();
  factory OfflineSOSService() => _instance;
  OfflineSOSService._internal();

  IO.Socket? _socket;
  String? _serverUrl;
  bool _isConnected = false;
  bool _isConnecting = false;
  List<String> _discoveredServers = [];
  Timer? _discoveryTimer;
  Timer? _heartbeatTimer;

  // Stream controllers for UI updates
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<List<String>> _serversController = StreamController<List<String>>.broadcast();
  final StreamController<Map<String, dynamic>> _alertController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get connectionStatusStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<String>> get discoveredServersStream => _serversController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  // Getters for current state
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  List<String> get discoveredServers => List.unmodifiable(_discoveredServers);
  String? get connectedServer => _serverUrl;

  /// Start discovering local SOS servers on the network
  Future<void> startServerDiscovery() async {
    try {
      _updateStatus('Scanning for local SOS servers...');
      _discoveredServers.clear();
      _serversController.add(_discoveredServers);

      // Common ports for local SOS servers
      List<int> commonPorts = [3000, 3001, 8080, 8081, 9000, 9001];
      
      // Get local network IP range
      String? localIP = await _getLocalIP();
      if (localIP == null) {
        _updateStatus('Cannot determine local network');
        return;
      }

      String networkBase = localIP.substring(0, localIP.lastIndexOf('.'));
      _updateStatus('Scanning network: $networkBase.x');

      // Scan common IPs and ports
      List<Future> scanFutures = [];
      
      for (int i = 1; i <= 254; i++) {
        String ip = '$networkBase.$i';
        if (ip == localIP) continue; // Skip own IP
        
        for (int port in commonPorts) {
          scanFutures.add(_checkServer(ip, port));
        }
      }

      // Wait for all scans to complete with timeout
      await Future.wait(scanFutures).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Server discovery timeout reached');
          return [];
        },
      );

      if (_discoveredServers.isEmpty) {
        _updateStatus('No SOS servers found. Start a server on your network.');
      } else {
        _updateStatus('Found ${_discoveredServers.length} SOS server(s)');
        _serversController.add(_discoveredServers);
      }

    } catch (e) {
      _updateStatus('Discovery failed: ${e.toString()}');
      debugPrint('Server discovery error: $e');
    }
  }

  /// Check if a server exists at the given IP and port
  Future<void> _checkServer(String ip, int port) async {
    try {
      Socket socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      await socket.close();
      
      // Test if it's a Socket.IO server by making a quick HTTP request
      String serverUrl = 'http://$ip:$port';
      if (await _isSocketIOServer(serverUrl)) {
        _discoveredServers.add(serverUrl);
        debugPrint('Found SOS server: $serverUrl');
      }
    } catch (e) {
      // Server not found or not responding - this is expected
    }
  }

  /// Check if the server supports Socket.IO
  Future<bool> _isSocketIOServer(String serverUrl) async {
    try {
      HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      HttpClientRequest request = await client.getUrl(Uri.parse('$serverUrl/socket.io/'));
      HttpClientResponse response = await request.close();
      
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get the local IP address
  Future<String?> _getLocalIP() async {
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      
      for (NetworkInterface interface in interfaces) {
        // Look for WiFi or Ethernet interfaces
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('eth') ||
            interface.name.toLowerCase().contains('wi-fi')) {
          
          for (InternetAddress addr in interface.addresses) {
            String ip = addr.address;
            // Check if it's a private IP (local network)
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              return ip;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return null;
    }
  }

  /// Connect to the first discovered server automatically
  Future<bool> connectToServer() async {
    if (_discoveredServers.isEmpty) {
      await startServerDiscovery();
    }
    
    if (_discoveredServers.isEmpty) {
      _updateStatus('No SOS servers found on network');
      return false;
    }
    
    return await connectToSpecificServer(_discoveredServers.first);
  }

  /// Connect to a specific SOS server
  Future<bool> connectToSpecificServer(String serverUrl) async {
    if (_isConnecting) {
      _updateStatus('Already connecting...');
      return false;
    }

    try {
      _isConnecting = true;
      _updateStatus('Connecting to server...');
      
      await disconnectFromServer(); // Disconnect any existing connection

      _socket = IO.io(serverUrl, IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(3)
          .setReconnectionDelay(1000)
          .setTimeout(5000)
          .build());

      Completer<bool> completer = Completer<bool>();

      _socket!.onConnect((_) {
        debugPrint('Connected to SOS server: $serverUrl');
        _isConnected = true;
        _serverUrl = serverUrl;
        _connectionController.add(true);
        _updateStatus('Connected to SOS server');
        _startHeartbeat();
        
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('Disconnected from SOS server');
        _isConnected = false;
        _serverUrl = null;
        _connectionController.add(false);
        _updateStatus('Disconnected from server');
        _stopHeartbeat();
      });

      _socket!.onConnectError((error) {
        debugPrint('Connection error: $error');
        _updateStatus('Connection failed: $error');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _socket!.onError((error) {
        debugPrint('Socket error: $error');
        _updateStatus('Server error: $error');
      });

      // Listen for incoming SOS alerts from other clients
      _socket!.on('sos_alert_broadcast', (data) {
        debugPrint('Received SOS alert from server: $data');
        _alertController.add(Map<String, dynamic>.from(data));
      });

      // Listen for server responses
      _socket!.on('sos_response', (data) {
        debugPrint('SOS response from server: $data');
        _updateStatus(data['message'] ?? 'SOS alert processed');
      });

      // Wait for connection with timeout
      bool connected = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _updateStatus('Connection timeout');
          return false;
        },
      );

      return connected;

    } catch (e) {
      _updateStatus('Connection error: ${e.toString()}');
      debugPrint('Connection error: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnect from the current server
  Future<void> disconnectFromServer() async {
    try {
      _stopHeartbeat();
      
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
      
      _isConnected = false;
      _serverUrl = null;
      _connectionController.add(false);
      _updateStatus('Disconnected');
      
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  /// Send an SOS alert through the local server
  Future<bool> sendSOSAlert({
    required String alertType,
    String? customMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isConnected || _socket == null) {
      _updateStatus('Not connected to any server');
      return false;
    }

    try {
      _updateStatus('Sending SOS alert...');
      
      // Get current location
      Position? position;
      try {
        position = await LocationService().getCurrentLocation();
      } catch (e) {
        debugPrint('Could not get location for SOS: $e');
      }

      // Get current user data
      User? user = await AuthService.getCurrentUser();

      // Prepare SOS alert data
      Map<String, dynamic> sosData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'alertType': alertType,
        'message': customMessage ?? 'Emergency SOS Alert',
        'user': {
          'name': user?.name ?? 'Unknown User',
          'phone': user?.phone ?? 'No phone provided',
          'email': user?.email ?? 'No email provided',
        },
        'location': position != null ? {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': position.timestamp.toIso8601String(),
        } : null,
        'device': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
        'additionalData': additionalData ?? {},
      };

      Completer<bool> completer = Completer<bool>();

      // Send SOS alert with acknowledgment
      _socket!.emitWithAck('sos_alert', sosData, ack: (data) {
        if (data != null && data['success'] == true) {
          _updateStatus('SOS alert sent successfully');
          completer.complete(true);
        } else {
          String errorMsg = data?['message'] ?? 'Unknown server error';
          _updateStatus('SOS failed: $errorMsg');
          completer.complete(false);
        }
      });

      // Wait for server acknowledgment with timeout
      bool success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _updateStatus('SOS alert timeout - server not responding');
          return false;
        },
      );

      return success;

    } catch (e) {
      _updateStatus('SOS alert failed: ${e.toString()}');
      debugPrint('SOS alert error: $e');
      return false;
    }
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _socket != null) {
        _socket!.emit('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Update status and notify listeners
  void _updateStatus(String status) {
    debugPrint('OfflineSOSService: $status');
    _statusController.add(status);
  }

  /// Get all stored SOS alerts from server
  Future<List<Map<String, dynamic>>> getStoredAlerts() async {
    if (!_isConnected || _socket == null) {
      return [];
    }

    try {
      Completer<List<Map<String, dynamic>>> completer = Completer();

      _socket!.emitWithAck('get_alerts', {}, ack: (data) {
        if (data != null && data['success'] == true) {
          List<Map<String, dynamic>> alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);
          completer.complete(alerts);
        } else {
          completer.complete([]);
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

    } catch (e) {
      debugPrint('Error getting stored alerts: $e');
      return [];
    }
  }

  /// Clean up resources
  void dispose() {
    _discoveryTimer?.cancel();
    disconnectFromServer();
    _connectionController.close();
    _statusController.close();
    _serversController.close();
    _alertController.close();
  }
}