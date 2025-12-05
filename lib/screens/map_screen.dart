import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
// Repo services
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../widgets/bottom_navigation.dart';

// Google Places API key is read from `GooglePlacesService.apiKey` (use --dart-define to supply it).

class MapScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  final VoidCallback? onTriggerSOS;
  /// Optional bottom navigation widget provided by the  parent app.
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
  // Nearby services feature removed — keep only markers map.
  Marker? _selectedPlaceMarker;
  MapType _mapType = MapType.normal;

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
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      _moveCamera(LatLng(pos.latitude, pos.longitude), zoom: 15);

      // Listen to the shared location stream
      _positionSub = LocationService().locationStream.listen((p) {
        if (!mounted) return;
        setState(() => _currentPosition = p);
        _updateMarkers();
      });
    } catch (e) {
      debugPrint('Error initializing LocationService: $e');
    }
  }

  // Nearby services functions removed.

  void _updateMarkers() {
    if (!mounted) return;
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

    // Only user marker and optionally a selected place marker are shown on the map
    if (_selectedPlaceMarker != null) {
      _markers[_selectedPlaceMarker!.markerId] = _selectedPlaceMarker!;
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

  Future<void> _testStaticMapTiles() async {
    final key = await GooglePlacesService.resolvedApiKey();
    if (key.isEmpty || key.startsWith('YOUR_GOOGLE_PLACES_API_KEY')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Places/Maps API key not configured')));
      return;
    }
    final lat = _currentPosition?.latitude ?? 20.5937;
    final lng = _currentPosition?.longitude ?? 78.9629;
    final url = Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
      'center': '$lat,$lng',
      'zoom': '17',
      'size': '600x300',
      'scale': '2',
      'markers': 'color:blue|$lat,$lng',
      'key': key,
    });

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200 && resp.headers['content-type']?.startsWith('image') == true) {
        // Show the image in a dialog
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Static Map Tiles OK'),
            content: Image.memory(resp.bodyBytes, fit: BoxFit.cover),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Static map request failed (${resp.statusCode})')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Static map request error: $e')));
    }
  }

  Future<void> _performPlacesAutocomplete(String input) async {
    final key = await GooglePlacesService.resolvedApiKey();
    if (key.isEmpty || key.startsWith('YOUR_GOOGLE_PLACES_API_KEY')) return;
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': key,
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
      if (!mounted) return;
      setState(() => _placeSuggestions = List<Map<String, dynamic>>.from(results));
    } catch (_) {}
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'] as String?;
    final key = await GooglePlacesService.resolvedApiKey();
    if (placeId == null || key.isEmpty || key.startsWith('YOUR_GOOGLE_PLACES_API_KEY')) {
      setState(() {
        _searchController.text = suggestion['description'] ?? '';
        _placeSuggestions = [];
      });
      return;
    }

    final url = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': key,
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
      if (!mounted) return;
      setState(() {
        _searchController.text = result['name'] ?? suggestion['description'] ?? '';
        _placeSuggestions = [];
        _selectedPlaceMarker = Marker(
          markerId: const MarkerId('place_selected'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: result['name'] ?? suggestion['description']),
          icon: BitmapDescriptor.defaultMarker,
          onTap: () => _moveCamera(LatLng(lat, lng), zoom: 16),
        );
      });
      _moveCamera(LatLng(lat, lng), zoom: 16);
    } catch (_) {}
  }

  // Nearby services UI removed.

  @override
  Widget build(BuildContext context) {
    // Map layout
    final media = MediaQuery.of(context);
    // UI layout: full screen map with overlay search and bottom list
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map (fills background). Wrap creation in a try/catch so
            // a native plugin error (missing API key, etc.) doesn't crash the
            // whole app; show a friendly fallback instead.
            Positioned.fill(
              child: Builder(
                builder: (ctx) {
                  try {
                    return GoogleMap(
                      mapType: _mapType,
                      initialCameraPosition: _initialCamera,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      markers: Set<Marker>.of(_markers.values),
                      onMapCreated: (controller) async {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                        }
                        try {
                          // Clear any custom map style that might have been
                          // injected previously and force a refresh of tiles.
                          await controller.setMapStyle(null);
                        } catch (_) {}

                        // Move camera to current position if available
                        if (_currentPosition != null) {
                          try {
                            await controller.moveCamera(CameraUpdate.newLatLngZoom(
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              17,
                            ));
                          } catch (_) {}
                        }

                        // Diagnostic: attempt a simple platform call to verify the
                        // native map is responding and has tiles available. If this
                        // throws, surface an actionable error to the user.
                        try {
                          await controller.getVisibleRegion();
                        } catch (err) {
                          debugPrint('Map controller diagnostic failed: $err');
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Map Initialization Problem'),
                                content: const Text(
                                  'The Google Maps native SDK failed to initialize correctly.\n\n'
                                  'Common causes: missing/invalid API key, Maps SDK for Android not enabled, or billing/quotas not configured.\n\n'
                                  'Tap Retry to attempt re-initialization or check your Google Cloud Console settings.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _initLocation();
                                      setState(() {});
                                    },
                                    child: const Text('Retry'),
                                  ),
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                                ],
                              ),
                            );
                          }
                        }
                      },
                    );
                  } catch (err, st) {
                    // Log and show a simple fallback UI so app stays usable.
                    debugPrint('GoogleMap build error: $err\n$st');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Card(
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text('Map unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                const Text('Google Maps failed to initialize. Please check your API key or try again later.', textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    // Retry: re-attempt to initialize location and rebuild
                                    await _initLocation();
                                    setState(() {});
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
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
                        if (kDebugMode)
                          IconButton(
                            icon: const Icon(Icons.api_outlined, color: Color(0xFF6B7280)),
                            tooltip: 'Test Places API Key',
                            onPressed: () async {
                              final res = await GooglePlacesService.testApiKey(lat: _currentPosition?.latitude, lng: _currentPosition?.longitude);
                              if (!mounted) return;
                              final ok = res['ok'] == true;
                              final status = res['status'] ?? '';
                              final msg = res['message'] ?? '';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Places API test: ${ok ? 'OK' : 'FAIL'} ($status) ${msg}')));
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

            // Nearby services removed: bottom panel omitted.
            // Nearby filters removed.

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
            // Debug map type toggle (only visible in debug mode)
            if (kDebugMode)
              Positioned(
                right: 16,
                bottom: 86,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      onPressed: () async {
                        // Map type toggle
                        setState(() {
                          _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
                        });
                        if (_mapController.isCompleted) {
                          try {
                            final c = await _mapController.future;
                            await c.setMapStyle(null);
                            if (_currentPosition != null) {
                              await c.moveCamera(CameraUpdate.newLatLngZoom(
                                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 17));
                            }
                          } catch (_) {}
                        }
                      },
                      backgroundColor: Colors.white,
                      child: Icon(_mapType == MapType.normal ? Icons.satellite : Icons.map, color: Colors.black87, size: 18),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      onPressed: _testStaticMapTiles,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.image, color: Colors.black87, size: 18),
                      heroTag: 'static_map_test',
                    ),
                  ],
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

