import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'encryption_service.dart';

class ChatService {
  static final ChatService instance = ChatService._();
  final SupabaseClient _supabase = Supabase.instance.client;

  ChatService._();

  Future<void> sendMessage({required String senderId, required String receiverId, required String plainText}) async {
    // get recipient public key from profiles table
    final res = await _supabase.from('profiles').select('id,public_key').eq('id', receiverId).maybeSingle();
    // avoid unnecessary cast: ensure we only treat the result as a map when it is one
    final recipient = res is Map<String, dynamic> ? res : null;
    if (recipient == null || recipient['public_key'] == null) {
      throw Exception('Recipient public key not found');
    }
    final recipientPublicPem = recipient['public_key'] as String;

    final encrypted = await EncryptionService.instance.encryptForRecipient(plainText, recipientPublicPem);

    await _supabase.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_text': encrypted,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    });
  }

  /// Stream of all messages from messages table. Caller should filter for conversation.
  Stream<List<ChatMessage>> messagesStream() {
    final stream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('timestamp');
    return stream.map((rows) {
      return (rows as List).map((r) => ChatMessage.fromMap(r as Map<String, dynamic>)).toList();
    });
  }

  /// Convenience: stream only messages for a 1:1 conversation between currentUser and otherUser
  Stream<List<ChatMessage>> conversationStream(String currentUserId, String otherUserId) {
    return messagesStream().map((all) {
      final conv = all.where((m) => (m.senderId == currentUserId && m.receiverId == otherUserId) || (m.senderId == otherUserId && m.receiverId == currentUserId)).toList();
      conv.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return conv;
    });
  }

  Future<List<Map<String, dynamic>>> fetchUsers({String? query}) async {
    final q = _supabase.from('profiles').select('id,full_name,avatar_url,public_key');
    if (query != null && query.isNotEmpty) {
      q.ilike('full_name', '%$query%');
    }
    final res = await q;
    return List<Map<String, dynamic>>.from(res as List<dynamic>);
  }
}
