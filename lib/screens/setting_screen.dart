import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../services/auto_sync_auth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

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

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  // Settings with proper state management
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _soundAlertsEnabled = true;
  bool _vibrationEnabled = true;
  // removed offline mode setting per recent changes
  double _autoSOSDelay = 10.0;
  String _emergencySound = 'siren';
  // GPS accuracy removed from settings

  Map<String, dynamic> _syncStatus = {
    'isInitialized': false,
    'isSyncing': false,
    'hasAuthToken': false,
  };

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AudioPlayer _audioPlayer;
  String? _playingSound;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _updateSyncStatus();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _playingSound = null);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _locationSharingEnabled = prefs.getBool('locationSharing') ?? true;
      _soundAlertsEnabled = prefs.getBool('soundAlerts') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? true;
      _autoSOSDelay = prefs.getDouble('autoSOSDelay') ?? 10.0;
      _emergencySound = prefs.getString('emergencySound') ?? 'siren';
      // locationAccuracy preference removed
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _updateSyncStatus() async {
    try {
      final status = AutoSyncAuthManager.instance.getSyncStatus();
      setState(() {
        _syncStatus = status;
      });
    } catch (e) {
      print('Error getting sync status: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFF8FAFC),
            ],
            stops: [0.0, 0.3, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          _buildEmergencySettingsCard(),
                          const SizedBox(height: 16),
                          _buildLocationPrivacyCard(),
                          const SizedBox(height: 16),
                          _buildNotificationsCard(),
                          const SizedBox(height: 16),
                          _buildSystemStatusCard(),
                          const SizedBox(height: 16),
                          _buildAccountActionsCard(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 6,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onNavigate(2),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _updateSyncStatus,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  // Quick actions removed from Settings per request.
  

  Widget _buildEmergencySettingsCard() {
    return _buildSettingsCard(
      'Emergency Settings',
      Icons.shield_rounded,
      const Color(0xFFEF4444),
      [
        _buildSliderTile(
          'SOS Alert Delay',
          'Countdown before alert is sent',
          _autoSOSDelay,
          5.0,
          30.0,
          (value) {
            setState(() => _autoSOSDelay = value);
            _saveSetting('autoSOSDelay', value);
          },
          '${_autoSOSDelay.round()}s',
        ),
        const Divider(height: 1),
        _buildSoundList(),
      ],
    );
  }

  Widget _buildLocationPrivacyCard() {
    return _buildSettingsCard(
      'Location & Privacy',
      Icons.location_on_rounded,
      const Color(0xFF10B981),
      [
        _buildSwitchTile(
          'Location Sharing',
          'Share location with emergency contacts',
          _locationSharingEnabled,
          (value) {
            setState(() => _locationSharingEnabled = value);
            _saveSetting('locationSharing', value);
          },
        ),
      ],
    );
  }

  Widget _buildSoundList() {
    final sounds = [
      {'value': 'siren', 'label': 'Siren', 'file': 'assets/sounds/police-siren-397963.mp3'},
      {'value': 'alarm', 'label': 'Alarm', 'file': null},
      {'value': 'beep', 'label': 'Beep', 'file': null},
      {'value': 'silent', 'label': 'Silent', 'file': null},
    ];

    return Column(
      children: sounds.map((s) {
        final value = s['value']?.toString() ?? '';
        final label = s['label']?.toString() ?? '';
        final file = s['file'] is String ? s['file'] as String : null;

        return Column(
          children: [
            _buildSoundOption(value, label, file),
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSoundOption(String value, String label, String? file) {
    final isSelected = _emergencySound == value;
    final isPlaying = _playingSound == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file != null ? 'Tap play to preview' : 'Not available locally',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill, color: isPlaying ? const Color(0xFFEF4444) : const Color(0xFF6366F1), size: 30),
                onPressed: () async {
                  if (file == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sound not available locally')));
                    return;
                  }
                  if (isPlaying) {
                    await _audioPlayer.stop();
                    setState(() => _playingSound = null);
                    return;
                  }
                  await _previewSound(file, value);
                },
              ),
              IconButton(
                icon: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)),
                onPressed: () {
                  setState(() => _emergencySound = value);
                  _saveSetting('emergencySound', value);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected: $label')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _previewSound(String filePath, String value) async {
    try {
      // verify asset exists
      await rootBundle.load(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sound asset not found')));
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(filePath));
      setState(() => _playingSound = value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error playing sound')));
    }
  }

  Widget _buildNotificationsCard() {
    return _buildSettingsCard(
      'Notifications & Alerts',
      Icons.notifications_rounded,
      const Color(0xFF06B6D4),
      [
        _buildSwitchTile(
          'Push Notifications',
          'Receive safety alerts and updates',
          _notificationsEnabled,
          (value) {
            setState(() => _notificationsEnabled = value);
            _saveSetting('notifications', value);
          },
        ),
        const Divider(height: 1),
        _buildSwitchTile(
          'Sound Alerts',
          'Play sounds for notifications',
          _soundAlertsEnabled,
          (value) {
            setState(() => _soundAlertsEnabled = value);
            _saveSetting('soundAlerts', value);
          },
        ),
        const Divider(height: 1),
        _buildSwitchTile(
          'Vibration',
          'Vibrate for emergency alerts',
          _vibrationEnabled,
          (value) {
            setState(() => _vibrationEnabled = value);
            _saveSetting('vibration', value);
          },
        ),
      ],
    );
  }

  Widget _buildSystemStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Auto-Sync Service',
              _syncStatus['isInitialized'] ? 'Active' : 'Inactive',
              _syncStatus['isInitialized'] ? const Color(0xFF10B981) : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Currently Syncing',
              _syncStatus['isSyncing'] ? 'Yes' : 'No',
              _syncStatus['isSyncing'] ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Authentication',
              _syncStatus['hasAuthToken'] ? 'Verified' : 'Not Verified',
              _syncStatus['hasAuthToken'] ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Safe Travel App v1.0.0'),
                    backgroundColor: Color(0xFF6366F1),
                  ),
                );
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF06B6D4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            'App version and information',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  widget.onSignout();
                }
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          Text(
                            'Sign out from your account',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    String displayValue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF6366F1),
              inactiveTrackColor: const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF6366F1),
              overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / 1).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<Map<String, String>> options,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: options.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(
                      option['label']!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}