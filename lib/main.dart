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
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Text',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
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
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthenticationStatus() async {
    try {
      final isAuthenticated = await AuthService.isAuthenticated();
      final isTokenExpired = await AuthService.isTokenExpired();
      
      if (isAuthenticated && !isTokenExpired) {
        // User is authenticated with valid token
        final user = await AuthService.getCurrentUser();
        setState(() {
          _user = user;
          _currentScreen = user != null ? 2 : 0; // home or signin
          _isLoading = false;
        });
      } else if (isAuthenticated && isTokenExpired) {
        // Try to refresh token
        final refreshResult = await AuthService.refreshToken();
        if (refreshResult.success) {
          final user = await AuthService.getCurrentUser();
          setState(() {
            _user = user;
            _currentScreen = user != null ? 2 : 0;
            _isLoading = false;
          });
        } else {
          // Refresh failed, show signin
          setState(() {
            _user = null;
            _currentScreen = 0;
            _isLoading = false;
          });
        }
      } else {
        // Not authenticated, show signin
        setState(() {
          _user = null;
          _currentScreen = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error checking auth, default to signin
      setState(() {
        _user = null;
        _currentScreen = 0;
        _isLoading = false;
        _errorMessage = 'Authentication check failed: ${e.toString()}';
      });
    }
  }

  void _navigateToScreen(int screen) {
    setState(() {
      _currentScreen = screen;
      _errorMessage = ''; // Clear any error messages
    });
  }

  Future<void> _handleSignin(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await AuthService.signin(email, password);
      
      if (result.success && result.user != null) {
        setState(() {
          _user = result.user;
          _currentScreen = 2; // go to home
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign in failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignup(String name, String email, String phone, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await AuthService.signup(name, email, phone, password);
      
      if (result.success && result.user != null) {
        setState(() {
          _user = result.user;
          _currentScreen = 2; // go to home
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign up failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.signout();
      setState(() {
        _user = null;
        _currentScreen = 0; // back to signin
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign out failed: ${e.toString()}';
      });
    }
  }

  Future<void> _updateUser(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.updateUserProfile(user);
      
      if (result.success && result.user != null) {
        setState(() {
          _user = result.user;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Profile update failed: ${e.toString()}';
      });
    }
  }

  Widget _buildCurrentScreen() {
    // Show loading screen during initial authentication check
    if (_isLoading && _user == null && _currentScreen == 0) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        isLoading: _isLoading,
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
        isLoading: _isLoading,
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
