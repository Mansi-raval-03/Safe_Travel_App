import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/nearby_services_controller.dart';
import '../models/place_model.dart';

class NearbyEmergencyServicesMap extends StatefulWidget {
  const NearbyEmergencyServicesMap({Key? key}) : super(key: key);

  @override
  State<NearbyEmergencyServicesMap> createState() => _NearbyEmergencyServicesMapState();
}

class _NearbyEmergencyServicesMapState extends State<NearbyEmergencyServicesMap> {
  final NearbyServicesController _controller = NearbyServicesController();
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();

  Set<Marker> _markers = {};
  bool _mapReady = false;
  bool _permissionGranted = true;
  bool _loading = true;
  List<PlaceModel> _places = [];

  StreamSubscription<List<PlaceModel>>? _placesSub;
  StreamSubscription<bool>? _loadingSub;

  static const CameraPosition _initialCamera = CameraPosition(target: LatLng(0,0), zoom: 14);

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(() {
      _controller.search(_searchController.text);
    });
  }

  Future<void> _init() async {
    final ok = await _controller.ensurePermission();
    if (!ok) {
      setState(() { _permissionGranted = false; _loading = false; });
      return;
    }
    _placesSub = _controller.placesStream.listen((places) {
      setState(() { _places = places; _updateMarkers(); });
    });
    _loadingSub = _controller.loadingStream.listen((v) { setState(() { _loading = v; }); });
    _controller.startListening();
    // initial fetch - wait a moment for position to be available
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_controller.lastPosition != null) {
        await _controller.fetchNearbyServicesForPosition(_controller.lastPosition!);
        _moveCameraToPosition(_controller.lastPosition!);
      } else {
        // try to get current
        try {
          final pos = await _controller.getCurrentPosition();
          await _controller.fetchNearbyServicesForPosition(pos);
          _moveCameraToPosition(pos);
        } catch (_) {}
      }
    });
  }

  Future<void> _moveCameraToPosition(position) async {
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14));
    } catch (_) {}
  }

  void _updateMarkers() {
    final Set<Marker> markers = {};
    for (final p in _places) {
      final mid = MarkerId(p.placeId);
      final marker = Marker(
        markerId: mid,
        position: p.location,
        infoWindow: InfoWindow(
          title: p.name,
          snippet: p.address ?? (p.distanceMeters != null ? '${(p.distanceMeters! / 1000).toStringAsFixed(2)} km' : null),
          onTap: () => _onMarkerTap(p),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _onMarkerTap(p),
      );
      markers.add(marker);
    }
    setState(() { _markers = markers; });
  }

  Future<void> _onMarkerTap(PlaceModel p) async {
    // show bottom sheet with details
    showModalBottomSheet(context: context, builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (p.address != null) Text(p.address!),
            const SizedBox(height: 8),
            Text(p.distanceMeters != null ? '${(p.distanceMeters! / 1000).toStringAsFixed(2)} km away' : ''),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openDirections(p),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // center map on marker
                    final controller = await _mapController.future;
                    await controller.animateCamera(CameraUpdate.newLatLngZoom(p.location, 16));
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Center'),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openDirections(PlaceModel p) async {
    final lat = p.location.latitude;
    final lng = p.location.longitude;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _loadingSub?.cancel();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Emergency Services'),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_permissionGranted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 56),
            const SizedBox(height: 12),
            const Text('Location permission denied'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () async {
              await _controller.openAppSettings();
            }, child: const Text('Open app settings'))
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: _markers,
          onMapCreated: (c) {
            if (!_mapController.isCompleted) _mapController.complete(c);
            setState(() { _mapReady = true; _loading = false; });
          },
          onTap: (_) {},
        ),
        Positioned(top: 12, left: 12, right: 12, child: _buildSearchBar()),
        if (_loading) const Center(child: CircularProgressIndicator()),
        Positioned(bottom: 16, left: 12, right: 12, child: _buildPlacesList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search nearby services...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPlacesList() {
    if (_loading && _places.isEmpty) return const SizedBox.shrink();
    if (_places.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
        child: const Text('No services found near you'),
      );
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        itemCount: _places.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = _places[index];
          return GestureDetector(
            onTap: () async {
              final controller = await _mapController.future;
              await controller.animateCamera(CameraUpdate.newLatLngZoom(p.location, 16));
            },
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(p.address ?? ''),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.distanceMeters != null ? '${(p.distanceMeters! / 1000).toStringAsFixed(2)} km' : ''),
                      ElevatedButton(onPressed: () => _openDirections(p), child: const Text('Directions')),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
