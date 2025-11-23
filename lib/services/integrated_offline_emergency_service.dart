import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_database_service.dart';
import 'location_service.dart';
import 'auth_service.dart';
import 'sms_service.dart';

/// Integrated Offline Emergency Contact & SOS Service
/// Handles offline storage of emergency contacts and offline SOS alerts with live location sharing
class IntegratedOfflineEmergencyService {
  static IntegratedOfflineEmergencyService? _instance;
  static IntegratedOfflineEmergencyService get instance {
    _instance ??= IntegratedOfflineEmergencyService._();
    return _instance!;
  }
  IntegratedOfflineEmergencyService._();

  late final OfflineDatabaseService _dbService;
  late final LocationService _locationService;
  bool _initialized = false;
  Completer<void>? _initializingCompleter;
  
  // Stream controllers for real-time updates
  final _contactsController = StreamController<List<OfflineEmergencyContact>>.broadcast();
  final _sosAlertsController = StreamController<List<OfflineSOSAlert>>.broadcast();
  final _locationController = StreamController<Position>.broadcast();
  final _networkController = StreamController<bool>.broadcast();
  
  // Connectivity monitoring
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _locationTimer;
  Timer? _syncTimer;
  
  // Getters for streams
  Stream<List<OfflineEmergencyContact>> get contactsStream => _contactsController.stream;
  Stream<List<OfflineSOSAlert>> get sosAlertsStream => _sosAlertsController.stream;
  Stream<Position> get locationStream => _locationController.stream;
  Stream<bool> get networkStream => _networkController.stream;
  
  // Getters for current state
  bool get isOnline => _isOnline;
  
  /// Initialize the service
  Future<void> initialize() async {
    // Fast path: already initialized
    if (_initialized) return;

    // If another caller is currently initializing, wait for it
    if (_initializingCompleter != null) {
      await _initializingCompleter!.future;
      return;
    }

    _initializingCompleter = Completer<void>();

    try {
      print('🚀 Initializing Integrated Offline Emergency Service...');

      // Initialize database service
      _dbService = OfflineDatabaseService.instance;
      await _dbService.database;

      // Initialize location service
      _locationService = LocationService();

      // Start connectivity monitoring
      await _startConnectivityMonitoring();

      // Start periodic sync when online
      _startPeriodicSync();
      _initialized = true;

      _initializingCompleter!.complete();
      print('✅ Integrated Offline Emergency Service initialized successfully');
    } catch (e) {
      _initializingCompleter!.completeError(e);
      print('❌ Error initializing service: $e');
      rethrow;
    } finally {
      // Clear the completer so future attempts can initialize again if needed
      _initializingCompleter = null;
    }
  }
  
  /// Start monitoring network connectivity
  Future<void> _startConnectivityMonitoring() async {
    try {
      // Check initial connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      _isOnline = !connectivityResults.contains(ConnectivityResult.none);
      _networkController.add(_isOnline);
      
      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        final wasOnline = _isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);
        _networkController.add(_isOnline);
        
        print('🌐 Network status changed: ${_isOnline ? "Online" : "Offline"}');
        
        // If we just came back online, sync data
        if (!wasOnline && _isOnline) {
          _syncPendingData();
        }
      });
    } catch (e) {
      print('❌ Error setting up connectivity monitoring: $e');
      _isOnline = false;
      _networkController.add(false);
    }
  }
  
  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        _syncPendingData();
      }
    });
  }
  
  // ==================== EMERGENCY CONTACTS ====================
  
  /// Add emergency contact offline
  Future<int> addEmergencyContact(OfflineEmergencyContact contact) async {
    try {
      final db = await _dbService.database;
      
      final contactId = await db.insert(
        OfflineDatabaseService.tableEmergencyContacts,
        contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ Emergency contact added offline: ${contact.name} (ID: $contactId)');
      
      // Update UI
      _loadAndBroadcastContacts();
      
      // Try to sync online if connected
      if (_isOnline) {
        _syncContactToServer(contactId);
      }
      
      return contactId;
    } catch (e) {
      print('❌ Error adding emergency contact: $e');
      rethrow;
    }
  }
  
  /// Get all emergency contacts from offline storage
  Future<List<OfflineEmergencyContact>> getAllEmergencyContacts() async {
    try {
      final db = await _dbService.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        OfflineDatabaseService.tableEmergencyContacts,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'is_primary DESC, name ASC',
      );
      
      return maps.map((map) => OfflineEmergencyContact.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting emergency contacts: $e');
      return [];
    }
  }
  
  /// Update emergency contact
  Future<void> updateEmergencyContact(OfflineEmergencyContact contact) async {
    try {
      final db = await _dbService.database;
      
      await db.update(
        OfflineDatabaseService.tableEmergencyContacts,
        {
          ...contact.toMap(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contact.id],
      );
      
      print('✅ Emergency contact updated: ${contact.name}');
      
      // Update UI
      _loadAndBroadcastContacts();
      
      // Try to sync online if connected
      if (_isOnline && contact.id != null) {
        _syncContactToServer(contact.id!);
      }
    } catch (e) {
      print('❌ Error updating emergency contact: $e');
      rethrow;
    }
  }
  
  /// Delete emergency contact
  Future<void> deleteEmergencyContact(int contactId) async {
    try {
      final db = await _dbService.database;
      
      // Soft delete
      await db.update(
        OfflineDatabaseService.tableEmergencyContacts,
        {
          'is_active': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [contactId],
      );
      
      print('✅ Emergency contact deleted (soft): ID $contactId');
      
      // Update UI
      _loadAndBroadcastContacts();
    } catch (e) {
      print('❌ Error deleting emergency contact: $e');
      rethrow;
    }
  }
  
  /// Load and broadcast contacts to UI
  Future<void> _loadAndBroadcastContacts() async {
    final contacts = await getAllEmergencyContacts();
    _contactsController.add(contacts);
  }
  
  // ==================== SOS ALERTS & LIVE LOCATION ====================
  
  /// Send SOS alert with live location sharing (offline)
  Future<int> sendSOSAlertOffline({
    required String emergencyType,
    String? message,
    bool enableLiveLocationSharing = true,
    Duration liveLocationDuration = const Duration(hours: 2),
  }) async {
    try {
      print('🚨 Sending SOS alert offline...');
      
      // Get current location
      Position? position;
      try {
        position = await _locationService.getCurrentLocation();
        print('📍 Location acquired: ${position?.latitude}, ${position?.longitude}');
      } catch (e) {
        print('❌ Could not get location: $e');
        // Continue without location for critical alerts
      }
      
      // Create SOS alert record
      final sosAlert = OfflineSOSAlert(
        emergencyType: emergencyType,
        message: message ?? 'Emergency SOS Alert',
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        accuracy: position?.accuracy ?? 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        userId: await _getCurrentUserId(),
      );
      
      // Store SOS alert in database
      final db = await _dbService.database;
      final sosId = await db.insert(
        OfflineDatabaseService.tableSOSAlerts,
        sosAlert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ SOS alert stored offline with ID: $sosId');
      
      // Get emergency contacts
      final contacts = await getAllEmergencyContacts();
      
      if (contacts.isEmpty) {
        print('⚠️ No emergency contacts found for SOS alert');
      } else {
        // Create pending shares for each contact
        await _createPendingShares(sosId, contacts, sosAlert);
        
        // Start live location sharing if enabled
        if (enableLiveLocationSharing && position != null) {
          _startLiveLocationSharing(sosId, contacts, liveLocationDuration);
        }
        
        // Try immediate sharing if online
        if (_isOnline) {
          _processPendingShares();
        }
      }
      
      // Update UI
      _loadAndBroadcastSOSAlerts();
      
      return sosId;
    } catch (e) {
      print('❌ Error sending SOS alert offline: $e');
      rethrow;
    }
  }
  
  /// Create pending shares for SOS alert
  Future<void> _createPendingShares(int sosId, List<OfflineEmergencyContact> contacts, OfflineSOSAlert sosAlert) async {
    try {
      final db = await _dbService.database;
      final batch = db.batch();
      
      for (final contact in contacts) {
        // Create location sharing message
        final locationText = sosAlert.latitude != 0.0 && sosAlert.longitude != 0.0
            ? 'Location: https://maps.google.com/?q=${sosAlert.latitude},${sosAlert.longitude}'
            : 'Location: Not available';
            
        final messageContent = '''
🚨 EMERGENCY SOS ALERT 🚨
From: ${await _getCurrentUserName()}
Type: ${sosAlert.emergencyType.toUpperCase()}
Message: ${sosAlert.message}
Time: ${DateTime.fromMillisecondsSinceEpoch(sosAlert.timestamp)}

$locationText

This is an automated emergency message. Please respond immediately.
''';
        
        // SMS share
        if (contact.phone.isNotEmpty) {
          batch.insert(OfflineDatabaseService.tablePendingShares, {
            'sos_alert_id': sosId,
            'contact_id': contact.id,
            'share_type': 'sms',
            'message_content': messageContent,
            'contact_info': contact.phone,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        // WhatsApp share
        if (contact.phone.isNotEmpty) {
          batch.insert(OfflineDatabaseService.tablePendingShares, {
            'sos_alert_id': sosId,
            'contact_id': contact.id,
            'share_type': 'whatsapp',
            'message_content': messageContent,
            'contact_info': contact.phone,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        // Email share
        if (contact.email?.isNotEmpty == true) {
          batch.insert(OfflineDatabaseService.tablePendingShares, {
            'sos_alert_id': sosId,
            'contact_id': contact.id,
            'share_type': 'email',
            'message_content': messageContent,
            'contact_info': contact.email,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      
      await batch.commit();
      print('✅ Created ${contacts.length * 2} pending shares for SOS alert');
    } catch (e) {
      print('❌ Error creating pending shares: $e');
      rethrow;
    }
  }
  
  /// Start live location sharing
  void _startLiveLocationSharing(int sosId, List<OfflineEmergencyContact> contacts, Duration duration) {
    print('📍 Starting live location sharing for ${duration.inHours} hours...');
    
    // Cancel any existing timer
    _locationTimer?.cancel();
    
    int updateCount = 0;
    final maxUpdates = (duration.inMinutes / 2).ceil(); // Update every 2 minutes
    
    _locationTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      updateCount++;
      
      try {
        final position = await _locationService.getCurrentLocation();
        
        if (position != null) {
          // Store location update
          await _storeLocationUpdate(sosId, position);
          
          // Create location update message
          final locationMessage = '''
📍 LIVE LOCATION UPDATE #$updateCount
Time: ${DateTime.now()}
Location: https://maps.google.com/?q=${position.latitude},${position.longitude}
Accuracy: ±${position.accuracy.round()}m
Speed: ${position.speed.toStringAsFixed(1)} m/s

SOS Alert ID: $sosId
''';
          
          // Queue location updates for sharing
          await _queueLocationUpdates(contacts, locationMessage);
          
          // Try immediate sharing if online
          if (_isOnline) {
            _processPendingShares();
          }
          
          // Update UI with new location
          _locationController.add(position);
        } else {
          print('⚠️ Could not get location for live update #$updateCount');
        }
        
      } catch (e) {
        print('❌ Error in live location update: $e');
      }
      
      // Stop after duration
      if (updateCount >= maxUpdates) {
        timer.cancel();
        print('✅ Live location sharing completed');
      }
    });
  }
  
  /// Store location update in database
  Future<void> _storeLocationUpdate(int sosId, Position position) async {
    try {
      final db = await _dbService.database;
      
      await db.insert(OfflineDatabaseService.tableLocations, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error storing location update: $e');
    }
  }
  
  /// Queue location updates for sharing
  Future<void> _queueLocationUpdates(List<OfflineEmergencyContact> contacts, String message) async {
    try {
      final db = await _dbService.database;
      final batch = db.batch();
      
      for (final contact in contacts) {
        // SMS location update
        if (contact.phone.isNotEmpty) {
          batch.insert(OfflineDatabaseService.tableOfflineMessages, {
            'message_type': 'location_update',
            'recipient': contact.phone,
            'message_content': message,
            'metadata': json.encode({
              'contact_id': contact.id,
              'share_type': 'sms',
            }),
            'priority': 3, // High priority
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      
      await batch.commit();
    } catch (e) {
      print('❌ Error queueing location updates: $e');
    }
  }
  
  /// Process pending shares (when online)
  Future<void> _processPendingShares() async {
    if (!_isOnline) return;
    
    try {
      final db = await _dbService.database;
      
      // Get pending shares
      final pendingShares = await db.query(
        OfflineDatabaseService.tablePendingShares,
        where: 'status = ? AND retry_count < max_retries',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
      
      for (final share in pendingShares) {
        await _executeShare(share);
      }
      
      // Get pending messages
      final pendingMessages = await db.query(
        OfflineDatabaseService.tableOfflineMessages,
        where: 'retry_count < max_retries',
        orderBy: 'priority DESC, created_at ASC',
        limit: 10, // Process in batches
      );
      
      for (final message in pendingMessages) {
        await _executeMessage(message);
      }
      
    } catch (e) {
      print('❌ Error processing pending shares: $e');
    }
  }
  
  /// Execute a pending share
  Future<void> _executeShare(Map<String, dynamic> share) async {
    try {
      final shareType = share['share_type'] as String;
      final contactInfo = share['contact_info'] as String;
      final messageContent = share['message_content'] as String;
      
      bool success = false;
      
      switch (shareType) {
        case 'sms':
          success = await _sendSMS(contactInfo, messageContent);
          break;
        case 'whatsapp':
          success = await _sendWhatsApp(contactInfo, messageContent);
          break;
        case 'email':
          success = await _sendEmail(contactInfo, 'Emergency SOS Alert', messageContent);
          break;
      }
      
      // Update share status
      final db = await _dbService.database;
      await db.update(
        OfflineDatabaseService.tablePendingShares,
        {
          'status': success ? 'sent' : 'failed',
          'retry_count': (share['retry_count'] as int) + 1,
          'last_attempt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [share['id']],
      );
      
    } catch (e) {
      print('❌ Error executing share: $e');
    }
  }
  
  /// Execute a pending message
  Future<void> _executeMessage(Map<String, dynamic> message) async {
    try {
      final messageType = message['message_type'] as String;
      final recipient = message['recipient'] as String;
      final content = message['message_content'] as String;
      
      bool success = false;
      
      // For now, treat all as SMS (can be extended for other types)
      if (messageType == 'location_update') {
        success = await _sendSMS(recipient, content);
      }
      
      // Update message status
      final db = await _dbService.database;
      if (success) {
        await db.delete(
          OfflineDatabaseService.tableOfflineMessages,
          where: 'id = ?',
          whereArgs: [message['id']],
        );
      } else {
        await db.update(
          OfflineDatabaseService.tableOfflineMessages,
          {
            'retry_count': (message['retry_count'] as int) + 1,
          },
          where: 'id = ?',
          whereArgs: [message['id']],
        );
      }
      
    } catch (e) {
      print('❌ Error executing message: $e');
    }
  }
  
  // ==================== SHARING METHODS ====================
  
  /// Send SMS
  Future<bool> _sendSMS(String phoneNumber, String message) async {
    try {
      // Request and ensure SMS permission, then send directly via SmsService.
      final permsOk = await SmsService.ensurePermissions();
      if (!permsOk) {
        print('⚠️ SMS permission not granted - automatic send not possible');
        return false;
      }

      final sent = await SmsService.sendSingleSms(phone: phoneNumber, message: message);
      if (sent) {
        print('📱 SMS automatically sent to $phoneNumber');
        return true;
      }

      print('❌ SmsService reported failure sending to $phoneNumber');
      return false;
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }
  
  /// Send WhatsApp message
  Future<bool> _sendWhatsApp(String phoneNumber, String message) async {
    try {
      // Remove any formatting from phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error sending WhatsApp: $e');
      return false;
    }
  }
  
  /// Send Email
  Future<bool> _sendEmail(String email, String subject, String body) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }
  
  // ==================== SYNC METHODS ====================
  
  /// Sync pending data when coming back online
  Future<void> _syncPendingData() async {
    try {
      print('🔄 Syncing pending data...');
      
      // Process pending shares and messages
      await _processPendingShares();
      
      // Sync contacts to server
      await _syncContactsToServer();
      
      // Sync SOS alerts to server
      await _syncSOSAlertsToServer();
      
      print('✅ Pending data sync completed');
    } catch (e) {
      print('❌ Error syncing pending data: $e');
    }
  }
  
  /// Sync contact to server
  Future<void> _syncContactToServer(int contactId) async {
    // TODO: Implement server sync when you have backend API
    print('📤 Contact $contactId queued for server sync');
  }
  
  /// Sync all contacts to server
  Future<void> _syncContactsToServer() async {
    // TODO: Implement server sync when you have backend API
    print('📤 All contacts queued for server sync');
  }
  
  /// Sync SOS alerts to server
  Future<void> _syncSOSAlertsToServer() async {
    // TODO: Implement server sync when you have backend API
    print('📤 SOS alerts queued for server sync');
  }
  
  // ==================== UTILITY METHODS ====================
  
  /// Get all SOS alerts
  Future<List<OfflineSOSAlert>> getAllSOSAlerts() async {
    try {
      final db = await _dbService.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        OfflineDatabaseService.tableSOSAlerts,
        orderBy: 'timestamp DESC',
      );
      
      return maps.map((map) => OfflineSOSAlert.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting SOS alerts: $e');
      return [];
    }
  }
  
  /// Load and broadcast SOS alerts
  Future<void> _loadAndBroadcastSOSAlerts() async {
    final alerts = await getAllSOSAlerts();
    _sosAlertsController.add(alerts);
  }
  
  /// Get current user ID
  Future<String> _getCurrentUserId() async {
    try {
      final user = await AuthService.getCurrentUser();
      return user?.id ?? 'offline_user';
    } catch (e) {
      return 'offline_user';
    }
  }
  
  /// Get current user name
  Future<String> _getCurrentUserName() async {
    try {
      final user = await AuthService.getCurrentUser();
      return user?.name ?? 'Emergency User';
    } catch (e) {
      return 'Emergency User';
    }
  }
  
  /// Dispose resources
  void dispose() {
    _locationTimer?.cancel();
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _contactsController.close();
    _sosAlertsController.close();
    _locationController.close();
    _networkController.close();
  }
}

// ==================== DATA MODELS ====================

/// Offline Emergency Contact Model
class OfflineEmergencyContact {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? relationship;
  final bool isPrimary;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  OfflineEmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.relationship,
    this.isPrimary = false,
    this.isActive = true,
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'is_primary': isPrimary ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory OfflineEmergencyContact.fromMap(Map<String, dynamic> map) {
    return OfflineEmergencyContact(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      relationship: map['relationship'],
      isPrimary: map['is_primary'] == 1,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  OfflineEmergencyContact copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? relationship,
    bool? isPrimary,
    bool? isActive,
  }) {
    return OfflineEmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Offline SOS Alert Model
class OfflineSOSAlert {
  final int? id;
  final String emergencyType;
  final String message;
  final double latitude;
  final double longitude;
  final double accuracy;
  final int timestamp;
  final String userId;
  final bool isSynced;
  final int createdAt;

  OfflineSOSAlert({
    this.id,
    required this.emergencyType,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.userId,
    this.isSynced = false,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'emergency_type': emergencyType,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp,
      'user_id': userId,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory OfflineSOSAlert.fromMap(Map<String, dynamic> map) {
    return OfflineSOSAlert(
      id: map['id'],
      emergencyType: map['emergency_type'],
      message: map['message'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      accuracy: map['accuracy'],
      timestamp: map['timestamp'],
      userId: map['user_id'],
      isSynced: map['is_synced'] == 1,
      createdAt: map['created_at'],
    );
  }
}