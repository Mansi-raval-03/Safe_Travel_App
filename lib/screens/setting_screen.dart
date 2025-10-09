import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onSignout;

  const SettingsScreen({
    Key? key,
    required this.onNavigate,
    required this.onSignout,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> settings = {
    'notifications': true,
    'locationSharing': true,
    'autoSOSDelay': 10.0,
    'soundAlerts': true,
    'vibration': true,
    'darkMode': false,
    'offlineMode': true,
    'batterySaver': false,
    'emergencySound': 'siren',
    'locationAccuracy': 'high',
  };

  void _updateSetting(String key, dynamic value) {
    setState(() {
      settings[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Status Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 4),
                        Container(
                          width: 16,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 4),
                        Container(
                          width: 16,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Header
          Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onNavigate(2), // Home screen
                    icon: Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.all(4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.settings, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Quick Actions
                    Container(
                      margin: EdgeInsets.only(bottom: 24),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                        children: [
                          _buildQuickAction('Profile', Icons.person, () => widget.onNavigate(7)),
                          _buildQuickAction('Emergency', Icons.shield, () => widget.onNavigate(5)),
                          _buildQuickAction('Privacy', Icons.lock, () {}),
                          _buildQuickAction('Help', Icons.help, () {}),
                        ],
                      ),
                    ),

                    // Emergency Settings
                    _buildSettingsCard(
                      'Emergency Settings',
                      Icons.shield,
                      Color(0xFF3B82F6),
                      [
                        _buildSliderSetting(
                          'SOS Alert Delay',
                          'Countdown time before SOS alert is sent',
                          'autoSOSDelay',
                          5.0,
                          30.0,
                          'seconds',
                        ),
                        _buildDropdownSetting(
                          'Emergency Alert Sound',
                          'Sound played during emergency alerts',
                          'emergencySound',
                          [
                            {'value': 'siren', 'label': 'Siren'},
                            {'value': 'alarm', 'label': 'Alarm'},
                            {'value': 'beep', 'label': 'Beep'},
                            {'value': 'silent', 'label': 'Silent'},
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Location & Privacy
                    _buildSettingsCard(
                      'Location & Privacy',
                      Icons.location_on,
                      Color(0xFF10B981),
                      [
                        _buildSwitchSetting(
                          'Location Sharing',
                          'Share location with emergency contacts',
                          'locationSharing',
                        ),
                        _buildDropdownSetting(
                          'Location Accuracy',
                          'GPS precision level',
                          'locationAccuracy',
                          [
                            {'value': 'high', 'label': 'High (1-3m)'},
                            {'value': 'medium', 'label': 'Medium (10m)'},
                            {'value': 'low', 'label': 'Low (100m)'},
                          ],
                        ),
                        _buildSwitchSetting(
                          'Offline Mode',
                          'Enable emergency features without internet',
                          'offlineMode',
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Notifications & Alerts
                    _buildSettingsCard(
                      'Notifications & Alerts',
                      Icons.notifications,
                      Color(0xFFEF4444),
                      [
                        _buildSwitchSetting(
                          'Push Notifications',
                          'Receive safety alerts and updates',
                          'notifications',
                        ),
                        _buildSwitchSetting(
                          'Sound Alerts',
                          'Play sounds for notifications',
                          'soundAlerts',
                        ),
                        _buildSwitchSetting(
                          'Vibration',
                          'Vibrate for emergency alerts',
                          'vibration',
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Device & Performance
                    _buildSettingsCard(
                      'Device & Performance',
                      Icons.smartphone,
                      Color(0xFF8B5CF6),
                      [
                        _buildSwitchSetting(
                          'Dark Mode',
                          'Use dark theme for better visibility',
                          'darkMode',
                        ),
                        _buildSwitchSetting(
                          'Battery Saver',
                          'Optimize for longer battery life',
                          'batterySaver',
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // System Status
                    _buildSystemStatusCard(),

                    SizedBox(height: 16),

                    // Data & Storage
                    _buildDataStorageCard(),

                    SizedBox(height: 16),

                    // Account Actions
                    _buildAccountCard(),

                    SizedBox(height: 16),

                    // App Info
                    _buildAppInfoCard(),

                    // Bottom padding for navigation
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 6, // Settings screen - no corresponding bottom nav item
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade700),
                SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(String title, IconData icon, Color iconColor, List<Widget> children) {
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
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(String title, String description, String key) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Switch(
            value: settings[key] as bool,
            onChanged: (value) => _updateSetting(key, value),
            activeColor: Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(String title, String description, String key, double min, double max, String unit) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(settings[key] as double).toInt()} $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Slider(
            value: settings[key] as double,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: Color(0xFF3B82F6),
            onChanged: (value) => _updateSetting(key, value),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(String title, String description, String key, List<Map<String, String>> options) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: settings[key] as String,
                style: TextStyle(fontSize: 12, color: Colors.black),
                onChanged: (value) => _updateSetting(key, value),
                items: options.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(option['label']!),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
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
            Row(
              children: [
                Icon(Icons.storage, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2,
              children: [
                _buildStatusItem('Network', 'Connected', Icons.wifi, Color(0xFF10B981)),
                _buildStatusItem('GPS', 'Active', Icons.location_on, Color(0xFF3B82F6)),
                _buildStatusItem('Battery', '87%', Icons.battery_full, Color(0xFF10B981)),
                _buildStatusItem('Safety', 'Ready', Icons.shield, Color(0xFF10B981)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, String status, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStorageCard() {
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
              'Data & Storage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            _buildActionItem('Offline Maps', 'Download maps for offline use', 'Manage'),
            _buildActionItem('Emergency Data', 'Backup and sync emergency contacts', 'Backup'),
            _buildActionItem('Clear Cache', 'Free up storage space', 'Clear'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
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
              'Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            _buildActionItem('Export Data', 'Download your data and settings', 'Export'),
            _buildActionItem('Privacy Policy', 'View our privacy policy', 'View'),
            _buildSignoutItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, String description, String action) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              action,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignoutItem() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEF4444),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sign out of your account',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: widget.onSignout,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            side: BorderSide(color: Color(0xFFEF4444)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 4),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Safe Travel App v2.1.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Last updated: September 16, 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '© 2025 Safe Travel Inc. All rights reserved.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}