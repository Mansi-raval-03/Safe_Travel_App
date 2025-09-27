class ApiConfig {
  // Update this URL to match your backend server
  // For development, use your local IP address or localhost
  // For production, use your deployed server URL
  static const String baseUrl = 'http://localhost:3000/api/v1';
  
  // Alternative configurations for different environments
  static const String developmentUrl = 'http://localhost:3000/api/v1';
  static const String productionUrl = 'https://your-production-server.com/api/v1';
  
  // Get the current base URL based on environment
  static String get currentBaseUrl {
    // You can add logic here to switch between development and production
    // For now, return the base URL
    return baseUrl;
  }
  
  // Common headers for API requests
  static Map<String, String> get commonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);
}