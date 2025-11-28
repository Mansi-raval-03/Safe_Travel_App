import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/alert_service.dart';
import 'alert_map_screen.dart';

/// A compact panel widget that can be shown as a right-side sliding panel.
class AlertNotifications extends StatefulWidget {
  const AlertNotifications({Key? key}) : super(key: key);

  @override
  State<AlertNotifications> createState() => _AlertNotificationsState();
}

class _AlertNotificationsState extends State<AlertNotifications> {
  final AlertService _alertService = AlertService();
  late Stream<List<SosAlert>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _alertService.alertsStream;
    // fetch initial alerts
    _alertService.fetchInitialAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.65; // panel width (65% of screen)
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Decorative gradient header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(0)),
                  ),
                  child: Row(
                    children: [
                      // small handle
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Alert Notifications', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      // unread badge
                      StreamBuilder<List<SosAlert>>(
                        stream: _stream,
                        builder: (context, snapshot) {
                          final count = (snapshot.data ?? []).length;
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: StreamBuilder<List<SosAlert>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final alerts = snapshot.data ?? [];
                        if (alerts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.notifications_none_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                SizedBox(height: 8),
                                Text('No alerts yet', style: TextStyle(color: Color(0xFF6B7280))),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final a = alerts[idx];
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
                                  child: Text(a.senderName.isNotEmpty ? a.senderName[0] : 'S', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                                ),
                                title: Text(a.senderName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(a.message ?? 'SOS Alert', style: const TextStyle(color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(_formatTime(a.timestamp), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        const SizedBox(width: 12),
                                        if (a.latitude != null && a.longitude != null)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlertMapScreen(latitude: a.latitude!, longitude: a.longitude!, senderName: a.senderName)));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                              child: const Text('Live location', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (a.latitude != null && a.longitude != null) {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlertMapScreen(latitude: a.latitude!, longitude: a.longitude!, senderName: a.senderName)));
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
