import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/bottom_navigation_bar.dart';
import 'package:safe_travel_app/screens/home/home_screen.dart';

class NearbyLocationScreen extends StatelessWidget {
  final List<Map<String, dynamic>> mechanics = [
    {
      'name': 'Roadside Repair Pros',
      'status': 'Available',
      'distance': '2.5 miles',
      'time': '5 min away',
      'icon': Icons.build,
      'actions': ['Call'],
    },
    {
      'name': 'Quick-Fix Auto',
      'status': 'Busy',
      'distance': '2.5 miles',
      'time': '5 min away',
      'icon': Icons.build,
      'actions': ['Chat'],
    },
    {
      'name': 'Mobile Mechanics Hub',
      'status': 'Available',
      'distance': '2.5 miles',
      'time': '5 min away',
      'icon': Icons.build,
      'actions': ['Chat'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Mechanics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen()),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 1),
      body: Column(
        children: [
          Container(
            height: 200,
            color: Colors.grey[300],
            child: Center(child: Text("Map Placeholder")),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Mechanics',
                  style: TextStyle(
                    fontSize: screenHeight < 700 ? 18 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text('See All'),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Flexible(
            
            child: Expanded(
              child: ListView.builder(
                itemCount: mechanics.length,
                itemBuilder: (context, index) {
                  final mechanic = mechanics[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: ListTile(
                      leading: Icon(mechanic['icon'], color: Colors.green),
                      title: Row(
                        children: [
                          Text(mechanic['name']),
                          SizedBox(width: 10),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mechanic['status'] == 'Available'
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              mechanic['status'],
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      subtitle:
                          Text('${mechanic['time']} - ${mechanic['distance']}'),
                      trailing: ElevatedButton.icon(
                        icon: Icon(
                          mechanic['actions'][0] == 'Call'
                              ? Icons.call
                              : Icons.chat,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          foregroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: Text(mechanic['actions'][0]),
                        onPressed: () {},
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
