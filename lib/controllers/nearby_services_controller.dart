import 'dart:async';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place_model.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';

class NearbyServicesController {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _posSub;
  Position? lastPosition;
  DateTime? _lastFetchTime;
  double fetchDistanceThresholdMeters = 150; // only refetch if user moved this far
  Duration fetchMinInterval = const Duration(seconds: 10);

  final StreamController<List<PlaceModel>> _placesController = StreamController.broadcast();
  Stream<List<PlaceModel>> get placesStream => _placesController.stream;

  final StreamController<bool> _loadingController = StreamController.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  // search debounce
  Timer? _searchDebounce;

  // state
  List<PlaceModel> currentPlaces = [];

  Future<bool> ensurePermission() async {
    return await _locationService.requestPermission();
  }

  Future<Position> getCurrentPosition() async {
    return await _locationService.getCurrentPosition();
  }

  void startListening({int distanceFilter = 50}) async {
    _posSub?.cancel();
    _posSub = _locationService.getPositionStream(distanceFilterMeters: distanceFilter).listen((pos) async {
      final moved = _shouldRefetch(pos);
      lastPosition = pos;
      if (moved) {
        await fetchNearbyServicesForPosition(pos);
      }
    });
  }

  bool _shouldRefetch(Position pos) {
    if (lastPosition == null) return true;
    final d = _distanceBetween(lastPosition!.latitude, lastPosition!.longitude, pos.latitude, pos.longitude);
    final since = _lastFetchTime == null ? true : DateTime.now().difference(_lastFetchTime!) > fetchMinInterval;
    return d >= fetchDistanceThresholdMeters && since;
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // metres
    final phi1 = lat1 * pi/180;
    final phi2 = lat2 * pi/180;
    final dphi = (lat2-lat1) * pi/180;
    final dlambda = (lon2-lon1) * pi/180;
    final a = sin(dphi/2)*sin(dphi/2) + cos(phi1)*cos(phi2)*sin(dlambda/2)*sin(dlambda/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  Future<void> fetchNearbyServicesForPosition(Position pos, {int radiusMeters = 2000, String? keyword}) async {
    _loadingController.add(true);
    _lastFetchTime = DateTime.now();
    try {
      final types = ['hospital', 'police', 'gas_station'];
      final List<PlaceModel> aggregated = [];
      for (final t in types) {
        final results = await GooglePlacesService.nearbySearch(lat: pos.latitude, lng: pos.longitude, type: t, radiusMeters: radiusMeters, keyword: keyword);
        for (final r in results) {
          // compute distance
          final d = _distanceBetween(pos.latitude, pos.longitude, r.location.latitude, r.location.longitude);
          aggregated.add(PlaceModel(
            placeId: r.placeId,
            name: r.name,
            address: r.address,
            location: r.location,
            placeType: r.placeType,
            distanceMeters: d,
          ));
        }
      }
      // dedupe by placeId
      final map = <String, PlaceModel>{};
      for (final p in aggregated) map[p.placeId] = p;
      currentPlaces = map.values.toList();
      // sort by distance
      currentPlaces.sort((a,b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      _placesController.add(currentPlaces);
    } catch (e) {
      _placesController.add([]);
    } finally {
      _loadingController.add(false);
    }
  }

  void search(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      // clear search: refetch for lastPosition
      if (lastPosition != null) fetchNearbyServicesForPosition(lastPosition!);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (lastPosition != null) {
        fetchNearbyServicesForPosition(lastPosition!, keyword: query);
      }
    });
  }

  void dispose() {
    _posSub?.cancel();
    _placesController.close();
    _loadingController.close();
    _searchDebounce?.cancel();
  }

  /// Open app settings via location service
  Future<bool> openAppSettings() async {
    return await _locationService.openAppSettings();
  }
}
