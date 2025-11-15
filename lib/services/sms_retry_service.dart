import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SmsRetryService {
  SmsRetryService._();

  static final SmsRetryService _instance = SmsRetryService._();
  static SmsRetryService get instance => _instance;

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final docs = await getApplicationDocumentsDirectory();
    final path = join(docs.path, 'safe_travel_sms_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sms_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            message TEXT NOT NULL,
            attempts INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> addFailedSms({required String phone, required String message}) async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await _db!.insert('sms_queue', {
      'phone': phone,
      'message': message,
      'attempts': 0,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSms({int limit = 50}) async {
    await init();
    final rows = await _db!.query('sms_queue', orderBy: 'created_at ASC', limit: limit);
    return rows;
  }

  Future<void> removeSms(int id) async {
    await init();
    await _db!.delete('sms_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementAttempts(int id) async {
    await init();
    await _db!.rawUpdate('UPDATE sms_queue SET attempts = attempts + 1 WHERE id = ?', [id]);
  }

  /// Retry pending SMS using a provided sender callback.
  /// The sender should return true on success.
  Future<void> retryPending(Future<bool> Function(String phone, String message) sender, {int batch = 20}) async {
    await init();
    final pending = await getPendingSms(limit: batch);
    for (final row in pending) {
      final int id = row['id'] as int;
      final String phone = row['phone'] as String;
      final String message = row['message'] as String;
      try {
        final ok = await sender(phone, message);
        if (ok) {
          await removeSms(id);
        } else {
          await incrementAttempts(id);
        }
      } catch (e) {
        await incrementAttempts(id);
      }
    }
  }
}
