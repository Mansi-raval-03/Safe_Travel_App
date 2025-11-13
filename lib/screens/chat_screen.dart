import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import '../services/encryption_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  const ChatScreen({Key? key, required this.otherUserId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = AuthService.getCurrentUserSync();
    _currentUserId = user?.id ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserId)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.instance.conversationStream(_currentUserId, widget.otherUserId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final msgs = snap.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe = m.senderId == _currentUserId;
                    return FutureBuilder<String>(
                      future: EncryptionService.instance.decryptEnvelope(m.messageText),
                      builder: (context, decSnap) {
                        final text = decSnap.hasData ? decSnap.data! : 'Encrypted message';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ChatService.instance.sendMessage(senderId: _currentUserId, receiverId: widget.otherUserId, plainText: text);
  }
}
