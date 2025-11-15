import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/responsive.dart';

class AlertMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String senderName;

  const AlertMapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.senderName,
  }) : super(key: key);

  @override
  _AlertMapScreenState createState() => _AlertMapScreenState();
}

class _AlertMapScreenState extends State<AlertMapScreen> {
  late CameraPosition _initialPosition;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initialPosition = CameraPosition(
      target: LatLng(widget.latitude, widget.longitude),
      zoom: 16.0,
    );
    _markers.add(Marker(
      markerId: const MarkerId('alert_sender'),
      position: LatLng(widget.latitude, widget.longitude),
      infoWindow: InfoWindow(title: widget.senderName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Location',
          style: TextStyle(fontSize: Responsive.s(context, 18)),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        markers: _markers,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }
}
