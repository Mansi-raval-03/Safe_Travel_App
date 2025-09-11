import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/Emergency_Assistance/emergency_sssistance_screen.dart';
import 'package:safe_travel_app/screens/Location/nearby_location_screen.dart';
import 'package:safe_travel_app/screens/bottom_navigation_bar.dart';

class HomeScreen extends StatelessWidget {
  void _navigateToNearbyMechanics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NearbyLocationScreen()),
    );
  }

  void _navigateToEmergencyAssistance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmergencyAssistanceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Safe Travel App"),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
        ],
        leading: Icon(Icons.shield, color: Colors.blue),
      ),
      body: Padding(
        padding: EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _navigateToEmergencyAssistance(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
                shadowColor: Colors.redAccent,
                elevation: 10,
                fixedSize: Size(150, 150),
                shape: CircleBorder(),
                textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              child: Text('HELP ME'),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _navigateToNearbyMechanics(context),
              icon: Icon(Icons.build),
              label: Text('Nearby Mechanics'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.local_shipping),
              label: Text('Towing Service'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.local_shipping),
              label: Text('Towing Service'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.location_on),
              label: Text('Share Live Location'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.timer),
              label: Text('Set Arrival Timer'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 0),
    );
  }
}
