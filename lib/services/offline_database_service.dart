import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_contact_service.dart';

/// Offline Database Service for SOS and Location Management
/// Handles SQLite operations for offline SOS sharing, location tracking,
/// and emergency contact management when network is unavailable
class OfflineDatabaseService {
  static OfflineDatabaseService? _instance;
  static Database? _database;
  
  static OfflineDatabaseService get instance {
    _instance ??= OfflineDatabaseService._();
    return _instance!;
  }
  
  OfflineDatabaseService._();

  // Database configuration
  static const String _dbName = 'safe_travel_offline.db';
  static const int _dbVersion = 2; // Incremented for trip_events table

  // Table names
  static const String tableSOSAlerts = 'sos_alerts';
  static const String tableLocations = 'locations';
  static const String tableEmergencyContacts = 'emergency_contacts';
  static const String tablePendingShares = 'pending_shares';
  static const String tableOfflineMessages = 'offline_messages';
  static const String tableTripEvents = 'trip_events';

  /// Initialize database connection
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize SQLite database with tables
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);

      print('🗄️ Initializing offline database at: $path');

      return await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      print('❌ Database initialization error: $e');
      rethrow;
    }
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
    // Enable WAL mode for better concurrency
    await db.execute('PRAGMA journal_mode = WAL');
    print('🔧 Database configured with foreign keys and WAL mode');
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // SOS Alerts table
    batch.execute('''
      CREATE TABLE $tableSOSAlerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emergency_type TEXT NOT NULL,
        message TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        user_id TEXT
      )
    ''');

    // Locations table for tracking user movement
    batch.execute('''
      CREATE TABLE $tableLocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        heading REAL,
        speed REAL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Emergency contacts table (offline cache)
    batch.execute('''
      CREATE TABLE $tableEmergencyContacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        relationship TEXT,
        is_primary INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Pending shares table for offline SOS sharing
    batch.execute('''
      CREATE TABLE $tablePendingShares (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sos_alert_id INTEGER,
        contact_id INTEGER,
        share_type TEXT NOT NULL, -- 'sms', 'whatsapp', 'email', 'general'
        message_content TEXT NOT NULL,
        contact_info TEXT NOT NULL, -- phone/email
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 3,
        status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'failed'
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        last_attempt INTEGER,
        FOREIGN KEY (sos_alert_id) REFERENCES $tableSOSAlerts(id) ON DELETE CASCADE,
        FOREIGN KEY (contact_id) REFERENCES $tableEmergencyContacts(id) ON DELETE CASCADE
      )
    ''');

    // Offline messages queue
    batch.execute('''
      CREATE TABLE $tableOfflineMessages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_type TEXT NOT NULL, -- 'sos', 'location_update', 'emergency'
        recipient TEXT NOT NULL,
        message_content TEXT NOT NULL,
        metadata TEXT, -- JSON string for additional data
        priority INTEGER DEFAULT 1, -- 1=low, 2=medium, 3=high, 4=critical
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 5,
        status TEXT DEFAULT 'queued', -- 'queued', 'sending', 'sent', 'failed'
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        scheduled_at INTEGER,
        last_attempt INTEGER
      )
    ''');

    // Create indexes for better performance
    batch.execute('CREATE INDEX idx_sos_alerts_timestamp ON $tableSOSAlerts(timestamp)');
    batch.execute('CREATE INDEX idx_locations_timestamp ON $tableLocations(timestamp)');
    batch.execute('CREATE INDEX idx_pending_shares_status ON $tablePendingShares(status)');
    batch.execute('CREATE INDEX idx_offline_messages_priority ON $tableOfflineMessages(priority, status)');

    // Trip Events table for offline trip management
    batch.execute('''
      CREATE TABLE $tableTripEvents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backend_id TEXT, -- Server-assigned ID after sync
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        destination_latitude REAL NOT NULL,
        destination_longitude REAL NOT NULL,
        destination_address TEXT,
        destination_name TEXT,
        current_latitude REAL,
        current_longitude REAL,
        current_address TEXT,
        notes TEXT,
        status TEXT DEFAULT 'scheduled', -- scheduled, active, completed, missed, alert_triggered, cancelled
        travel_mode TEXT DEFAULT 'other', -- walking, driving, public_transport, cycling, other
        last_location_update INTEGER,
        is_emergency_contacts_notified INTEGER DEFAULT 0,
        alert_threshold_location_timeout INTEGER DEFAULT 30,
        alert_threshold_destination_tolerance INTEGER DEFAULT 500,
        is_synced INTEGER DEFAULT 0,
        sync_version INTEGER DEFAULT 1,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    batch.execute('CREATE INDEX idx_trip_events_status ON $tableTripEvents(status)');
    batch.execute('CREATE INDEX idx_trip_events_start_time ON $tableTripEvents(start_time)');
    batch.execute('CREATE INDEX idx_trip_events_sync ON $tableTripEvents(is_synced)');

    await batch.commit();
    print('✅ Database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('📈 Upgrading database from version $oldVersion to $newVersion');
    
    // Upgrade from version 1 to 2: Add trip_events table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE $tableTripEvents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          backend_id TEXT,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          destination_latitude REAL NOT NULL,
          destination_longitude REAL NOT NULL,
          destination_address TEXT,
          destination_name TEXT,
          current_latitude REAL,
          current_longitude REAL,
          current_address TEXT,
          notes TEXT,
          status TEXT DEFAULT 'scheduled',
          travel_mode TEXT DEFAULT 'other',
          last_location_update INTEGER,
          is_emergency_contacts_notified INTEGER DEFAULT 0,
          alert_threshold_location_timeout INTEGER DEFAULT 30,
          alert_threshold_destination_tolerance INTEGER DEFAULT 500,
          is_synced INTEGER DEFAULT 0,
          sync_version INTEGER DEFAULT 1,
          created_at INTEGER DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
      ''');

      await db.execute('CREATE INDEX idx_trip_events_status ON $tableTripEvents(status)');
      await db.execute('CREATE INDEX idx_trip_events_start_time ON $tableTripEvents(start_time)');
      await db.execute('CREATE INDEX idx_trip_events_sync ON $tableTripEvents(is_synced)');
      
      print('✅ Trip events table added in database upgrade');
    }
  }

  /// Database opened callback
  Future<void> _onOpen(Database db) async {
    print('🗄️ Database opened successfully');
    await _performMaintenanceTasks(db);
  }

  /// Perform maintenance tasks on database open
  Future<void> _performMaintenanceTasks(Database db) async {
    try {
      // Clean up old synced SOS alerts (older than 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;
      await db.delete(
        tableSOSAlerts,
        where: 'is_synced = 1 AND created_at < ?',
        whereArgs: [thirtyDaysAgo ~/ 1000],
      );

      // Clean up old location data (older than 7 days)
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;
      await db.delete(
        tableLocations,
        where: 'is_synced = 1 AND created_at < ?',
        whereArgs: [sevenDaysAgo ~/ 1000],
      );

      // Clean up failed messages (older than 3 days with max retries exceeded)
      final threeDaysAgo = DateTime.now().subtract(Duration(days: 3)).millisecondsSinceEpoch;
      await db.delete(
        tableOfflineMessages,
        where: 'status = "failed" AND created_at < ? AND retry_count >= max_retries',
        whereArgs: [threeDaysAgo ~/ 1000],
      );

      print('🧹 Database maintenance completed');
    } catch (e) {
      print('❌ Database maintenance error: $e');
    }
  }

  /// Store SOS alert for offline access
  Future<int> storeSOSAlert({
    required String emergencyType,
    required String message,
    required Position position,
    String? userId,
  }) async {
    try {
      final db = await database;
      final sosAlert = {
        'emergency_type': emergencyType,
        'message': message,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        'user_id': userId,
        'is_synced': 0,
      };

      final id = await db.insert(tableSOSAlerts, sosAlert);
      print('💾 SOS Alert stored with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error storing SOS alert: $e');
      rethrow;
    }
  }
  
  /// Get unsent SOS alerts for syncing when online
  Future<List<Map<String, dynamic>>> getUnsentSOSAlerts() async {
    try {
      final db = await database;
      return await db.query(
        tableSOSAlerts,
        where: 'is_synced = 0',
        orderBy: 'timestamp ASC',
      );
    } catch (e) {
      print('❌ Error getting unsent SOS alerts: $e');
      return [];
    }
  }

  /// Store location data for tracking
  Future<int> storeLocationData(Position position) async {
    try {
      final db = await database;
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        'is_synced': 0,
      };

      final id = await db.insert(tableLocations, locationData);
      print('📍 Location data stored with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error storing location data: $e');
      return -1;
    }
  }

  /// Cache emergency contacts for offline access
  Future<void> cacheEmergencyContacts(List<EmergencyContact> contacts) async {
    try {
      final db = await database;
      await db.delete(tableEmergencyContacts); // Clear existing cache

      final batch = db.batch();
      for (final contact in contacts) {
        batch.insert(tableEmergencyContacts, {
          'name': contact.name,
          'phone': contact.phone,
          'relationship': contact.relationship,
          'is_primary': contact.isPrimary ? 1 : 0,
          'is_active': 1,
        });
      }

      await batch.commit();
      print('👥 Cached ${contacts.length} emergency contacts');
    } catch (e) {
      print('❌ Error caching emergency contacts: $e');
    }
  }

  /// Get cached emergency contacts
  Future<List<EmergencyContact>> getCachedEmergencyContacts() async {
    try {
      final db = await database;
      final maps = await db.query(
        tableEmergencyContacts,
        where: 'is_active = 1',
        orderBy: 'is_primary DESC, name ASC',
      );

      return maps.map((map) => EmergencyContact(
        id: (map['id'] as int).toString(),
        name: map['name'] as String,
        phone: map['phone'] as String,
        relationship: map['relationship'] as String,
        isPrimary: (map['is_primary'] as int) == 1,
      )).toList();
    } catch (e) {
      print('❌ Error getting cached contacts: $e');
      return [];
    }
  }

  /// Add pending share for offline SOS
  Future<int> addPendingShare({
    required int sosAlertId,
    required int contactId,
    required String shareType,
    required String messageContent,
    required String contactInfo,
  }) async {
    try {
      final db = await database;
      final pendingShare = {
        'sos_alert_id': sosAlertId,
        'contact_id': contactId,
        'share_type': shareType,
        'message_content': messageContent,
        'contact_info': contactInfo,
        'status': 'pending',
      };

      final id = await db.insert(tablePendingShares, pendingShare);
      print('⏳ Pending share added with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error adding pending share: $e');
      return -1;
    }
  }

  /// Get pending shares for processing
  Future<List<Map<String, dynamic>>> getPendingShares() async {
    try {
      final db = await database;
      return await db.query(
        tablePendingShares,
        where: 'status = ? AND retry_count < max_retries',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ Error getting pending shares: $e');
      return [];
    }
  }

  /// Update pending share status
  Future<void> updatePendingShareStatus(int id, String status, {int? retryCount}) async {
    try {
      final db = await database;
      final updates = {
        'status': status,
        'last_attempt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      
      if (retryCount != null) {
        updates['retry_count'] = retryCount;
      }

      await db.update(
        tablePendingShares,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('📝 Pending share $id status updated to: $status');
    } catch (e) {
      print('❌ Error updating pending share status: $e');
    }
  }

  /// Queue offline message
  Future<int> queueOfflineMessage({
    required String messageType,
    required String recipient,
    required String messageContent,
    String? metadata,
    int priority = 1,
    DateTime? scheduledAt,
  }) async {
    try {
      final db = await database;
      final offlineMessage = {
        'message_type': messageType,
        'recipient': recipient,
        'message_content': messageContent,
        'metadata': metadata,
        'priority': priority,
        'scheduled_at': scheduledAt != null ? scheduledAt.millisecondsSinceEpoch ~/ 1000 : null,
        'status': 'queued',
      };

      final id = await db.insert(tableOfflineMessages, offlineMessage);
      print('📮 Offline message queued with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error queuing offline message: $e');
      return -1;
    }
  }

  /// Get queued offline messages
  Future<List<Map<String, dynamic>>> getQueuedOfflineMessages({int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        tableOfflineMessages,
        where: 'status = ? AND retry_count < max_retries',
        whereArgs: ['queued'],
        orderBy: 'priority DESC, created_at ASC',
        limit: limit,
      );
    } catch (e) {
      print('❌ Error getting queued messages: $e');
      return [];
    }
  }

  /// Update offline message status
  Future<void> updateOfflineMessageStatus(int id, String status, {int? retryCount}) async {
    try {
      final db = await database;
      final updates = {
        'status': status,
        'last_attempt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      
      if (retryCount != null) {
        updates['retry_count'] = retryCount;
      }

      await db.update(
        tableOfflineMessages,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('📧 Offline message $id status updated to: $status');
    } catch (e) {
      print('❌ Error updating offline message status: $e');
    }
  }

  /// Get last known location from database
  Future<Position?> getLastKnownLocation() async {
    try {
      final db = await database;
      final maps = await db.query(
        tableLocations,
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final map = maps.first;
        return Position(
          latitude: map['latitude'] as double,
          longitude: map['longitude'] as double,
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
          accuracy: map['accuracy'] as double? ?? 0,
          altitude: map['altitude'] as double? ?? 0,
          altitudeAccuracy: 0,
          heading: map['heading'] as double? ?? 0,
          headingAccuracy: 0,
          speed: map['speed'] as double? ?? 0,
          speedAccuracy: 0,
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting last known location: $e');
      return null;
    }
  }

  /// Get unsynced SOS alerts
  Future<List<Map<String, dynamic>>> getUnsyncedSOSAlerts() async {
    try {
      final db = await database;
      return await db.query(
        tableSOSAlerts,
        where: 'is_synced = 0',
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      print('❌ Error getting unsynced SOS alerts: $e');
      return [];
    }
  }

  /// Mark SOS alert as synced
  Future<void> markSOSAlertAsSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        tableSOSAlerts,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ SOS Alert $id marked as synced');
    } catch (e) {
      print('❌ Error marking SOS alert as synced: $e');
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;
      final stats = <String, int>{};
      
      // Count records in each table
      final sosCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableSOSAlerts')
      ) ?? 0;
      
      final locationCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableLocations')
      ) ?? 0;
      
      final contactCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableEmergencyContacts')
      ) ?? 0;
      
      final pendingShareCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tablePendingShares WHERE status = "pending"')
      ) ?? 0;
      
      final queuedMessageCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableOfflineMessages WHERE status = "queued"')
      ) ?? 0;

      stats['sos_alerts'] = sosCount;
      stats['locations'] = locationCount;
      stats['emergency_contacts'] = contactCount;
      stats['pending_shares'] = pendingShareCount;
      stats['queued_messages'] = queuedMessageCount;

      return stats;
    } catch (e) {
      print('❌ Error getting database stats: $e');
      return {};
    }
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    try {
      final db = await database;
      final batch = db.batch();
      
      batch.delete(tablePendingShares);
      batch.delete(tableOfflineMessages);
      batch.delete(tableSOSAlerts);
      batch.delete(tableLocations);
      batch.delete(tableEmergencyContacts);
      
      await batch.commit();
      print('🗑️ All database data cleared');
    } catch (e) {
      print('❌ Error clearing database data: $e');
    }
  }

  /// Get unsynced locations for background sync
  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    try {
      final db = await database;
      final locations = await db.query(
        tableLocations,
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
        limit: 100, // Sync in batches
      );
      
      print('📍 Retrieved ${locations.length} unsynced locations');
      return locations;
    } catch (e) {
      print('❌ Error getting unsynced locations: $e');
      return [];
    }
  }

  /// Mark locations as synced after successful upload
  Future<void> markLocationsSynced([List<int>? locationIds]) async {
    try {
      final db = await database;
      
      if (locationIds != null && locationIds.isNotEmpty) {
        // Mark specific locations as synced
        final batch = db.batch();
        for (final id in locationIds) {
          batch.update(
            tableLocations,
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit();
        print('✅ Marked ${locationIds.length} locations as synced');
      } else {
        // Mark all unsynced locations as synced
        final count = await db.update(
          tableLocations,
          {'is_synced': 1},
          where: 'is_synced = ?',
          whereArgs: [0],
        );
        print('✅ Marked $count locations as synced');
      }
    } catch (e) {
      print('❌ Error marking locations as synced: $e');
    }
  }

  /// Store location data with sync information
  Future<int> storeLocation(Map<String, dynamic> locationData) async {
    try {
      final db = await database;
      
      // Ensure required fields with defaults
      final data = {
        'latitude': locationData['latitude'],
        'longitude': locationData['longitude'],
        'accuracy': locationData['accuracy'] ?? 0.0,
        'altitude': locationData['altitude'] ?? 0.0,
        'heading': locationData['heading'] ?? 0.0,
        'speed': locationData['speed'] ?? 0.0,
        'timestamp': locationData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      };

      final id = await db.insert(tableLocations, data);
      print('📍 Location stored with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error storing location: $e');
      return -1;
    }
  }

  /// Get recent stored locations for monitoring/debugging (last N locations)
  Future<List<Map<String, dynamic>>> getRecentStoredLocations({int limit = 10}) async {
    try {
      final db = await database;
      final locations = await db.query(
        tableLocations,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      
      print('📍 Retrieved ${locations.length} recent stored locations');
      return locations;
    } catch (e) {
      print('❌ Error getting recent stored locations: $e');
      return [];
    }
  }

  /// Get service statistics for monitoring
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      final db = await database;
      
      final totalLocations = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableLocations',
      );
      
      final unsyncedLocations = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableLocations WHERE is_synced = 0',
      );
      
      final totalSOS = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableSOSAlerts',
      );
      
      final unsyncedSOS = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableSOSAlerts WHERE is_synced = 0',
      );

      final stats = {
        'totalLocations': totalLocations.first['count'] ?? 0,
        'unsyncedLocations': unsyncedLocations.first['count'] ?? 0,
        'totalSOSAlerts': totalSOS.first['count'] ?? 0,
        'unsyncedSOSAlerts': unsyncedSOS.first['count'] ?? 0,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
      
      print('📊 Service stats: $stats');
      return stats;
    } catch (e) {
      print('❌ Error getting service stats: $e');
      return {
        'totalLocations': 0,
        'unsyncedLocations': 0,
        'totalSOSAlerts': 0,
        'unsyncedSOSAlerts': 0,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 Database connection closed');
    }
  }

  // ==================== TRIP EVENTS METHODS ====================

  /// Store trip event for offline access
  Future<int> storeTripEvent(Map<String, dynamic> tripEvent) async {
    try {
      final db = await database;
      final id = await db.insert(tableTripEvents, tripEvent);
      print('🗓️ Trip event stored with ID: $id');
      return id;
    } catch (e) {
      print('❌ Error storing trip event: $e');
      rethrow;
    }
  }

  /// Get all trip events (with optional status filter)
  Future<List<Map<String, dynamic>>> getTripEvents({String? status, String? userId}) async {
    try {
      final db = await database;
      String? whereClause;
      List<dynamic>? whereArgs;

      if (status != null && userId != null) {
        whereClause = 'status = ? AND user_id = ?';
        whereArgs = [status, userId];
      } else if (status != null) {
        whereClause = 'status = ?';
        whereArgs = [status];
      } else if (userId != null) {
        whereClause = 'user_id = ?';
        whereArgs = [userId];
      }

      final trips = await db.query(
        tableTripEvents,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_time DESC',
      );

      print('🗓️ Retrieved ${trips.length} trip events');
      return trips;
    } catch (e) {
      print('❌ Error getting trip events: $e');
      return [];
    }
  }

  /// Get specific trip event by ID
  Future<Map<String, dynamic>?> getTripEvent(int id) async {
    try {
      final db = await database;
      final trips = await db.query(
        tableTripEvents,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (trips.isNotEmpty) {
        print('🗓️ Retrieved trip event with ID: $id');
        return trips.first;
      }
      return null;
    } catch (e) {
      print('❌ Error getting trip event: $e');
      return null;
    }
  }

  /// Update trip event
  Future<void> updateTripEvent(int id, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      
      // Add updated_at timestamp
      final data = {
        ...updates,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'is_synced': 0, // Mark as unsynced when updated
      };

      await db.update(
        tableTripEvents,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      print('🗓️ Trip event $id updated');
    } catch (e) {
      print('❌ Error updating trip event: $e');
      rethrow;
    }
  }

  /// Update trip location during active trip
  Future<void> updateTripLocation(
    int id,
    double latitude,
    double longitude, {
    String? address,
  }) async {
    try {
      final db = await database;
      await db.update(
        tableTripEvents,
        {
          'current_latitude': latitude,
          'current_longitude': longitude,
          'current_address': address,
          'last_location_update': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      print('📍 Trip $id location updated');
    } catch (e) {
      print('❌ Error updating trip location: $e');
    }
  }

  /// Get unsynced trip events
  Future<List<Map<String, dynamic>>> getUnsyncedTripEvents() async {
    try {
      final db = await database;
      final trips = await db.query(
        tableTripEvents,
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
      );

      print('🗓️ Retrieved ${trips.length} unsynced trip events');
      return trips;
    } catch (e) {
      print('❌ Error getting unsynced trip events: $e');
      return [];
    }
  }

  /// Mark trip event as synced
  Future<void> markTripEventSynced(int id, {String? backendId}) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{'is_synced': 1};
      
      if (backendId != null) {
        updates['backend_id'] = backendId;
      }

      await db.update(
        tableTripEvents,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ Trip event $id marked as synced');
    } catch (e) {
      print('❌ Error marking trip event as synced: $e');
    }
  }

  /// Get active trip events (currently in progress)
  Future<List<Map<String, dynamic>>> getActiveTripEvents({String? userId}) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      String whereClause = 'status = ? AND start_time <= ? AND end_time >= ?';
      List<dynamic> whereArgs = ['active', now, now];

      if (userId != null) {
        whereClause += ' AND user_id = ?';
        whereArgs.add(userId);
      }

      final trips = await db.query(
        tableTripEvents,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_time ASC',
      );

      print('🗓️ Retrieved ${trips.length} active trip events');
      return trips;
    } catch (e) {
      print('❌ Error getting active trip events: $e');
      return [];
    }
  }

  /// Get upcoming trip events
  Future<List<Map<String, dynamic>>> getUpcomingTripEvents({String? userId, int limit = 10}) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      String whereClause = 'status = ? AND start_time > ?';
      List<dynamic> whereArgs = ['scheduled', now];

      if (userId != null) {
        whereClause += ' AND user_id = ?';
        whereArgs.add(userId);
      }

      final trips = await db.query(
        tableTripEvents,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_time ASC',
        limit: limit,
      );

      print('🗓️ Retrieved ${trips.length} upcoming trip events');
      return trips;
    } catch (e) {
      print('❌ Error getting upcoming trip events: $e');
      return [];
    }
  }

  /// Delete trip event (soft delete by setting status to cancelled)
  Future<void> deleteTripEvent(int id) async {
    try {
      final db = await database;
      await db.update(
        tableTripEvents,
        {
          'status': 'cancelled',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      print('🗑️ Trip event $id cancelled');
    } catch (e) {
      print('❌ Error deleting trip event: $e');
      rethrow;
    }
  }

  /// Get trip events that need monitoring (active trips that haven't been updated recently)
  Future<List<Map<String, dynamic>>> getTripsNeedingMonitoring({
    int timeoutMinutes = 30,
    String? userId,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeoutThreshold = now - (timeoutMinutes * 60);

      String whereClause = 'status = ? AND (last_location_update IS NULL OR last_location_update < ?)';
      List<dynamic> whereArgs = ['active', timeoutThreshold];

      if (userId != null) {
        whereClause += ' AND user_id = ?';
        whereArgs.add(userId);
      }

      final trips = await db.query(
        tableTripEvents,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'last_location_update ASC NULLS FIRST',
      );

      print('⚠️ Retrieved ${trips.length} trips needing monitoring');
      return trips;
    } catch (e) {
      print('❌ Error getting trips needing monitoring: $e');
      return [];
    }
  }

  /// Dispose of the service
  void dispose() {
    close();
    _instance = null;
  }

  Future<void> init() async {}
}