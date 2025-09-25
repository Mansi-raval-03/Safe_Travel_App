import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ------------------ Emergency Screen ------------------
class EmergencyScreen extends StatefulWidget {
  final List<EmergencyContact> contacts;
  final Function(List<EmergencyContact>) onUpdateContacts;
  final Function(int) onNavigate;

  const EmergencyScreen({
    super.key,
    required this.contacts,
    required this.onUpdateContacts,
    required this.onNavigate,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  // Use the contacts passed from parent instead of hardcoded ones
  late List<EmergencyContact> contacts;

  @override
  void initState() {
    super.initState();
    contacts = List.from(widget.contacts);
  }

  // Function to make a phone call
  Future<void> _makeCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // Function to send SMS
  Future<void> _sendSms(String phone) async {
    final Uri url = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate(2), // Navigate back to Home screen
        ),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Text(
                  contact.name[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(contact.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(contact.relationship),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _makeCall(contact.phone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.blue),
                    onPressed: () => _sendSms(contact.phone),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.sos),
        label: const Text("Send SOS"),
        onPressed: () {
          // TODO: Integrate SOS functionality (like notifying all contacts)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SOS Alert Sent to all contacts!")),
          );
        },
      ),
    );
  }
}

// ------------------ EmergencyContact Model ------------------
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
    );
  }
}