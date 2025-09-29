import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('🔍 Testing backend connection...');
  
  // Test different URLs for different environments
  List<String> testUrls = [
    'https://safe-travel-app-backend.onrender.com',   // Production Render
    'http://localhost:3000',                          // Local development
    'http://10.0.2.2:3000',                         // Android Emulator
  ];
  
  for (String baseUrl in testUrls) {
    print('\n📍 Testing: $baseUrl');
    
    try {
      // Test basic server connection
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      print('✅ Status: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('📄 Response: ${response.body}');
      }
      
    } on SocketException catch (e) {
      print('❌ Connection refused: ${e.message}');
    } on HttpException catch (e) {
      print('⚠️ HTTP Error: ${e.message}');
    } on FormatException catch (e) {
      print('🔍 Format Error: ${e.message}');
    } catch (e) {
      print('❓ Unknown Error: $e');
    }
  }
  
  print('\n🎯 Testing authentication endpoint...');
  try {
    final testData = {
      'email': 'test@example.com',
      'password': 'testpass'
    };
    
    final response = await http.post(
      Uri.parse('https://safe-travel-app-backend.onrender.com/api/v1/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(testData),
    ).timeout(Duration(seconds: 10));
    
    print('✅ Auth endpoint status: ${response.statusCode}');
    print('📄 Auth response: ${response.body}');
    
  } catch (e) {
    print('❌ Auth endpoint error: $e');
  }
  
  print('\n🏁 Connection test completed!');
}