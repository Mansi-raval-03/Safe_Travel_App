import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  final Location _location = Location();

  final LatLng _destination =
      const LatLng(37.42796133580664, -122.085749655962);

  final List<Marker> _landmarkMarkers = [
    Marker(
      markerId: MarkerId('hospital'),
      position: LatLng(37.429, -122.088),
      infoWindow: InfoWindow(title: 'Hospital'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: MarkerId('police'),
      position: LatLng(37.426, -122.083),
      infoWindow: InfoWindow(title: 'Police Station'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ),
    Marker(
      markerId: MarkerId('fuel'),
      position: LatLng(37.428, -122.087),
      infoWindow: InfoWindow(title: 'Fuel Station'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
  ];

  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    final permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      final requestResult = await _location.requestPermission();
      if (requestResult != PermissionStatus.granted) return;
    }

    final loc = await _location.getLocation();
    if (!mounted) return;
    setState(() {
      _currentLocation = loc;
    });

    _location.onLocationChanged.listen((newLoc) {
      if (!mounted) return;
      setState(() {
        _currentLocation = newLoc;
      });
      _updateRoute();
    });

    _updateRoute();
  }

  void _updateRoute() {
    if (_currentLocation == null) return;
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: [
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            _destination,
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLatLng = _currentLocation == null
        ? _destination
        : LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);

    final Set<Marker> markers = {
      ..._landmarkMarkers,
      if (_currentLocation != null)
        Marker(
          markerId: const MarkerId('user'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Travel Map'),
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: userLatLng,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              markers: markers,
              polylines: _polylines,
            ),
    );
  }
}
