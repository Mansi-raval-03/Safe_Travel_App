import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import 'package:safe_travel_app/screens/bottom_navigation_bar.dart';
import 'package:safe_travel_app/screens/home/home_screen.dart';

class EmergencyAssistanceScreen extends StatefulWidget {
  @override
  _EmergencyAssistanceScreenState createState() => _EmergencyAssistanceScreenState();
}

class _EmergencyAssistanceScreenState extends State<EmergencyAssistanceScreen> {
  bool shareWithContacts = true;
  bool shareWithMechanics = false;
  bool shareWithTowing = true;

  GoogleMapController? _mapController;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location services are disabled.")),
      );
      return;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _sendCustomMessage() {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location not available")),
      );
      return;
    }

    String googleMapsLink =
        "https://www.google.com/maps?q=${_currentLocation!.latitude},${_currentLocation!.longitude}";

    String message =
        "🚨 I need help! My current location is: $googleMapsLink\n\n"
        "Share with:\n"
        "${shareWithContacts ? "- Emergency Contacts\n" : ""}"
        "${shareWithMechanics ? "- Nearby Mechanics\n" : ""}"
        "${shareWithTowing ? "- Towing Service\n" : ""}";

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Message Sent!")),
    );

    // Share via system share sheet
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Assistance'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen()),
            );
          },
        ),
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
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: _currentLocation == null
                  ? Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation!,
                          zoom: 15,
                        ),
                        myLocationEnabled: true,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        markers: {
                          Marker(
                            markerId: MarkerId("currentLocation"),
                            position: _currentLocation!,
                            infoWindow: InfoWindow(title: "You are here"),
                          ),
                        },
                      ),
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
                _currentLocation == null
                    ? "Fetching your location..."
                    : "I need help! My current location is "
                      "https://www.google.com/maps?q=${_currentLocation!.latitude},${_currentLocation!.longitude}",
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
              secondary: Icon(Icons.contacts),
              value: shareWithContacts,
              onChanged: (val) => setState(() => shareWithContacts = val!),
            ),
            CheckboxListTile(
              title: Text('Nearby Mechanics'),
              secondary: Icon(Icons.build),
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
              onPressed: _sendCustomMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ), 
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                elevation: 0,
                shadowColor: Colors.transparent,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Send Custom Message'),
            ),
          ],
        ),
      ),
    );
  }

  static const sizedBox20 = SizedBox(height: 20);
}
