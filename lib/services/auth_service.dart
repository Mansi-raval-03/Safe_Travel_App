import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.currentBaseUrl;
  
  /// Sign up with email, password, name, and phone
  static Future<AuthResult> signup(String name, String email, String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: ApiConfig.commonHeaders,
        body: json.encode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      ).timeout(ApiConfig.requestTimeout);

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201 && responseData['success'] == true) {
        final userData = responseData['data']['user'];
        final token = responseData['data']['token'];
        
        // Create user object
        final user = User(
          id: userData['_id'],
          name: userData['name'],
          email: userData['email'],
          phone: userData['phone'],
        );

        // Save token and user data
        await _saveAuthData(token, user);

        return AuthResult(
          success: true,
          user: user,
          token: token,
          message: responseData['message'],
        );
      } else {
        return AuthResult(
          success: false,
          message: responseData['message'] ?? 'Signup failed',
        );
      }
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: ApiConfig.timeoutErrorMessage,
      );
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'Unable to connect to server. Please ensure the backend server is running and try again.',
      );
    } on FormatException {
      return AuthResult(
        success: false,
        message: 'Invalid server response. Please try again.',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signin'),
        headers: ApiConfig.commonHeaders,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.requestTimeout);

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final userData = responseData['data']['user'];
        final token = responseData['data']['token'];
        
        // Create user object
        final user = User(
          id: userData['_id'],
          name: userData['name'],
          email: userData['email'],
          phone: userData['phone'],
        );

        // Save token and user data
        await _saveAuthData(token, user);

        return AuthResult(
          success: true,
          user: user,
          token: token,
          message: responseData['message'],
        );
      } else {
        return AuthResult(
          success: false,
          message: responseData['message'] ?? 'Invalid credentials',
        );
      }
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: ApiConfig.timeoutErrorMessage,
      );
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'Unable to connect to server. Please ensure the backend server is running and try again.',
      );
    } on FormatException {
      return AuthResult(
        success: false,
        message: 'Invalid server response. Please try again.',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Sign out - clear stored data
  static Future<void> signout() async {
    try {
      // Try to call backend signout endpoint
      final token = await getAuthToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/signout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Even if backend call fails, we still clear local data
      print('Signout API error: $e');
    } finally {
      // Always clear local data
      await clearAuthData();
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    final user = await getCurrentUser();
    return token != null && user != null;
  }

  /// Get current user from storage
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      
      if (userJson != null) {
        final userData = json.decode(userJson);
        return User(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          phone: userData['phone'],
        );
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Get stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Refresh authentication token
  static Future<AuthResult> refreshToken() async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        return AuthResult(success: false, message: 'No auth token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final newToken = responseData['data']['token'];
        
        // Update stored token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', newToken);

        return AuthResult(
          success: true,
          token: newToken,
          message: 'Token refreshed successfully',
        );
      } else {
        // Token refresh failed, clear auth data
        await clearAuthData();
        return AuthResult(
          success: false,
          message: responseData['message'] ?? 'Token refresh failed',
        );
      }
    } catch (e) {
      // Network error, clear auth data
      await clearAuthData();
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Save auth data to secure storage
  static Future<void> _saveAuthData(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save token
    await prefs.setString('auth_token', token);
    
    // Save user data
    final userJson = json.encode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
    });
    await prefs.setString('current_user', userJson);
    
    // Save login timestamp for token expiry tracking
    await prefs.setInt('auth_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear all auth data
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
    await prefs.remove('auth_timestamp');
  }

  /// Check if token is expired (24 hours)
  static Future<bool> isTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('auth_timestamp');
      
      if (timestamp == null) return true;
      
      final loginTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(loginTime);
      
      // Token expires after 24 hours
      return difference.inHours >= 24;
    } catch (e) {
      return true; // Assume expired if error occurs
    }
  }

  /// Update user profile
  static Future<AuthResult> updateUserProfile(User updatedUser) async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        return AuthResult(success: false, message: 'Authentication required');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': updatedUser.name,
          'phone': updatedUser.phone,
        }),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Update stored user data
        await _saveAuthData(token, updatedUser);
        
        return AuthResult(
          success: true,
          user: updatedUser,
          message: responseData['message'] ?? 'Profile updated successfully',
        );
      } else {
        return AuthResult(
          success: false,
          message: responseData['message'] ?? 'Update failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}

/// Authentication result class
class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String message;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    required this.message,
  });
}