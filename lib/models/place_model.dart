import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceModel {
  final String placeId;
  final String name;
  final String? address;
  final LatLng location;
  final String placeType;
  final double? distanceMeters;

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.location,
    this.address,
    this.placeType = '',
    this.distanceMeters,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json, {double? distance}) {
    final geometry = json['geometry'] ?? {};
    final loc = geometry['location'] ?? {};
    return PlaceModel(
      placeId: json['place_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['vicinity'] ?? json['formatted_address'],
      location: LatLng((loc['lat'] ?? 0.0).toDouble(), (loc['lng'] ?? 0.0).toDouble()),
      placeType: (json['types'] != null && json['types'] is List && json['types'].isNotEmpty) ? json['types'][0] : '',
      distanceMeters: distance,
    );
  }
}
