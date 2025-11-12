import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:safe_travel_app/models/emergency_screen.dart';
import 'package:safe_travel_app/screens/setting_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';

import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sos_confirmation_screen.dart';
import 'screens/offline_sos_screen.dart';
import 'screens/offline_emergency_contacts_screen.dart';
import 'screens/enhanced_offline_sos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/location_storage_demo_screen.dart';
import 'screens/trips_screen.dart';
import 'models/user.dart';
import 'services/auth_service.dart';
import 'services/auto_location_sync_service.dart';
import 'services/background_sync_worker.dart';
import 'services/location_cache_manager.dart';
import 'services/auto_sync_auth_manager.dart';
import 'config/api_config.dart';

import 'services/integrated_offline_emergency_service.dart';

void main() async {
  // Preserve splash screen while initializing
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Quick-start developer mode: if a file named `FAST_RUN` exists in the
  // project root, skip awaiting heavy initialization to speed up iterative
  // development and allow hot-reload cycles. This is safe for local testing
  // and can be removed before production.
  bool fastRun = false;
  try {
    fastRun = File('FAST_RUN').existsSync();
  } catch (_) {
    fastRun = false;
  }

  if (fastRun) {
    // Remove splash and run app immediately. Initialize services in background.
  FlutterNativeSplash.remove();
  runApp(SafeTravelApp());
  // Start initialization in background (do not await) so app launches fast.
  _initializeAutoLocationSync();
    return;
  }

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Initialize auto location sync services (blocking) for normal runs
  await _initializeAutoLocationSync();

  runApp(SafeTravelApp());
}

/// Initialize the auto location sync feature
Future<void> _initializeAutoLocationSync() async {
  try {
    final syncService = AutoLocationSyncService.instance;
    final backgroundWorker = BackgroundSyncWorker.instance;
    final cacheManager = LocationCacheManager.instance;

    // Initialize background worker only on supported platforms and when not in debug mode.
    // Workmanager and some platform background initializers can cause crashes on emulators
    // or during rapid local iteration. Skip background initialization in debug to keep
    // the app runnable while developing. This can be enabled for production builds.
    if (!kDebugMode && backgroundWorker.isBackgroundSyncSupported()) {
      try {
        await backgroundWorker.initialize();
      } catch (e) {
        print('❌ Background worker initialization skipped due to error: $e');
      }
    } else {
      print('⚠️ Skipping background worker initialization (debug/unsupported platform)');
    }

    // Initialize sync service with configuration (disable background tasks in debug)
    await syncService.initialize(
      config: AutoSyncConfig(
        baseUrl: ApiConfig.currentBaseUrl.replaceAll('/api/v1', ''), // Remove API prefix for sync endpoint
        offlineThreshold: const Duration(minutes: 15),
        syncTimeout: const Duration(seconds: 30),
        maxRetries: 3,
        retryDelay: const Duration(seconds: 5),
        enableBackgroundSync: !kDebugMode,
      ),
    );

    // Get stored auth token if exists
    final storedToken = await AuthService.getAuthToken();
    if (storedToken != null && storedToken.isNotEmpty) {
      syncService.setAuthToken(storedToken);
    }

    // Get current user if logged in
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser != null) {
      await cacheManager.setUserId(currentUser.id);
    }

    print('✅ Auto Location Sync initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Auto Location Sync: $e');
    // Don't block the app if auto-sync initialization fails
  }
}

class SafeTravelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Travel',
      theme: ThemeData(
        useMaterial3: true,
        // Professional Light Color Scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Soft indigo
          brightness: Brightness.light,
          primary: const Color(0xFF6366F1), // Soft indigo
          secondary: const Color(0xFF10B981), // Soft emerald
          surface: const Color(0xFFFAFBFC), // Very light gray
          background: const Color(0xFFFFFFFF), // Pure white
          error: const Color(0xFFFF6B6B), // Soft red for errors
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF374151), // Dark gray text
          onBackground: const Color(0xFF374151),
        ),
        fontFamily: 'SF Pro Text',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Professional App Bar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF374151),
          elevation: 0,
          scrolledUnderElevation: 1,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        // Professional Card Theme
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Professional Input Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        // Professional Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: MainApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainApp extends StatefulWidget {
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentScreen =
      0; // 0: signin, 1: signup, 2: email_verification, 3: home, 4: map, 5: sos, 6: contacts, 7: settings, 8: profile, 9: offline_sos, 10: emergency_contacts, 11: enhanced_sos
  User? _user;
  String _errorMessage = '';
  
  // Loading states
  bool _isLoading = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _initializeEmergencyService();
    
    // Remove splash screen after a short delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      FlutterNativeSplash.remove();
    });
  }

  /// Initialize the offline emergency service
  Future<void> _initializeEmergencyService() async {
    try {
      await IntegratedOfflineEmergencyService.instance.initialize();
      print('Offline emergency service initialized successfully');
    } catch (e) {
      print('Failed to initialize offline emergency service: $e');
    }
  }



  /// Quick authentication check - optimized for speed
  Future<void> _checkAuthenticationStatus() async {
    // Start with signin screen immediately, no loading
    setState(() {
      _currentScreen = 0;
    });

    // Check authentication in background without blocking UI
    _quickAuthCheck();
  }

  /// Background authentication check that doesn't block UI
  Future<void> _quickAuthCheck() async {
    try {
      // Quick local check first - no network calls
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) return; // Stay on signin

      // Check if token is obviously expired (local check)
      final isTokenExpired = await AuthService.isTokenExpired();
      if (isTokenExpired) {
        // Try silent refresh in background
        AuthService.refreshToken().then((result) {
          if (result.success && result.token != null) {
            AuthService.getCurrentUser().then((user) async {
              if (mounted && user != null) {
                // Update auto-sync with refreshed token
                await AutoSyncAuthManager.instance.onLoginSuccess(user, result.token!);
                
                setState(() {
                  _user = user;
                  _currentScreen = 2; // Navigate to home
                });
              }
            });
          }
        });
        return;
      }

      // Get cached user data if available
      final user = await AuthService.getCurrentUser();
      final token = await AuthService.getAuthToken();
      
      if (mounted && user != null && token != null) {
        // Restore auto-sync for existing session
        await AutoSyncAuthManager.instance.onLoginSuccess(user, token);
        
        setState(() {
          _user = user;
          _currentScreen = 2; // Navigate to home
        });
      }
    } catch (e) {
      // Silently fail - user stays on signin screen
      print('Background auth check failed: $e');
    }
  }

  void _navigateToScreen(int screen) {
    setState(() {
      _currentScreen = screen;
      _errorMessage = ''; // Clear any error messages
    });
  }

  Future<void> _handleSignin(String email, String password) async {
    // Clear any previous error and set loading state
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final result = await AuthService.signin(email, password);
      
      if (result.success && result.user != null && result.token != null) {
        // Setup auto-sync for the logged-in user
        await AutoSyncAuthManager.instance.onLoginSuccess(result.user!, result.token!);
        
        // Navigation on success with loading cleared
        setState(() {
          _user = result.user;
          _currentScreen = 2; // go to home (screen 2)
          _isLoading = false;
        });
      } else {
        // Show error and clear loading
        setState(() {
          _errorMessage = result.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignup(String name, String email, String phone, String password) async {
    // Clear any previous error immediately  
    setState(() {
      _errorMessage = '';
      _isRegistering = true;
    });

    try {
      // Directly create account without email verification
      final result = await AuthService.signup(name, email, phone, password);
      
      if (result.success && result.user != null && result.token != null) {
        // Setup auto-sync for the new user
        await AutoSyncAuthManager.instance.onLoginSuccess(result.user!, result.token!);
        
        // Navigate directly to home screen
        setState(() {
          _user = result.user;
          _isRegistering = false;
          _currentScreen = 2; // home screen
        });
      } else {
        setState(() {
          _isRegistering = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _errorMessage = 'Registration failed: ${e.toString()}';
      });
    }
  }





  Future<void> _handleSignout() async {
    try {
      // Clear auto-sync data before signing out
      await AutoSyncAuthManager.instance.onLogout();
      
      await AuthService.signout();
      
      // Clear user and navigate to signin screen
      setState(() {
        _user = null;
        _errorMessage = '';
      });
      
      // Navigate to signin screen (screen 0)
      _navigateToScreen(0);
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign out failed: ${e.toString()}';
      });
    }
  }

  Future<void> _updateUser(User user) async {
    try {
      final result = await AuthService.updateUserProfile(user);
      
      if (result.success && result.user != null) {
        setState(() {
          _user = result.user;
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Profile update failed: ${e.toString()}';
      });
    }
  }

  Widget _buildCurrentScreen() {
    // No loading screen - show requested screen immediately
    switch (_currentScreen) {
    case 0:
      return SigninScreen(
        onSignin: _handleSignin,
        onNavigateToSignup: () => _navigateToScreen(1),
        isLoading: _isLoading,
        errorMessage: _errorMessage,
      );
    case 1:
      return SignUpScreen(
        onSignup: _handleSignup,
        onNavigateToSignin: () => _navigateToScreen(0),
        isLoading: _isRegistering,
        errorMessage: _errorMessage,
      );

    case 2:
      return HomeScreen(
        user: _user,
        onNavigate: _navigateToScreen,
      );
    case 3:
      return MapScreen(
        onNavigate: _navigateToScreen,
        onTriggerSOS: () => _navigateToScreen(4),
      );
    case 4:
      return SOSConfirmationScreen(
        user: _user,
        onNavigate: _navigateToScreen,
      );
    case 5:
      return EmergencyScreen(
        onNavigate: _navigateToScreen,
      );
    case 6:
      return SettingsScreen(
        onNavigate: _navigateToScreen,
        onSignout: _handleSignout,
      );
    case 7:
      return ProfileScreen(
        user: _user,
        onUpdateUser: _updateUser,
        onNavigate: _navigateToScreen,
      );
    case 8:
      return LocationStorageDemoScreen();
    case 9:
      return const OfflineSOSScreen();
    case 10:
      return OfflineEmergencyContactsScreen(
        onNavigate: _navigateToScreen,
      );
    case 11:
      return EnhancedOfflineSOSScreen(
        onNavigate: _navigateToScreen,
      );
    case 12:
      return TripsScreen(
        userId: _user?.id ?? '',
      );
    default:
      return SigninScreen(
        onSignin: _handleSignin,
        onNavigateToSignup: () => _navigateToScreen(1),
        isLoading: false, // No more loading states
        errorMessage: _errorMessage,
      );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
    );
  }
}
