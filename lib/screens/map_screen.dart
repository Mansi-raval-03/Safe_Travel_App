import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
// Repo services
import '../services/location_service.dart';
import '../services/emergency_location_service.dart';
import '../services/google_places_service.dart';
import '../models/place_model.dart';
import '../widgets/bottom_navigation.dart';

// Placeholder: set at runtime using secure config (do NOT commit keys).
const String _kGooglePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';

class MapScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  final VoidCallback? onTriggerSOS;
  /// Optional bottom navigation widget provided by the parent app.
  /// If null, the screen will not build its own BottomNavigationBar.
  final Widget? bottomNavigationBar;

  const MapScreen({Key? key, this.onNavigate, this.onTriggerSOS, this.bottomNavigationBar}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;

  final Map<MarkerId, Marker> _markers = {};
  List<Map<String, dynamic>> _nearbyServices = [];

  Timer? _debounce;
  List<Map<String, dynamic>> _placeSuggestions = [];

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final ok = await LocationService().initialize();
      if (!ok) return;

      final pos = LocationService().currentPosition ?? await LocationService().getCurrentLocation();
      if (pos == null) return;

      setState(() => _currentPosition = pos);
      _moveCamera(LatLng(pos.latitude, pos.longitude), zoom: 15);
      await _loadNearbyServices(pos.latitude, pos.longitude);

      // Listen to the shared location stream
      _positionSub = LocationService().locationStream.listen((p) {
        if (!mounted) return;
        setState(() => _currentPosition = p);
        _updateMarkers();
        // reload nearby services on significant moves
        _maybeReloadNearbyServices(p);
      });
    } catch (e) {
      debugPrint('Error initializing LocationService: $e');
    }
  }

  Future<void> _maybeReloadNearbyServices(Position p) async {
    // reload when moved more than ~200 meters from last known
    if (_nearbyServices.isEmpty) {
      await _loadNearbyServices(p.latitude, p.longitude);
      return;
    }

    final lastLat = _nearbyServices.first['latitude'] as double? ?? p.latitude;
    final lastLng = _nearbyServices.first['longitude'] as double? ?? p.longitude;
    final moved = Geolocator.distanceBetween(lastLat, lastLng, p.latitude, p.longitude);
    if (moved > 200) {
      await _loadNearbyServices(p.latitude, p.longitude);
    }
  }

  Future<void> _loadNearbyServices(double lat, double lng) async {
    try {
      // Use Google Places Nearby Search to fetch real nearby emergency services
      final types = ['hospital', 'police', 'gas_station'];
      final List<Map<String, dynamic>> aggregated = [];

      for (final t in types) {
        final results = await GooglePlacesService.nearbySearch(lat: lat, lng: lng, type: t, radiusMeters: 3000);
        for (final p in results) {
          final d = Geolocator.distanceBetween(lat, lng, p.location.latitude, p.location.longitude) / 1000.0; // km
          aggregated.add({
            'name': p.name,
            'type': t,
            'latitude': p.location.latitude,
            'longitude': p.location.longitude,
            'address': p.address ?? '',
            'phone': '',
            'distance_km': d,
            'place_id': p.placeId,
          });
        }
      }

      // dedupe by place_id
      final mapById = <String, Map<String, dynamic>>{};
      for (final a in aggregated) {
        final id = a['place_id'] as String? ?? '${a['name']}_${a['latitude']}_${a['longitude']}';
        mapById[id] = a;
      }

      final list = mapById.values.toList();
      list.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));

      setState(() {
        _nearbyServices = list.take(12).map((s) => Map<String, dynamic>.from(s)).toList();
      });
      _updateMarkers();
    } catch (e) {
      debugPrint('Error loading nearby services: $e');
      // Fallback to sample data if Places API fails
      _generateSampleNearbyServices(lat, lng);
    }
  }

  void _generateSampleNearbyServices(double lat, double lng) {
    final samples = [
      {
        'name': 'Central Hospital',
        'type': 'hospital',
        'latitude': lat + 0.004,
        'longitude': lng + 0.003,
        'address': '123 Health St.',
        'phone': '1234567890',
      },
      {
        'name': 'City Police Station',
        'type': 'police',
        'latitude': lat - 0.0035,
        'longitude': lng + 0.0025,
        'address': '45 Safety Ave.',
        'phone': '0987654321',
      },
      {
        'name': 'Downtown Fire Dept.',
        'type': 'fire',
        'latitude': lat + 0.002,
        'longitude': lng - 0.003,
        'address': '9 Rescue Blvd.',
        'phone': '1122334455',
      },
    ];

    setState(() {
      _nearbyServices = List<Map<String, dynamic>>.from(samples);
      _updateMarkers();
    });
  }

  void _updateMarkers() {
    _markers.clear();
    if (_currentPosition != null) {
      final id = const MarkerId('user_location');
      _markers[id] = Marker(
        markerId: id,
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }

    for (var s in _nearbyServices) {
      final mid = MarkerId('service_${s['name']}_${s['latitude']}_${s['longitude']}');
      final hue = _markerHueForType(s['type']?.toString() ?? 'other');
      _markers[mid] = Marker(
        markerId: mid,
        position: LatLng(s['latitude'] as double, s['longitude'] as double),
        infoWindow: InfoWindow(title: s['name'] as String, snippet: s['address'] as String),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => _moveCamera(LatLng(s['latitude'] as double, s['longitude'] as double), zoom: 16),
      );
    }

    setState(() {});
  }

  double _markerHueForType(String type) {
    switch (type.toLowerCase()) {
      case 'hospital':
        return BitmapDescriptor.hueRed;
      case 'police':
        return BitmapDescriptor.hueBlue;
      case 'fire':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 15}) async {
    final controller = await _mapController.future;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } catch (_) {}
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final text = _searchController.text.trim();
      if (text.isEmpty) {
        setState(() => _placeSuggestions = []);
        return;
      }
      _performPlacesAutocomplete(text);
    });
  }

  Future<void> _performPlacesAutocomplete(String input) async {
    if (_kGooglePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') return;
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': _kGooglePlacesApiKey,
      'types': 'establishment|geocode',
      'location': _currentPosition != null ? '${_currentPosition!.latitude},${_currentPosition!.longitude}' : null,
      'radius': '5000',
    }..removeWhere((k, v) => v == null));

    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final preds = (body['predictions'] as List<dynamic>?) ?? [];
      final results = preds.map((p) => {
            'place_id': p['place_id'],
            'description': p['description'],
          }).toList();

      setState(() => _placeSuggestions = List<Map<String, dynamic>>.from(results));
    } catch (_) {}
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'] as String?;
    if (placeId == null || _kGooglePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      setState(() {
        _searchController.text = suggestion['description'] ?? '';
        _placeSuggestions = [];
      });
      return;
    }

    final url = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': _kGooglePlacesApiKey,
      'fields': 'geometry,name,formatted_address',
    });

    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>?;
      if (result == null) return;
      final loc = result['geometry']?['location'];
      if (loc == null) return;
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();
      setState(() {
        _searchController.text = result['name'] ?? suggestion['description'] ?? '';
        _placeSuggestions = [];
        _nearbyServices.insert(0, {
          'name': result['name'] ?? suggestion['description'],
          'type': 'place',
          'latitude': lat,
          'longitude': lng,
          'address': result['formatted_address'] ?? '',
          'phone': '',
        });
        _updateMarkers();
      });
      _moveCamera(LatLng(lat, lng), zoom: 16);
    } catch (_) {}
  }

  double _distanceKmToService(Map<String, dynamic> s) {
    if (_currentPosition == null) return 0.0;
    final d = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (s['latitude'] as double),
      (s['longitude'] as double),
    );
    return (d / 1000.0);
  }

  Widget _buildBottomList() {
    final list = _nearbyServices
        .map((s) => {'data': s, 'distance': _distanceKmToService(s)})
        .toList();

    list.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          final s = item['data'] as Map<String, dynamic>;
          final dist = item['distance'] as double;
          return SizedBox(
            width: 300,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          s['type'] == 'hospital'
                              ? Icons.local_hospital
                              : s['type'] == 'police'
                                  ? Icons.local_police
                                  : s['type'] == 'fire'
                                      ? Icons.local_fire_department
                                      : Icons.place,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${dist.toStringAsFixed(2)} km'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s['address'] ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Call ${s['phone'] ?? 'N/A'}')),
                            );
                          },
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final lat = s['latitude'] as double;
                            final lng = s['longitude'] as double;
                            _moveCamera(LatLng(lat, lng), zoom: 16);
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Go'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI layout: full screen map with overlay search and bottom list
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map (fills background)
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: _initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: Set<Marker>.of(_markers.values),
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  if (_currentPosition != null) {
                    controller.moveCamera(CameraUpdate.newLatLngZoom(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      15,
                    ));
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
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search places or addresses',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          onSubmitted: (_) => _onSearchChanged(),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _placeSuggestions = [];
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Place suggestions (overlay)
            if (_placeSuggestions.isNotEmpty)
              Positioned(
                left: 14,
                right: 18,
                top: 72,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _placeSuggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = _placeSuggestions[i];
                        return ListTile(
                          title: Text(s['description'] ?? ''),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Bottom horizontal services list (floating panel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 75, // above bottom navigation
              child: SizedBox(
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildBottomList(),
                ),
              ),
            ),

            // Floating Action Button to center on user
            Positioned(
              right: 60,
              bottom: 20,
              child: FloatingActionButton(
                onPressed: () async {
                  if (_currentPosition != null) {
                    await _moveCamera(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
                  } else {
                    await _initLocation();
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      // Use the app's shared BottomNavigation widget so navigation is consistent.
      bottomNavigationBar: BottomNavigation(
        currentIndex: 3, // Map screen index in MainApp
        onNavigate: widget.onNavigate ?? (_) {},
      ),
    );
  }
}

