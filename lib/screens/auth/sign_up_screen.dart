import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';


class SignUpScreen extends StatefulWidget {
const SignUpScreen({super.key});


@override
State<SignUpScreen> createState() => _SignUpScreenState();
}


class _SignUpScreenState extends State<SignUpScreen> {
final _email = TextEditingController();
final _password = TextEditingController();
final _name = TextEditingController();
final _phone = TextEditingController();
bool _loading = false;
String? _error;


Future<void> _submit() async {
setState(() { _loading = true; _error = null; });
try {
await SupabaseService().signUpEmail(
email: _email.text.trim(),
password: _password.text,
fullName: _name.text.trim(),
phone: _phone.text.trim(),
);
if (mounted) Navigator.pop(context); // back to sign-in
} catch (e) {
_error = e.toString();
} finally { setState(() => _loading = false); }
}
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('Create account')),
body: Padding(
padding: const EdgeInsets.all(20),
child: SingleChildScrollView(
child: Column(
children: [
TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
const SizedBox(height: 12),
TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
const SizedBox(height: 12),
TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
const SizedBox(height: 12),
TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
const SizedBox(height: 20),
if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
FilledButton(
onPressed: _loading ? null : _submit,
child: _loading ? const CircularProgressIndicator() : const Text('Sign Up'),
),
],
),
),
),
);
}
}