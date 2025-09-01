import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  final _name = TextEditingController();
  final _phone = TextEditingController();

  Future<void> _load() async {
    final p = await SupabaseService().fetchMyProfile();
    _profile = p;
    _name.text = p?['full_name'] ?? '';
    _phone.text = p?['phone'] ?? '';
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await SupabaseService().updateMyProfile(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 28, child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Supabase.instance.client.auth.currentUser?.email ??
                              '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton(onPressed: _save, child: const Text('Save')),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await SupabaseService().signOut();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
