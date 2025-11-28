class SosAlert {
  final String id;
  final String senderName;
  final String? message;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final bool isRead;

  SosAlert({
    required this.id,
    required this.senderName,
    this.message,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.isRead = false,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: json['userName'] ?? json['senderName'] ?? 'Unknown',
      message: json['message']?.toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestamp'] is int) ? json['timestamp'] : (json['createdAt'] is String ? DateTime.parse(json['createdAt']).millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch)),
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : (json['location'] != null && json['location']['latitude'] is num) ? (json['location']['latitude'] as num).toDouble() : null,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : (json['location'] != null && json['location']['longitude'] is num) ? (json['location']['longitude'] as num).toDouble() : null,
      isRead: json['isRead'] == true || json['read'] == true ? true : false,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userName': senderName,
        'message': message,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'isRead': isRead,
      };
}
