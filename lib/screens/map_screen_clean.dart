import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// Placeholder: set at runtime using secure config (do NOT commit keys).
const String _kGooglePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';

class MapScreenClean extends StatefulWidget {
  const MapScreenClean({Key? key}) : super(key: key);

  @override
  State<MapScreenClean> createState() => _MapScreenCleanState();
}

class _MapScreenCleanState extends State<MapScreenClean> {
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
    target: LatLng(20.5937, 78.9629), // fallback: India center
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _currentPosition = pos);
      _moveCamera(LatLng(pos.latitude, pos.longitude), zoom: 15);
      _generateSampleNearbyServices(pos.latitude, pos.longitude);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10),
      ).listen((p) {
        setState(() => _currentPosition = p);
        _updateMarkers();
      });
    } catch (_) {}
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
        .map((s) => {
              'data': s,
              'distance': _distanceKmToService(s),
            })
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Emergency Services'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search places or addresses',
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _placeSuggestions = [];
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (_placeSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
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
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCamera,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildBottomList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
