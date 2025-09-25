import 'package:flutter/material.dart';

class VerificationStatusSection extends StatelessWidget {
  const VerificationStatusSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final verificationItems = [
      {'label': 'Email Verified', 'status': 'verified', 'icon': Icons.email},
      {'label': 'Phone Verified', 'status': 'verified', 'icon': Icons.phone},
      {'label': 'Emergency Contacts', 'status': 'verified', 'icon': Icons.shield},
      {'label': 'Location Services', 'status': 'verified', 'icon': Icons.location_on},
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
              'Verification Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Column(
              children: verificationItems.map((item) {
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 12),
                          Text(
                            item['label'] as String,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item['status'] == 'verified' ? Color(0xFF10B981) : Colors.yellow.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              item['status'] == 'verified' ? 'Verified' : 'Pending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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