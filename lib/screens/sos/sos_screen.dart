import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/location_helper.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _sending = false;
  String? _status;
  final _message = TextEditingController(text: 'Emergency! Need help.');

  Future<void> _sendSOS() async {
    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _status = 'Location permission denied or unavailable';
        });
        return;
      }
      await SupabaseService().createSos(
        latitude: pos.latitude,
        longitude: pos.longitude,
        message: _message.text,
      );
      setState(() {
        _status = 'SOS sent successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed: $e';
      });
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _message,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'SOS Message'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendSOS,
                icon: const Icon(Icons.sos),
                label: _sending
                    ? const CircularProgressIndicator()
                    : const Text('Send SOS'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Text(
                _status!,
                style: TextStyle(
                  color: _status!.startsWith('Failed')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
