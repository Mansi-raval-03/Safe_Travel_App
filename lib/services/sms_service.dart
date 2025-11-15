import 'dart:async';
import 'dart:collection';
import 'package:another_telephony/telephony.dart';
import 'sms_retry_service.dart';

class SmsService {
  SmsService._();

  static final Telephony _telephony = Telephony.instance;

  /// Requests required SMS & phone permissions. Returns true when granted.
  static Future<bool> ensurePermissions() async {
    try {
      final bool? granted = await _telephony.requestPhoneAndSmsPermissions;
      return granted == true;
    } catch (e) {
      print('SmsService: permission request failed: $e');
      return false;
    }
  }

  /// Send SOS messages to the provided phone numbers.
  /// Message body will include a maps link and timestamp.
  static Future<void> sendSOSMessages({
    required List<String> phones,
    required String message,
    required double latitude,
    required double longitude,
    int concurrency = 3,
  }) async {
    if (phones.isEmpty) {
      print('SmsService: no phone numbers provided');
      return;
    }

    final canSend = await _telephony.isSmsCapable ?? false;
    if (!canSend) {
      print('SmsService: device not capable of sending SMS');
      return;
    }

    final body = _buildMessage(message, latitude, longitude);

    // Send with limited concurrency to avoid overwhelming the device
    final sem = _AsyncSemaphore(concurrency);
    final futures = <Future>[];

    for (final to in phones) {
      if (to.trim().isEmpty) continue;
      await sem.acquire();
      final recipient = to.trim();
      final f = _telephony.sendSms(
        to: recipient,
        message: body,
        isMultipart: true,
        statusListener: (SendStatus status) {
          print('SmsService: sms to $recipient status: $status');
        },
      ).catchError((e) async {
        print('SmsService: failed to send sms to $recipient: $e');
        try {
          await SmsRetryService.instance.addFailedSms(phone: recipient, message: body);
          print('SmsService: queued failed sms to retry later for $recipient');
        } catch (dbErr) {
          print('SmsService: failed to queue sms for retry: $dbErr');
        }
      }).whenComplete(() => sem.release());

      futures.add(f);
    }

    try {
      await Future.wait(futures);
      print('SmsService: finished sending SMS batch');
    } catch (e) {
      print('SmsService: error awaiting SMS futures: $e');
    }
  }

  /// Send a single SMS and return true on success.
  static Future<bool> sendSingleSms({required String phone, required String message}) async {
    try {
      final canSend = await _telephony.isSmsCapable ?? false;
      if (!canSend) {
        print('SmsService: device not capable of sending SMS (single)');
        return false;
      }

      await _telephony.sendSms(
        to: phone.trim(),
        message: message,
        isMultipart: true,
        statusListener: (SendStatus status) {
          print('SmsService: single sms to $phone status: $status');
        },
      );
      return true;
    } catch (e) {
      print('SmsService: sendSingleSms failed for $phone: $e');
      try {
        await SmsRetryService.instance.addFailedSms(phone: phone.trim(), message: message);
      } catch (dbErr) {
        print('SmsService: failed to queue single sms for retry: $dbErr');
      }
      return false;
    }
  }

  static String _buildMessage(String message, double lat, double lng) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final maps = 'https://maps.google.com/?q=$lat,$lng';
    return '${message.trim()}\n\nLocation: $maps\nTime (UTC): $timestamp';
  }
}

/// Very small async semaphore for limiting concurrency
class _AsyncSemaphore {
  int _count;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  _AsyncSemaphore(this._count);

  Future<void> acquire() {
    if (_count > 0) {
      _count -= 1;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final c = _waiters.removeFirst();
      c.complete();
    } else {
      _count += 1;
    }
  }
}
