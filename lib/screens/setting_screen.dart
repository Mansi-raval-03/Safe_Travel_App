import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final Function(int) onNavigate;
  final VoidCallback onSignout;

  const SettingsScreen({
    super.key,
    required this.onNavigate,
    required this.onSignout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => onNavigate(7), // Navigate to Profile screen
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('Emergency Contacts'),
            onTap: () => onNavigate(5), // Navigate to Contacts screen
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out',
                style: TextStyle(color: Colors.red)),
            onTap: onSignout, // Call signout function
          ),
        ],
      ),
    );
  }
}
