class ApiConfig {
  // Update this URL to match your backend server
  // For development, use your local IP address or localhost
  // For production, use your deployed server URL
  static const String baseUrl = 'http://10.0.2.2:3000/api/v1'; // Android emulator
  static const String localhostUrl = 'http://localhost:3000/api/v1'; // Desktop/Web
  static const String localNetworkUrl = 'http://192.168.1.100:3000/api/v1'; // Replace with your IP
  
  // Alternative configurations for different environments
  static const String developmentUrl = 'http://10.0.2.2:3000/api/v1';
  static const String productionUrl = 'https://safe-travel-app-backend.onrender.com/api/v1';
  static const String localUrl = 'http://localhost:3000/api/v1';
  
  // Get the current base URL based on environment
  static String get currentBaseUrl {
    // Using production Render deployment
    // Switch to localUrl for local development
    // Switch to developmentUrl for Android emulator
    return productionUrl; // Using Render backend
  }

  // Socket.IO URLs (remove /api/v1 suffix for socket connection)
  static const String socketBaseUrl = 'http://10.0.2.2:3000'; // Android emulator
  static const String socketLocalhostUrl = 'http://localhost:3000'; // Desktop/Web
  static const String socketLocalNetworkUrl = 'http://192.168.1.100:3000'; // Replace with your IP
  static const String socketDevelopmentUrl = 'http://10.0.2.2:3000';
  static const String socketProductionUrl = 'https://safe-travel-app-backend.onrender.com';
  static const String socketLocalUrl = 'http://localhost:3000';
  
  // Get the current Socket.IO URL based on environment
  static String get currentSocketUrl {
    // Using production Render deployment for Socket.IO
    // Switch to socketLocalUrl for local development
    // Switch to socketDevelopmentUrl for Android emulator
    return socketProductionUrl; // Using Render backend for Socket.IO
  }
  
  // Common headers for API requests
  static Map<String, String> get commonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Network error messages
  static const String networkErrorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
  static const String timeoutErrorMessage = 'Request timed out. Please check your connection and try again.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
}