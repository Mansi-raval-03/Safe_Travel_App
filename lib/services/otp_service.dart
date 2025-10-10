import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class OTPService {
  static const String _baseUrl = ApiConfig.baseUrl;
  
  /// Send OTP to email
  Future<OTPResult> sendOTP(String email, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/otp/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email.trim().toLowerCase(),
          'name': name,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return OTPResult(
          success: true,
          message: data['message'] ?? 'OTP sent successfully',
          data: data['data'],
        );
      } else {
        return OTPResult(
          success: false,
          message: data['message'] ?? 'Failed to send OTP',
          errorCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      print('❌ Send OTP Error: $e');
      return OTPResult(
        success: false,
        message: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Verify OTP code
  Future<OTPResult> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/otp/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return OTPResult(
          success: true,
          message: data['message'] ?? 'Email verified successfully',
          data: data['data'],
        );
      } else {
        return OTPResult(
          success: false,
          message: data['message'] ?? 'Invalid OTP code',
          errorCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      print('❌ Verify OTP Error: $e');
      return OTPResult(
        success: false,
        message: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Resend OTP
  Future<OTPResult> resendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/otp/resend'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email.trim().toLowerCase(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return OTPResult(
          success: true,
          message: data['message'] ?? 'New OTP sent successfully',
          data: data['data'],
        );
      } else {
        return OTPResult(
          success: false,
          message: data['message'] ?? 'Failed to resend OTP',
          errorCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      print('❌ Resend OTP Error: $e');
      return OTPResult(
        success: false,
        message: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Check verification status
  Future<OTPStatusResult> checkVerificationStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/otp/status/${Uri.encodeComponent(email)}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return OTPStatusResult(
          success: true,
          isVerified: data['data']['isVerified'] ?? false,
          hasPendingOTP: data['data']['hasPendingOTP'] ?? false,
          attemptsRemaining: data['data']['attemptsRemaining'] ?? 3,
          otpExpiresAt: data['data']['otpExpiresAt'] != null
              ? DateTime.parse(data['data']['otpExpiresAt'])
              : null,
        );
      } else {
        return OTPStatusResult(
          success: false,
          message: data['message'] ?? 'Failed to check status',
        );
      }
    } catch (e) {
      print('❌ Check OTP Status Error: $e');
      return OTPStatusResult(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }
}

/// OTP operation result
class OTPResult {
  final bool success;
  final String message;
  final dynamic data;
  final int? errorCode;
  final List<dynamic>? errors;

  OTPResult({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
    this.errors,
  });

  factory OTPResult.fromJson(Map<String, dynamic> json) {
    return OTPResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
      errorCode: json['errorCode'],
      errors: json['errors'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'errorCode': errorCode,
      'errors': errors,
    };
  }
}

/// OTP status check result
class OTPStatusResult {
  final bool success;
  final bool isVerified;
  final bool hasPendingOTP;
  final int attemptsRemaining;
  final DateTime? otpExpiresAt;
  final String? message;

  OTPStatusResult({
    required this.success,
    this.isVerified = false,
    this.hasPendingOTP = false,
    this.attemptsRemaining = 3,
    this.otpExpiresAt,
    this.message,
  });

  factory OTPStatusResult.fromJson(Map<String, dynamic> json) {
    return OTPStatusResult(
      success: json['success'] ?? false,
      isVerified: json['isVerified'] ?? false,
      hasPendingOTP: json['hasPendingOTP'] ?? false,
      attemptsRemaining: json['attemptsRemaining'] ?? 3,
      otpExpiresAt: json['otpExpiresAt'] != null
          ? DateTime.parse(json['otpExpiresAt'])
          : null,
      message: json['message'],
    );
  }

  /// Check if OTP has expired
  bool get isExpired {
    if (otpExpiresAt == null) return false;
    return DateTime.now().isAfter(otpExpiresAt!);
  }

  /// Get remaining time in seconds
  int get remainingSeconds {
    if (otpExpiresAt == null) return 0;
    final diff = otpExpiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Get remaining time formatted as MM:SS
  String get remainingTimeFormatted {
    final totalSeconds = remainingSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}