import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({Key? key}) : super(key: key);

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String? _location;
  bool _isStoring = false;
  bool _isNotifying = false;
  String _status = '';

  Future<void> _getLocation() async {
    setState(() {
      _status = 'Getting location...';
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _location = '${position.latitude}, ${position.longitude}';
        _status = 'Location acquired!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to get location';
      });
    }
  }

  Future<void> _storeAndNotify() async {
    if (_location == null) {
      setState(() {
        _status = 'Please get location first';
      });
      return;
    }
    setState(() {
      _isStoring = true;
      _isNotifying = true;
      _status = 'Storing location and notifying contacts...';
    });

    // Simulate storing location (e.g., to a database)
    await Future.delayed(const Duration(seconds: 1));

    // Simulate notifying emergency contacts (e.g., via SMS or push notification)
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isStoring = false;
      _isNotifying = false;
      _status = 'Emergency contacts notified!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            Text(
              'SOS Emergency',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Get Location'),
              onPressed: _getLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Store + Notify Emergency Contacts'),
              onPressed: (_isStoring || _isNotifying) ? null : _storeAndNotify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (_location != null)
              Text(
                'Current Location: $_location',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            const Divider(),
            const Text(
              'Emergency contacts will receive your location alert.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}