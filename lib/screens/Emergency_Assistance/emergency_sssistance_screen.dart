import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/bottom_navigation_bar.dart';

class EmergencyAssistanceScreen extends StatefulWidget {
  @override
  _EmergencyAssistanceScreenState createState() => _EmergencyAssistanceScreenState();
}

class _EmergencyAssistanceScreenState extends State<EmergencyAssistanceScreen> {
  bool shareWithContacts = true;
  bool shareWithMechanics = false;
  bool shareWithTowing = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Assistance'),
        leading: IconButton(icon: Icon(Icons.menu), onPressed: () {}),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: CircleAvatar(child: Icon(Icons.person)),
          )
        ],
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 2),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 180,
              color: Colors.grey[300],
              child: Stack(
                children: [
                  Center(child: Text('Map Placeholder')),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Icon(Icons.wifi_tethering, color: Colors.red),
                  )
                ],
              ),
            ),
            sizedBox20,
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'I need help! My current location is [link to Google Maps with live coordinates].',
                style: TextStyle(fontSize: 16),
              ),
            ),
            sizedBox20,
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Share with:', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            CheckboxListTile(
              title: Text('Emergency Contacts'),
              secondary: Icon(Icons.build),
              value: shareWithContacts,
              onChanged: (val) => setState(() => shareWithContacts = val!),
            ),
            CheckboxListTile(
              title: Text('Nearby Mechanics'),
              secondary: Icon(Icons.local_shipping),
              value: shareWithMechanics,
              onChanged: (val) => setState(() => shareWithMechanics = val!),
            ),
            CheckboxListTile(
              title: Text('Towing Service'),
              secondary: Icon(Icons.local_shipping),
              value: shareWithTowing,
              onChanged: (val) => setState(() => shareWithTowing = val!),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Send custom message logic
              },
              child: Text('Send Custom Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const sizedBox20 = SizedBox(height: 20);
}