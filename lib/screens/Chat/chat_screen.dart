import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/bottom_navigation_bar.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class Message {
  final String text;
  final bool isReceiver; // true if from mechanic, false if from user
  final String status;
  final IconData icon;

  Message({required this.text, required this.isReceiver, this.status = "", this.icon = Icons.build});
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> messages = [
    Message(text: 'Hi, I need help with a flat tire at my current location. Are you available to come here?', isReceiver: true),
    Message(text: 'Online', isReceiver: false, status: 'Online', icon: Icons.call),
    Message(text: 'Hi, I need help with a flat tire location. Are you available to come here?', isReceiver: true),
    Message(text: 'Chat', isReceiver: false, status: 'Chat', icon: Icons.call),
  ];

  final TextEditingController _controller = TextEditingController();

  Widget _buildMessage(Message msg) {
    if (msg.isReceiver) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Icon(msg.icon, color: Colors.white),
            backgroundColor: Colors.green,
          ),
          SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(msg.text),
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(msg.icon, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(msg.status, style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      );
    }
  }

  void sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    // Add the user message to the list (can be customized)
    setState(() {
      messages.add(Message(text: _controller.text.trim(), isReceiver: false));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.shield, color: Colors.blue),
        title: Text('Chat'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: 0),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, index) => _buildMessage(messages[index]),
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: () {},
                ),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}