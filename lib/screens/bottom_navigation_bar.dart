import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/Location/nearby_location_screen.dart';
import 'package:safe_travel_app/screens/home/home_screen.dart';
import 'package:safe_travel_app/screens/profile/profile_screen.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  const BottomNavBar({super.key, required this.selectedIndex});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    void onItemTapped(int index) {
      switch (index) {
        case 0:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
          break;
        case 1:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NearbyLocationScreen()));
          break;
        case 2:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
          break;
      }
    }

    return BottomNavigationBar(
      currentIndex: widget.selectedIndex,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}