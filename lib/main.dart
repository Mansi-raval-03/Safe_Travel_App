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

  List<EmergencyContact> _emergencyContacts = [
    EmergencyContact(
        id: '1', name: 'John Doe', phone: '+1234567890', relationship: 'Father'),
    EmergencyContact(
        id: '2',
        name: 'Jane Smith',
        phone: '+0987654321',
        relationship: 'Mother'),
    EmergencyContact(
        id: '3',
        name: 'Mike Johnson',
        phone: '+1122334455',
        relationship: 'Brother'),
  ];

  void _navigateToScreen(int screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  void _handleSignin(String email, String password) {
    setState(() {
      _user = User(
        id: '1',
        name: 'Alex Thompson',
        email: email,
        phone: '+1234567890',
      );
      _currentScreen = 2; // go to home
    });
  }

  void _handleSignup(String email, String password) {
    setState(() {
      _user = User(
        id: '1',
        name: 'New User',
        email: email,
        phone: '+0000000000',
      );
      _currentScreen = 2; // go to home
    });
  }

  void _handleSignout() {
    setState(() {
      _user = null;
      _currentScreen = 0; // back to signin
    });
  }

  void _updateUser(User user) {
    setState(() {
      _user = user;
    });
  }

  void _updateEmergencyContacts(List<EmergencyContact> contacts) {
    setState(() {
      _emergencyContacts = contacts;
    });
  }

  Widget _buildCurrentScreen() {
  switch (_currentScreen) {
    case 0:
      return SigninScreen(
        onSignin: _handleSignin,
        onNavigateToSignup: () => _navigateToScreen(1),
      );
    case 1:
      return SignUpScreen(
        onSignup: _handleSignup,
        onNavigateToSignin: () => _navigateToScreen(0),
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
        emergencyContacts: _emergencyContacts,
        onNavigate: _navigateToScreen,
      );
    case 5:
      return EmergencyScreen(
        contacts: _emergencyContacts,
        onUpdateContacts: _updateEmergencyContacts,
        onNavigate: _navigateToScreen, id: '', name: '', phone: '', relationship: '',
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
