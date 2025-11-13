import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String messageText; // encrypted payload (base64/json)
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    String? id,
    required this.senderId,
    required this.receiverId,
    required this.messageText,
    DateTime? timestamp,
    this.read = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id']?.toString(),
        senderId: m['sender_id'] ?? m['senderId'],
        receiverId: m['receiver_id'] ?? m['receiverId'],
        messageText: m['message_text'] ?? m['messageText'] ?? '',
        timestamp: m['timestamp'] != null
            ? DateTime.parse(m['timestamp'])
            : DateTime.now(),
        read: m['read'] == true || m['read'] == 't',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message_text': messageText,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
      };
}
