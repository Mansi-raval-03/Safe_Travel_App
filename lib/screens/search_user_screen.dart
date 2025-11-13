import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({Key? key}) : super(key: key);

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  void _doSearch(String q) async {
    final res = await ChatService.instance.fetchUsers(query: q);
    setState(() => _results = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(hintText: 'Search by name...'),
              onChanged: _doSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final u = _results[i];
                return ListTile(
                  title: Text(u['full_name'] ?? u['id']),
                  subtitle: Text(u['id']),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: u['id'])));
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
