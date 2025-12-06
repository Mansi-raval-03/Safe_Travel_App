import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../widgets/bottom_navigation.dart';

class MapScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onTriggerSOS;

  const MapScreen({
    Key? key,
    required this.onNavigate,
    required this.onTriggerSOS,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  final Set<Circle> _circles = <Circle>{};
  final Set<Polyline> _polylines = <Polyline>{};
  final List<LatLng> _pathPoints = <LatLng>[];
  static const int _maxPathPoints = 1000;

  bool _followLocation = true;
  double _lastHeading = 0.0;
  String? mapStyle;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      debugPrint('Map style not found: $e');
    }
  }

  Future<void> _initLocation() async {
    try {
      final ok = await LocationService().initialize();
      if (!ok) return;

      final pos = LocationService().currentPosition ?? await LocationService().getCurrentLocation();
      if (!mounted || pos == null) return;

      setState(() => _currentPosition = pos);
      _moveCamera(LatLng(pos.latitude, pos.longitude), zoom: 16);
      _updateOverlays();

      _positionSubscription = LocationService().locationStream.listen((Position p) {
        if (!mounted) return;
        setState(() {
          _currentPosition = p;
          _lastHeading = p.heading;
          _pathPoints.add(LatLng(p.latitude, p.longitude));
          if (_pathPoints.length > _maxPathPoints) {
            _pathPoints.removeAt(0);
          }
        });

        _updateOverlays();

        if (_followLocation && _mapController.isCompleted) {
          _mapController.future.then((GoogleMapController controller) async {
            try {
              await controller.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng(p.latitude, p.longitude),
                17,
              ));
            } catch (_) {}
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  void _updateOverlays() {
    if (!mounted) return;

    _markers.clear();
    _circles.clear();
    _polylines.clear();

    if (_currentPosition != null) {
      final markerId = const MarkerId('user_location');
      _markers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: _lastHeading,
        anchor: const Offset(0.5, 0.5),
      );

      final acc = _currentPosition!.accuracy;
      final primary = Theme.of(context).colorScheme.primary;
      _circles.add(Circle(
        circleId: const CircleId('accuracy'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: acc > 1 ? acc : 8.0,
        strokeColor: primary.withOpacity(0.9),
        strokeWidth: 2,
        fillColor: primary.withOpacity(0.12),
      ));
    }

    if (_pathPoints.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('path'),
        points: List<LatLng>.from(_pathPoints),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    setState(() {});
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 16}) async {
    final controller = await _mapController.future;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                zoomControlsEnabled: false,
                markers: Set<Marker>.of(_markers.values),
                circles: _circles,
                polylines: _polylines,
                onTap: (_) {
                  if (_followLocation) {
                    setState(() => _followLocation = false);
                  }
                },
                onMapCreated: (GoogleMapController controller) async {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  if (mapStyle != null) {
                    try {
                      await controller.setMapStyle(mapStyle);
                    } catch (e) {
                      debugPrint('Failed to set map style: $e');
                    }
                  }
                  if (_currentPosition != null) {
                    try {
                      await controller.moveCamera(CameraUpdate.newLatLngZoom(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        17,
                      ));
                    } catch (_) {}
                  }
                },
              ),
            ),

            // Top search bar
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search or enter a place',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          onSubmitted: (_) {},
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Recenter + follow controls
            Positioned(
              right: 16,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'follow_toggle',
                    onPressed: () => setState(() => _followLocation = !_followLocation),
                    backgroundColor: Colors.white,
                    child: Icon(
                      _followLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: Colors.black87,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'recenter',
                    onPressed: () async {
                      if (_currentPosition != null) {
                        setState(() => _followLocation = true);
                        await _moveCamera(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          zoom: 17,
                        );
                      } else {
                        await _initLocation();
                      }
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Center crosshair overlay
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Center(
                  child: Icon(
                    Icons.add_location_alt,
                    color: Colors.black38.withOpacity(0.6),
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 3,
        onNavigate: widget.onNavigate,
      ),
    );
  }
}
