import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/home/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  profileScreen createState() => profileScreen();
}

class profileScreen extends State<ProfileScreen> {
  String vehicleType = 'Motorcycle';
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emergencyContactController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Complete Your Profile")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: vehicleType == 'Car'
                  ? TextEditingController(text: 'Car')
                  : vehicleType == 'Motorcycle'
                      ? TextEditingController(text: 'Motorcycle')
                      : TextEditingController(text: 'Bicycle'),
              decoration: InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
              readOnly: true,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: Icon(Icons.directions_car),
                  selected: vehicleType == 'Car',
                  onSelected: (_) => setState(() => vehicleType = 'Car'),
                ),
                SizedBox(width: 10),
                ChoiceChip(
                  label: Icon(Icons.motorcycle),
                  selected: vehicleType == 'Motorcycle',
                  onSelected: (_) => setState(() => vehicleType = 'Motorcycle'),
                ),
                SizedBox(width: 10),
                ChoiceChip(
                  label: Icon(Icons.pedal_bike),
                  selected: vehicleType == 'Bicycle',
                  onSelected: (_) => setState(() => vehicleType = 'Bicycle'),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: emergencyContactController,
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact',
                    border: OutlineInputBorder(),
                  ),
                )),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    
                  },
                  child: Text('Add Contact'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
              },
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              child: Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}