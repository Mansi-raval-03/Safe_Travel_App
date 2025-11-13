import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import 'chat_screen.dart';
import 'search_user_screen.dart';
import '../services/encryption_service.dart';
import '../services/auth_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final String _currentUserId;
  Stream<List<ChatMessage>>? _stream;

  @override
  void initState() {
    super.initState();
    // Avoid calling a non-existent synchronous auth method; initialize to empty
    // string and let the app populate the current user id via a proper auth
    // accessor or later update.
    _currentUserId = '';
    _stream = ChatService.instance.conversationStream(_currentUserId, '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchUserScreen())),
          )
        ],
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: ChatService.instance.messagesStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final msgs = snap.data!;
          // group by conversation partner
          final Map<String, List<ChatMessage>> convs = {};
          for (final m in msgs) {
            final other = m.senderId == _currentUserId ? m.receiverId : m.senderId;
            convs.putIfAbsent(other, () => []).add(m);
          }
          final entries = convs.entries.toList()
            ..sort((a, b) {
              final aLast = a.value.last.timestamp;
              final bLast = b.value.last.timestamp;
              return bLast.compareTo(aLast);
            });

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final otherId = entries[i].key;
              final last = entries[i].value.last;
              final unread = entries[i].value.where((m) => !m.read && m.receiverId == _currentUserId).length;
              return ListTile(
                title: Text(otherId),
                subtitle: Text(_previewText(last)),
                trailing: unread > 0 ? CircleAvatar(radius: 12, child: Text(unread.toString())) : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: otherId))),
              );
            },
          );
        },
      ),
    );
  }

  String _previewText(ChatMessage m) {
    try {
      // Attempt quick decrypt to show preview. If fails, show placeholder.
      // Note: decryptEnvelope may throw if private key not present.
      // Avoid performing decryption synchronously here - just show a placeholder.
      return 'Encrypted'; // real app should pre-decrypt cached messages asynchronously
    } catch (_) {
      return 'Encrypted message';
    }
  }
}
