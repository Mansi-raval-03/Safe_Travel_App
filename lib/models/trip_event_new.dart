import 'dart:convert';

/// Trip event status enum for better type safety
enum TripEventStatus { scheduled, active, completed, missed, alertTriggered, cancelled }

extension TripEventStatusX on TripEventStatus {
  static TripEventStatus fromString(String? status) {
    if (status == null) return TripEventStatus.scheduled;
    switch (status.toLowerCase()) {
      case 'scheduled':
        return TripEventStatus.scheduled;
      case 'active':
        return TripEventStatus.active;
      case 'completed':
        return TripEventStatus.completed;
      case 'missed':
        return TripEventStatus.missed;
      case 'alert_triggered':
      case 'alerttriggered':
        return TripEventStatus.alertTriggered;
      case 'cancelled':
        return TripEventStatus.cancelled;
      default:
        return TripEventStatus.scheduled;
    }
  }

  String get apiValue {
    switch (this) {
      case TripEventStatus.scheduled:
        return 'scheduled';
      case TripEventStatus.active:
        return 'active';
      case TripEventStatus.completed:
        return 'completed';
      case TripEventStatus.missed:
        return 'missed';
      case TripEventStatus.alertTriggered:
        return 'alert_triggered';
      case TripEventStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Mode of travel enum
enum TravelMode { walking, driving, publicTransport, cycling, other }

extension TravelModeX on TravelMode {
  static TravelMode fromString(String? mode) {
    if (mode == null) return TravelMode.other;
    switch (mode.toLowerCase()) {
      case 'walking':
        return TravelMode.walking;
      case 'driving':
        return TravelMode.driving;
      case 'public_transport':
      case 'publictransport':
        return TravelMode.publicTransport;
      case 'cycling':
        return TravelMode.cycling;
      default:
        return TravelMode.other;
    }
  }

  String get apiValue {
    switch (this) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.driving:
        return 'driving';
      case TravelMode.publicTransport:
        return 'public_transport';
      case TravelMode.cycling:
        return 'cycling';
      case TravelMode.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.publicTransport:
        return 'Public Transport';
      case TravelMode.cycling:
        return 'Cycling';
      case TravelMode.other:
        return 'Other';
    }
  }
}

/// Trip location model
class TripLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? name;

  const TripLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.name,
  });

  factory TripLocation.fromCoordinates(double lat, double lng,
      {String? address, String? name}) {
    return TripLocation(latitude: lat, longitude: lng, address: address, name: name);
  }

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      latitude: (json['latitude'] ?? json['lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['long'] ?? json['lng'] ?? 0.0).toDouble(),
      address: json['address']?.toString(),
      name: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (name != null) 'name': name,
    };
  }

  @override
  String toString() => name ?? address ?? '$latitude, $longitude';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripLocation && other.latitude == latitude && other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Main TripEvent model class
class TripEvent {
  final String id;
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final TripLocation destination;
  final String? notes;
  final TripEventStatus status;
  final TravelMode travelMode;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLocationUpdate;
  final TripLocation? currentLocation;
  final bool isEmergencyContactsNotified;
  final List<String> alertHistory;

  TripEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.destination,
    this.notes,
    this.status = TripEventStatus.scheduled,
    this.travelMode = TravelMode.other,
    DateTime? createdAt,
    this.updatedAt,
    this.lastLocationUpdate,
    this.currentLocation,
    this.isEmergencyContactsNotified = false,
    List<String>? alertHistory,
  })  : createdAt = createdAt ?? DateTime.now(),
        alertHistory = alertHistory ?? const [];

  factory TripEvent.fromJson(Map<String, dynamic> json) {
    return TripEvent(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().toIso8601String()),
      destination: TripLocation.fromJson(Map<String, dynamic>.from(json['destination'] ?? {})),
      notes: json['notes']?.toString(),
      status: TripEventStatusX.fromString(json['status']?.toString()),
      travelMode: TravelModeX.fromString(json['travelMode']?.toString()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      lastLocationUpdate:
          json['lastLocationUpdate'] != null ? DateTime.parse(json['lastLocationUpdate']) : null,
      currentLocation: json['currentLocation'] != null
          ? TripLocation.fromJson(Map<String, dynamic>.from(json['currentLocation']))
          : null,
      isEmergencyContactsNotified: json['isEmergencyContactsNotified'] ?? false,
      alertHistory: (json['alertHistory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'destination': destination.toJson(),
      if (notes != null) 'notes': notes,
      'status': status.apiValue,
      'travelMode': travelMode.apiValue,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastLocationUpdate != null) 'lastLocationUpdate': lastLocationUpdate!.toIso8601String(),
      if (currentLocation != null) 'currentLocation': currentLocation!.toJson(),
      'isEmergencyContactsNotified': isEmergencyContactsNotified,
      'alertHistory': alertHistory,
    };
  }

  String encode() => jsonEncode(toJson());

  static TripEvent decode(String encoded) => TripEvent.fromJson(jsonDecode(encoded));

  TripEvent copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    TripLocation? destination,
    String? notes,
    TripEventStatus? status,
    TravelMode? travelMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLocationUpdate,
    TripLocation? currentLocation,
    bool? isEmergencyContactsNotified,
    List<String>? alertHistory,
  }) {
    return TripEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      destination: destination ?? this.destination,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      travelMode: travelMode ?? this.travelMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      currentLocation: currentLocation ?? this.currentLocation,
      isEmergencyContactsNotified: isEmergencyContactsNotified ?? this.isEmergencyContactsNotified,
      alertHistory: alertHistory ?? this.alertHistory,
    );
  }

  bool get isValid {
    return title.isNotEmpty && startTime.isBefore(endTime) && destination.latitude.abs() <= 90 && destination.longitude.abs() <= 180;
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime) && status == TripEventStatus.active;
  }

  bool get isUpcoming => DateTime.now().isBefore(startTime) && status == TripEventStatus.scheduled;

  bool get hasEnded => DateTime.now().isAfter(endTime);

  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  Duration? get timeUntilStart {
    final now = DateTime.now();
    return now.isBefore(startTime) ? startTime.difference(now) : null;
  }

  Duration? get timeRemaining {
    final now = DateTime.now();
    return now.isBefore(endTime) ? endTime.difference(now) : null;
  }

  bool get shouldTriggerTimeAlert {
    if (!isCurrentlyActive) return false;
    if (DateTime.now().isAfter(startTime) && status == TripEventStatus.scheduled) return true;
    if (hasEnded && status == TripEventStatus.active) return true;
    return false;
  }

  bool get isLocationUpdateOverdue {
    if (lastLocationUpdate == null) return false;
    final timeSinceLastUpdate = DateTime.now().difference(lastLocationUpdate!);
    return isCurrentlyActive && timeSinceLastUpdate.inMinutes > 30;
  }

  @override
  String toString() => 'TripEvent(id: $id, title: $title, status: ${status.apiValue})';

  @override
  bool operator ==(Object other) => identical(this, other) || (other is TripEvent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Helper class for trip event creation
class TripEventBuilder {
  String title = '';
  DateTime? startTime;
  DateTime? endTime;
  TripLocation? destination;
  String? notes;
  TravelMode travelMode = TravelMode.other;

  TripEventBuilder setTitle(String title) {
    this.title = title;
    return this;
  }

  TripEventBuilder setStartTime(DateTime startTime) {
    this.startTime = startTime;
    return this;
  }

  TripEventBuilder setEndTime(DateTime endTime) {
    this.endTime = endTime;
    return this;
  }

  TripEventBuilder setDestination(TripLocation destination) {
    this.destination = destination;
    return this;
  }

  TripEventBuilder setNotes(String? notes) {
    this.notes = notes;
    return this;
  }

  TripEventBuilder setTravelMode(TravelMode mode) {
    this.travelMode = mode;
    return this;
  }

  TripEvent build(String userId) {
    if (title.isEmpty) throw ArgumentError('Title cannot be empty');
    if (startTime == null) throw ArgumentError('Start time is required');
    if (endTime == null) throw ArgumentError('End time is required');
    if (destination == null) throw ArgumentError('Destination is required');
    if (startTime!.isAfter(endTime!)) throw ArgumentError('Start time must be before end time');

    return TripEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title,
      startTime: startTime!,
      endTime: endTime!,
      destination: destination!,
      notes: notes,
      travelMode: travelMode,
      createdAt: DateTime.now(),
    );
  }
}
