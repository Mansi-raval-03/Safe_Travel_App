import 'package:flutter/material.dart';
import '../screens/offline_emergency_contacts_screen.dart';
import '../screens/enhanced_offline_sos_screen.dart';

/// Navigation Integration Helper for Offline Emergency Features
/// 
/// This class provides integration points to add the new offline emergency
/// screens to the main app navigation system.
class OfflineEmergencyNavigation {
  
  /// Creates a navigation page for emergency contacts
  /// Call this method in your main navigation to add the emergency contacts screen
  static Widget createEmergencyContactsPage({
    Function(int)? onNavigate,
  }) {
    return OfflineEmergencyContactsScreen(
      onNavigate: onNavigate,
    );
  }

  /// Creates a navigation page for enhanced SOS functionality  
  /// Call this method in your main navigation to add the enhanced SOS screen
  static Widget createEnhancedSOSPage({
    Function(int)? onNavigate,
  }) {
    return EnhancedOfflineSOSScreen(
      onNavigate: onNavigate,
    );
  }

  /// Gets the navigation route configuration for main app integration
  /// Use this to configure routes in your app router
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/emergency-contacts': (context) => const OfflineEmergencyContactsScreen(),
      '/enhanced-sos': (context) => const EnhancedOfflineSOSScreen(),
    };
  }

  /// Navigation helper to open emergency contacts screen
  static void navigateToEmergencyContacts(
    BuildContext context, {
    Function(int)? onNavigate,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OfflineEmergencyContactsScreen(
          onNavigate: onNavigate,
        ),
      ),
    );
  }

  /// Navigation helper to open enhanced SOS screen
  static void navigateToEnhancedSOS(
    BuildContext context, {
    Function(int)? onNavigate,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedOfflineSOSScreen(
          onNavigate: onNavigate,
        ),
      ),
    );
  }

  /// Integration configuration for main.dart
  /// This provides guidance for integrating with the existing main app
  static String getMainDartIntegrationGuide() {
    return '''
// MAIN.DART INTEGRATION GUIDE
// ===========================

// 1. IMPORT THE NAVIGATION HELPER
import 'navigation/offline_emergency_navigation.dart';

// 2. UPDATE YOUR MAIN APP NAVIGATION
// In your main app where you handle screen navigation (typically main.dart):

// Example integration in main.dart screen navigation:
List<Widget> _pages = [
  // ... existing pages ...
  
  // Add these new offline emergency pages:
  OfflineEmergencyNavigation.createEmergencyContactsPage(
    onNavigate: (index) => setState(() => _selectedIndex = index),
  ), // Index 5 - Emergency Contacts
  
  OfflineEmergencyNavigation.createEnhancedSOSPage(
    onNavigate: (index) => setState(() => _selectedIndex = index),
  ), // Index 6 - Enhanced SOS
];

// 3. UPDATE BOTTOM NAVIGATION BAR (if using one)
// Add these items to your BottomNavigationBar:

const BottomNavigationBarItem(
  icon: Icon(Icons.contacts),
  label: 'Emergency Contacts',
), // Index 5

const BottomNavigationBarItem(
  icon: Icon(Icons.sos),
  label: 'SOS Alert',
), // Index 6

// 4. EXAMPLE COMPLETE INTEGRATION
// Here's how to modify your existing main.dart:

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  
  List<Widget> get _pages => [
    // Your existing pages (0-4)...
    HomeScreen(onNavigate: _navigateToPage),
    MapScreen(onNavigate: _navigateToPage),
    // ... other existing screens ...
    
    // Add new offline emergency screens
    OfflineEmergencyNavigation.createEmergencyContactsPage(
      onNavigate: _navigateToPage,
    ), // Index 5
    
    OfflineEmergencyNavigation.createEnhancedSOSPage(
      onNavigate: _navigateToPage,
    ), // Index 6
  ];
  
  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _navigateToPage,
        items: [
          // Your existing navigation items...
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          // ... other existing items ...
          
          // Add new emergency navigation items
          const BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            label: 'Emergency',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'SOS',
          ),
        ],
      ),
    );
  }
}

// 5. ALTERNATIVE: DRAWER NAVIGATION
// If you're using a drawer instead of bottom nav:

Drawer(
  child: ListView(
    children: [
      // ... existing drawer items ...
      
      ListTile(
        leading: const Icon(Icons.contacts),
        title: const Text('Emergency Contacts'),
        onTap: () {
          Navigator.pop(context);
          _navigateToPage(5);
        },
      ),
      ListTile(
        leading: const Icon(Icons.sos),
        title: const Text('SOS Alert'),
        onTap: () {
          Navigator.pop(context);
          _navigateToPage(6);
        },
      ),
    ],
  ),
)

// 6. INITIALIZE EMERGENCY SERVICE
// In your main app initialization, add:

@override
void initState() {
  super.initState();
  
  // Initialize offline emergency service
  IntegratedOfflineEmergencyService.instance.initialize().catchError((e) {
    print('Failed to initialize emergency service: \$e');
  });
}

''';
  }

  /// Screen index constants for main app integration
  static const int emergencyContactsIndex = 5;
  static const int enhancedSOSIndex = 6;

  /// Recommended navigation items for bottom navigation bar
  static List<BottomNavigationBarItem> getRecommendedNavItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.contacts_outlined),
        activeIcon: Icon(Icons.contacts),
        label: 'Emergency Contacts',
        tooltip: 'Manage offline emergency contacts',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.emergency_outlined),
        activeIcon: Icon(Icons.emergency),
        label: 'SOS Alert',
        tooltip: 'Send emergency SOS with live location',
      ),
    ];
  }

  /// Drawer items for drawer navigation
  static List<Widget> getDrawerItems({
    required Function(int) onNavigate,
    required BuildContext context,
  }) {
    return [
      ListTile(
        leading: const Icon(Icons.contacts),
        title: const Text('Emergency Contacts'),
        subtitle: const Text('Manage offline contacts'),
        onTap: () {
          Navigator.pop(context);
          onNavigate(emergencyContactsIndex);
        },
      ),
      ListTile(
        leading: const Icon(Icons.emergency),
        title: const Text('SOS Alert'),
        subtitle: const Text('Send emergency alert'),
        onTap: () {
          Navigator.pop(context);
          onNavigate(enhancedSOSIndex);
        },
      ),
    ];
  }

  /// Quick access floating action button for SOS
  static Widget createSOSFloatingActionButton({
    required BuildContext context,
    Function(int)? onNavigate,
  }) {
    return FloatingActionButton.extended(
      onPressed: () {
        if (onNavigate != null) {
          onNavigate(enhancedSOSIndex);
        } else {
          navigateToEnhancedSOS(context, onNavigate: onNavigate);
        }
      },
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.emergency),
      label: const Text('SOS'),
      tooltip: 'Send emergency SOS alert',
    );
  }

  /// App bar actions for emergency features
  static List<Widget> getAppBarActions({
    required BuildContext context,
    Function(int)? onNavigate,
  }) {
    return [
      IconButton(
        icon: const Icon(Icons.contacts),
        tooltip: 'Emergency Contacts',
        onPressed: () {
          if (onNavigate != null) {
            onNavigate(emergencyContactsIndex);
          } else {
            navigateToEmergencyContacts(context, onNavigate: onNavigate);
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.emergency),
        tooltip: 'SOS Alert',
        onPressed: () {
          if (onNavigate != null) {
            onNavigate(enhancedSOSIndex);
          } else {
            navigateToEnhancedSOS(context, onNavigate: onNavigate);
          }
        },
      ),
    ];
  }
}