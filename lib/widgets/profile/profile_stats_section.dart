import 'package:flutter/material.dart';

class ProfileStatsSection extends StatelessWidget {
  const ProfileStatsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileStats = [
      {'label': 'Account Created', 'value': 'Sept 2025', 'icon': Icons.calendar_today},
      {'label': 'Emergency Contacts', 'value': '3', 'icon': Icons.phone},
      {'label': 'Safe Trips', 'value': '27', 'icon': Icons.check_circle},
      {'label': 'Verification Status', 'value': 'Verified', 'icon': Icons.shield},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: profileStats.map((stat) {
                return Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        stat['icon'] as IconData,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        stat['value'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        stat['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}