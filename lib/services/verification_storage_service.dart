import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class VerificationStorageService {
  static VerificationStorageService? _instance;
  static VerificationStorageService get instance {
    _instance ??= VerificationStorageService._();
    return _instance!;
  }
  VerificationStorageService._();

  // SharedPreferences keys
  static const String _verifiedEmailsKey = 'verified_emails';
  static const String _userPreferencesKey = 'user_preferences';
  static const String _registrationDataKey = 'registration_data';

  // SQLite database
  Database? _database;
  static const String _dbName = 'verification.db';
  static const int _dbVersion = 1;

  // Table names
  static const String _verificationTable = 'email_verifications';
  static const String _userDataTable = 'user_data';

  /// Initialize the storage service
  Future<void> initialize() async {
    await _initializeDatabase();
  }

  /// Initialize SQLite database
  Future<void> _initializeDatabase() async {
    if (_database != null) return;

    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      print('✅ Verification database initialized');
    } catch (e) {
      print('❌ Database initialization error: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_verificationTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        is_verified INTEGER NOT NULL DEFAULT 0,
        verified_at TEXT,
        user_name TEXT,
        user_data TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_userDataTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        name TEXT,
        phone TEXT,
        profile_data TEXT,
        preferences TEXT,
        registration_step INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_email_verification ON $_verificationTable(email)');
    await db.execute('CREATE INDEX idx_user_email ON $_userDataTable(email)');
    
    print('✅ Database tables created');
  }

  /// Upgrade database schema
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    print('📊 Upgrading database from version $oldVersion to $newVersion');
  }

  /// Get database instance
  Future<Database> get database async {
    if (_database == null) {
      await _initializeDatabase();
    }
    return _database!;
  }

  // ==================== EMAIL VERIFICATION METHODS ====================

  /// Save verified email information
  Future<void> saveVerifiedEmail(String email, Map<String, dynamic> userData) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.insert(
        _verificationTable,
        {
          'email': email.trim().toLowerCase(),
          'is_verified': 1,
          'verified_at': userData['verifiedAt'] ?? now,
          'user_name': userData['userName'],
          'user_data': json.encode(userData),
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Also save to SharedPreferences for quick access
      await _saveToSharedPreferences(email, userData);

      print('✅ Email verification saved: $email');
    } catch (e) {
      print('❌ Error saving verified email: $e');
      rethrow;
    }
  }

  /// Check if email is verified
  Future<bool> isEmailVerified(String email) async {
    try {
      // First check SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      final verifiedEmails = prefs.getStringList(_verifiedEmailsKey) ?? [];
      
      if (verifiedEmails.contains(email.trim().toLowerCase())) {
        return true;
      }

      // Check database
      final db = await database;
      final result = await db.query(
        _verificationTable,
        where: 'email = ? AND is_verified = ?',
        whereArgs: [email.trim().toLowerCase(), 1],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking email verification: $e');
      return false;
    }
  }

  /// Get verified email data
  Future<Map<String, dynamic>?> getVerifiedEmailData(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        _verificationTable,
        where: 'email = ? AND is_verified = ?',
        whereArgs: [email.trim().toLowerCase(), 1],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'email': row['email'],
          'verifiedAt': row['verified_at'],
          'userName': row['user_name'],
          'userData': row['user_data'] != null 
              ? json.decode(row['user_data'] as String) 
              : null,
          'createdAt': row['created_at'],
          'updatedAt': row['updated_at'],
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting verified email data: $e');
      return null;
    }
  }

  /// Get all verified emails
  Future<List<String>> getAllVerifiedEmails() async {
    try {
      final db = await database;
      final result = await db.query(
        _verificationTable,
        columns: ['email'],
        where: 'is_verified = ?',
        whereArgs: [1],
      );

      return result.map((row) => row['email'] as String).toList();
    } catch (e) {
      print('❌ Error getting all verified emails: $e');
      return [];
    }
  }

  /// Remove verified email
  Future<void> removeVerifiedEmail(String email) async {
    try {
      final db = await database;
      await db.delete(
        _verificationTable,
        where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()],
      );

      // Also remove from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final verifiedEmails = prefs.getStringList(_verifiedEmailsKey) ?? [];
      verifiedEmails.remove(email.trim().toLowerCase());
      await prefs.setStringList(_verifiedEmailsKey, verifiedEmails);

      print('✅ Email verification removed: $email');
    } catch (e) {
      print('❌ Error removing verified email: $e');
      rethrow;
    }
  }

  // ==================== USER DATA METHODS ====================

  /// Save user registration data
  Future<void> saveUserData(String email, Map<String, dynamic> userData) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.insert(
        _userDataTable,
        {
          'email': email.trim().toLowerCase(),
          'name': userData['name'],
          'phone': userData['phone'],
          'profile_data': json.encode(userData),
          'preferences': userData['preferences'] != null 
              ? json.encode(userData['preferences']) 
              : null,
          'registration_step': userData['registrationStep'] ?? 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ User data saved: $email');
    } catch (e) {
      print('❌ Error saving user data: $e');
      rethrow;
    }
  }

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        _userDataTable,
        where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'email': row['email'],
          'name': row['name'],
          'phone': row['phone'],
          'profileData': row['profile_data'] != null 
              ? json.decode(row['profile_data'] as String) 
              : null,
          'preferences': row['preferences'] != null 
              ? json.decode(row['preferences'] as String) 
              : null,
          'registrationStep': row['registration_step'],
          'createdAt': row['created_at'],
          'updatedAt': row['updated_at'],
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Update registration step
  Future<void> updateRegistrationStep(String email, int step) async {
    try {
      final db = await database;
      await db.update(
        _userDataTable,
        {
          'registration_step': step,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()],
      );

      print('✅ Registration step updated: $email -> $step');
    } catch (e) {
      print('❌ Error updating registration step: $e');
      rethrow;
    }
  }

  // ==================== SHARED PREFERENCES METHODS ====================

  /// Save to SharedPreferences for quick access
  Future<void> _saveToSharedPreferences(String email, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Add email to verified list
    final verifiedEmails = prefs.getStringList(_verifiedEmailsKey) ?? [];
    final emailLower = email.trim().toLowerCase();
    
    if (!verifiedEmails.contains(emailLower)) {
      verifiedEmails.add(emailLower);
      await prefs.setStringList(_verifiedEmailsKey, verifiedEmails);
    }

    // Save user data
    await prefs.setString('user_data_$emailLower', json.encode(userData));
  }

  /// Save user preferences
  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPreferencesKey, json.encode(preferences));
      print('✅ User preferences saved');
    } catch (e) {
      print('❌ Error saving user preferences: $e');
      rethrow;
    }
  }

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsString = prefs.getString(_userPreferencesKey);
      
      if (prefsString != null) {
        return json.decode(prefsString);
      }

      // Return default preferences
      return {
        'notifications': true,
        'locationSharing': true,
        'emergencyAlerts': true,
        'offlineMode': false,
        'autoBackup': true,
      };
    } catch (e) {
      print('❌ Error getting user preferences: $e');
      return {};
    }
  }

  /// Save registration data temporarily
  Future<void> saveRegistrationData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_registrationDataKey, json.encode(data));
      print('✅ Registration data saved temporarily');
    } catch (e) {
      print('❌ Error saving registration data: $e');
      rethrow;
    }
  }

  /// Get registration data
  Future<Map<String, dynamic>?> getRegistrationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_registrationDataKey);
      
      if (dataString != null) {
        return json.decode(dataString);
      }

      return null;
    } catch (e) {
      print('❌ Error getting registration data: $e');
      return null;
    }
  }

  /// Clear registration data
  Future<void> clearRegistrationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registrationDataKey);
      print('✅ Registration data cleared');
    } catch (e) {
      print('❌ Error clearing registration data: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear all verification data
  Future<void> clearAllData() async {
    try {
      // Clear database
      final db = await database;
      await db.delete(_verificationTable);
      await db.delete(_userDataTable);

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_verifiedEmailsKey);
      await prefs.remove(_userPreferencesKey);
      await prefs.remove(_registrationDataKey);

      print('✅ All verification data cleared');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      rethrow;
    }
  }

  /// Get storage statistics
  Future<Map<String, int>> getStorageStats() async {
    try {
      final db = await database;
      
      final verificationCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_verificationTable'),
      ) ?? 0;
      
      final userDataCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_userDataTable'),
      ) ?? 0;

      return {
        'verifiedEmails': verificationCount,
        'userData': userDataCount,
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {'verifiedEmails': 0, 'userData': 0};
    }
  }

  /// Export all data
  Future<Map<String, dynamic>> exportData() async {
    try {
      final db = await database;
      
      final verifications = await db.query(_verificationTable);
      final userData = await db.query(_userDataTable);
      
      final preferences = getUserPreferences();

      return {
        'verifications': verifications,
        'userData': userData,
        'preferences': await preferences,
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error exporting data: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _instance = null;
  }
}