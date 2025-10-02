import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_contact_service.dart';
import '../services/direct_sos_service.dart';

class EmergencyChatScreen extends StatefulWidget {
  final EmergencyContact contact;
  
  const EmergencyChatScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  _EmergencyChatScreenState createState() => _EmergencyChatScreenState();
}

class _EmergencyChatScreenState extends State<EmergencyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DirectSOSService _sosService = DirectSOSService.instance;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _sosService.initializeOfflineMode();
  }

  Future<void> _loadChatHistory() async {
    // For now, we'll show some example messages
    // In a real app, you'd load from local storage or server
    setState(() {
      _messages = [
        ChatMessage(
          text: "Hey! This is your emergency contact chat with ${widget.contact.name}",
          isMe: false,
          timestamp: DateTime.now().subtract(Duration(minutes: 5)),
          isSystem: true,
        ),
        ChatMessage(
          text: "You can send quick messages or emergency alerts directly from here",
          isMe: false,
          timestamp: DateTime.now().subtract(Duration(minutes: 4)),
          isSystem: true,
        ),
      ];
    });
  }

  Future<void> _sendMessage(String message, {bool isEmergency = false}) async {
    if (message.trim().isEmpty && !isEmergency) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Add message to chat
      final chatMessage = ChatMessage(
        text: message,
        isMe: true,
        timestamp: DateTime.now(),
        isEmergency: isEmergency,
      );

      setState(() {
        _messages.add(chatMessage);
      });

      // Send via SMS and WhatsApp
      if (isEmergency) {
        final result = await _sosService.sendDirectSOS(
          contacts: [widget.contact],
          customMessage: message,
        );

        // Add system message about sending
        setState(() {
          _messages.add(ChatMessage(
            text: result['success'] 
                ? "Emergency message sent via SMS and WhatsApp!"
                : "Failed to send emergency message: ${result['errors'].join(', ')}",
            isMe: false,
            timestamp: DateTime.now(),
            isSystem: true,
            isError: !result['success'],
          ));
        });
      } else {
        // Send regular message
        await _sendRegularMessage(message);
      }

      _messageController.clear();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Error sending message: $e",
          isMe: false,
          timestamp: DateTime.now(),
          isSystem: true,
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRegularMessage(String message) async {
    try {
      // Try SMS first
      String cleanPhone = widget.contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
      final smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        
        setState(() {
          _messages.add(ChatMessage(
            text: "Message sent via SMS to ${widget.contact.name}",
            isMe: false,
            timestamp: DateTime.now(),
            isSystem: true,
          ));
        });
      }
    } catch (e) {
      print('Error sending regular message: $e');
    }
  }

  Future<void> _makeCall() async {
    try {
      final Uri url = Uri(scheme: 'tel', path: widget.contact.phone);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not call ${widget.contact.name}')),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    try {
      String cleanPhone = widget.contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }

      final whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
      
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp for ${widget.contact.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name),
            Text(
              widget.contact.relationship,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.call),
            onPressed: _makeCall,
            tooltip: 'Call ${widget.contact.name}',
          ),
          IconButton(
            icon: Icon(Icons.message),
            onPressed: _openWhatsApp,
            tooltip: 'Open WhatsApp',
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline status indicator
          if (_sosService.isOfflineMode)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.orange,
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode - Messages will be sent when network is available',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Quick action buttons
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () {
                      _sendMessage(
                        "🚨 EMERGENCY! I need immediate help. Please contact me right away!",
                        isEmergency: true,
                      );
                    },
                    icon: Icon(Icons.warning),
                    label: Text('Send SOS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () {
                      _sendMessage("I'm safe now. Thank you for your concern.");
                    },
                    icon: Icon(Icons.check_circle),
                    label: Text('I\'m Safe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: Icon(
                      _isLoading ? Icons.hourglass_empty : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: _isLoading ? null : () {
                      _sendMessage(_messageController.text);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isMe 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isMe && !message.isSystem)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: Text(
                widget.contact.name[0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isSystem
                    ? (message.isError ? Colors.red[100] : Colors.blue[100])
                    : message.isMe
                        ? (message.isEmergency ? Colors.red : Colors.blue)
                        : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isSystem
                          ? (message.isError ? Colors.red[800] : Colors.blue[800])
                          : message.isMe
                              ? Colors.white
                              : Colors.black87,
                      fontWeight: message.isEmergency ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isSystem
                          ? Colors.grey[600]
                          : message.isMe
                              ? Colors.white70
                              : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isMe && !message.isSystem)
            SizedBox(width: 8),
          if (message.isMe && !message.isSystem)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isSystem;
  final bool isEmergency;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isSystem = false,
    this.isEmergency = false,
    this.isError = false,
  });
}