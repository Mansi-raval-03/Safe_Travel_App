import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_travel_app/models/emergency_screen.dart';
import 'package:safe_travel_app/screens/setting_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sos_confirmation_screen.dart';
import 'screens/profile_screen.dart';
import 'models/user.dart';
import 'services/auth_service.dart';

void main() {
  runApp(SafeTravelApp());
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
      0; // 0: signin, 1: signup, 2: home, 3: map, 4: sos, 5: contacts, 6: settings, 7: profile
  User? _user;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
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
          if (result.success) {
            AuthService.getCurrentUser().then((user) {
              if (mounted && user != null) {
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
      if (mounted && user != null) {
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
    // Clear any previous error immediately
    setState(() {
      _errorMessage = '';
    });

    try {
      final result = await AuthService.signin(email, password);
      
      if (result.success && result.user != null) {
        // Immediate navigation on success
        setState(() {
          _user = result.user;
          _currentScreen = 2; // go to home
        });
      } else {
        // Show error without loading state
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign in failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignup(String name, String email, String phone, String password) async {
    // Clear any previous error immediately  
    setState(() {
      _errorMessage = '';
    });

    try {
      final result = await AuthService.signup(name, email, phone, password);
      
      if (result.success && result.user != null) {
        // Immediate navigation on success
        setState(() {
          _user = result.user;
          _currentScreen = 2; // go to home
        });
      } else {
        // Show error without loading state
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign up failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignout() async {
    try {
      await AuthService.signout();
      setState(() {
        _user = null;
        _currentScreen = 0; // back to signin
        _errorMessage = '';
      });
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
        isLoading: false, // No more loading states
        errorMessage: _errorMessage,
      );
    case 1:
      return SignUpScreen(
        onSignup: _handleSignup,
        onNavigateToSignin: () => _navigateToScreen(0),
        isLoading: false, // No more loading states
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
