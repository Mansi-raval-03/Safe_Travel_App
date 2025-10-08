/// Location data model for real-time tracking and offline storage
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;
  final String? userId;
  final bool isSynced;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
    this.userId,
    this.isSynced = false,
  });

  /// Create LocationData from Position object
  factory LocationData.fromPosition({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? altitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
    String? userId,
  }) {
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      heading: heading,
      speed: speed,
      timestamp: timestamp ?? DateTime.now(),
      userId: userId,
    );
  }

  /// Convert to JSON for Socket.IO transmission
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'heading': heading,
      'speed': speed,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'userId': userId,
    };
  }

  /// Create from JSON (for receiving from Socket.IO)
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      altitude: json['altitude']?.toDouble(),
      heading: json['heading']?.toDouble(),
      speed: json['speed']?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      userId: json['userId'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabaseMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'heading': heading,
      'speed': speed,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'user_id': userId,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Create from database map
  factory LocationData.fromDatabaseMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      altitude: map['altitude']?.toDouble(),
      heading: map['heading']?.toDouble(),
      speed: map['speed']?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      userId: map['user_id'] as String?,
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  /// Copy with new values
  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
    String? userId,
    bool? isSynced,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^ longitude.hashCode ^ timestamp.hashCode;
  }
}

/// Custom LocationDto for internal use (different from background_locator_2's LocationDto)
class LocationDto {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationDto({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  /// Convert to LocationData
  LocationData toLocationData({String? userId}) {
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      heading: heading,
      speed: speed,
      timestamp: timestamp,
      userId: userId,
    );
  }

  @override
  String toString() {
    return 'LocationDto(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }
}