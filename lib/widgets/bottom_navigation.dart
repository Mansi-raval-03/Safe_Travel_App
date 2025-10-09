import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Map screen indices to bottom navigation indices
    int getBottomNavIndex() {
      switch (currentIndex) {
        case 2: return 0; // Home screen
        case 3: return 1; // Map screen  
        case 4: return 2; // SOS screen
        case 5: return 3; // Contacts screen
        case 7: return 4; // Profile screen
        case 6: return 0; // Settings screen - default to Home
        default: return 0; // Default to Home
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000), // Very subtle shadow
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0), // Light border
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: getBottomNavIndex(),
        onTap: (index) {
          // Map bottom nav indices to screen indices
          final screenMap = {
            0: 2, // Home
            1: 3, // Map
            2: 4, // SOS
            3: 5, // Contacts
            4: 7, // Profile
          };
          onNavigate(screenMap[index] ?? 2);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6366F1), // Professional indigo
        unselectedItemColor: const Color(0xFF9CA3AF), // Professional gray
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B), // Softer emergency red
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            label: 'SOS',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Contacts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}