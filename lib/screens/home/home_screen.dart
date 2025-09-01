import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _futureHistory;

  @override
  void initState() {
    super.initState();
    _futureHistory = SupabaseService().mySosHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Travel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    color: Colors.red,
                    icon: Icons.warning,
                    title: 'Send SOS',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Open SOS tab to send alert'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    color: Colors.blue,
                    icon: Icons.contacts,
                    title: 'Contacts',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Open Contacts tab to manage'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent SOS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder(
                future: _futureHistory,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items =
                      snapshot.data as List<Map<String, dynamic>>? ?? [];
                  if (items.isEmpty)
                    return const Center(child: Text('No SOS yet'));
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = items[i];
                      final dt = DateTime.tryParse(
                        row['created_at'] ?? '',
                      )?.toLocal();
                      final  when;
                      if (dt != null) {
                        when = DateFormat('dd MMM, hh:mm a').format(dt);
                      } else {
                        when = '';
                      }
                      return ListTile(
                        leading: const Icon(Icons.sos),
                        title: Text(row['message'] ?? 'SOS'),
                        subtitle: Text(
                          'Lat: ${row['latitude']?.toStringAsFixed(4) ?? '-'} | Lng: ${row['longitude']?.toStringAsFixed(4) ?? '-'}\n$when',
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
