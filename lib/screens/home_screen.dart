import 'package:flutter/material.dart';
import '../models/user.dart';
import '../widgets/bottom_navigation.dart';
import '../services/offline_database_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/fake_call_service.dart';
import '../services/emergency_siren_service.dart';
import 'fake_call_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/responsive.dart';

class HomeScreen extends StatefulWidget {
  final User? user;
  final Function(int) onNavigate;

  const HomeScreen({Key? key, required this.user, required this.onNavigate})
    : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Emergency contacts data
  int _emergencyContactsCount = 0;
  bool _isLoadingContacts = true;

  // Emergency services
  final FakeCallService _fakeCallService = FakeCallService();
  final EmergencySirenService _sirenService = EmergencySirenService();
  bool _isSirenActive = false;

  // Location/address state
  String _currentAddress = 'Fetching address...';
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);

    // Load emergency contacts data
    _loadEmergencyContacts();

    // Load current location/address
    _fetchCurrentAddress();
  }

  /// Fetch current location and address
  Future<void> _fetchCurrentAddress() async {
    setState(() {
      _isLoadingAddress = true;
      _currentAddress = 'Fetching address...';
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _currentAddress = 'Location services disabled';
          _isLoadingAddress = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _currentAddress = 'Location permission denied';
            _isLoadingAddress = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentAddress = 'Location permission permanently denied';
          _isLoadingAddress = false;
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
        if (!mounted) return;
        setState(() {
          _currentAddress = address.isNotEmpty ? address : 'Address not available';
          _isLoadingAddress = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _currentAddress = 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('Error fetching address: $e');
      if (!mounted) return;
      setState(() {
        _currentAddress = 'Error fetching address';
        _isLoadingAddress = false;
      });
    }
  }

  /// Load emergency contacts from local SQLite database
  Future<void> _loadEmergencyContacts() async {
    try {
      setState(() {
        _isLoadingContacts = true;
      });

      // Try to get contacts from API first, then fallback to local database
      try {
        final apiContacts = await EmergencyContactService.getAllContacts();
        if (!mounted) return;
        setState(() {
          _emergencyContactsCount = apiContacts.length;
          _isLoadingContacts = false;
        });
      } catch (apiError) {
        // Fallback to local database
        final dbService = OfflineDatabaseService.instance;
        final localContacts = await dbService.getCachedEmergencyContacts();
        if (!mounted) return;
        setState(() {
          _emergencyContactsCount = localContacts.length;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      print('Error loading emergency contacts: $e');
      if (!mounted) return;
      setState(() {
        _emergencyContactsCount = 0;
        _isLoadingContacts = false;
      });
    }
  }

  /// Handle fake call button press
  void _handleFakeCall() {
    print('📱 Fake Call button pressed from home screen');
    
    // Start fake call with 3-second delay
    _fakeCallService.startFakeCall(
      onCallReceived: () {
        // Navigate to fake call screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FakeCallScreen(
              callerName: 'Mom',
              callerNumber: 'Mobile',
            ),
            fullscreenDialog: true,
          ),
        );
      },
      delaySeconds: 3,
    );
    
    // Show snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📱 Incoming call in 3 seconds...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Handle emergency siren button press
  Future<void> _handleSirenToggle() async {
    print('🚨 Siren button pressed from home screen');
    
    final isPlaying = await _sirenService.toggleSiren();
    
    setState(() {
      _isSirenActive = isPlaying;
    });
    
    // Show snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPlaying ? '🚨 Emergency Siren Activated' : '🔇 Siren Stopped',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isPlaying ? Colors.red : Colors.grey,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      {
        'title': 'Start Navigation',
        'description': 'Get safest route to your destination',
        'icon': Icons.map_rounded,
        'color': const Color(0xFF6366F1),
        'action': () => widget.onNavigate(3),
      },
      {
        'title': 'Emergency SOS',
        'description': 'Quick access to emergency services',
        'icon': Icons.shield_rounded,
        'color': const Color(0xFFEF4444),
        'action': () => widget.onNavigate(4),
      },
      {
        'title': 'Fake Call',
        'description': 'Simulate incoming call for safety',
        'icon': Icons.phone_in_talk,
        'color': const Color(0xFF10B981),
        'action': _handleFakeCall,
      },
      {
        'title': _isSirenActive ? 'Stop Siren' : 'Emergency Siren',
        'description': _isSirenActive ? 'Tap to stop alarm' : 'Activate loud emergency alarm',
        'icon': _isSirenActive ? Icons.volume_off : Icons.emergency,
        'color': _isSirenActive ? const Color(0xFF6B7280) : const Color(0xFFEF4444),
        'action': _handleSirenToggle,
      },
      {
        'title': 'Emergency Contacts',
        'description': 'Manage your emergency contacts',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF10B981),
        'action': () => widget.onNavigate(5),
      },
      {
        'title': 'Profile',
        'description': 'View and edit your profile',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF8B5CF6),
        'action': () => widget.onNavigate(7),
      },
    ];

    final Size _screenSize = MediaQuery.of(context).size;
    final double _scale = Responsive.scale(context);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 252, 250, 248),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: CustomScrollView(
              slivers: [
                // Modern App Bar with Hero Section
                SliverAppBar(
                  expandedHeight: Responsive.s(context, 290),
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.fromARGB(255, 99, 241, 196),
                            Color.fromARGB(255, 143, 92, 246),
                            Color.fromARGB(255, 6, 147, 212),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Animated background pattern
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: BackgroundPatternPainter(
                                    _pulseAnimation.value,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Hero content
                          SafeArea(
                            child: Padding(
                              padding: EdgeInsets.all(Responsive.s(context, 24)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: Responsive.s(context, 45),
                                            height: Responsive.s(context, 48),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(Responsive.s(context, 16)),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.4,
                                                ),
                                                width: Responsive.s(context, 2),
                                              ),
                                            ),

                                            child: Padding(
                                              padding:
                                                  EdgeInsets.all(Responsive.s(context, 16)),
                                              child: Icon(
                                                Icons.security_outlined,
                                                color: Colors.white,
                                                size: Responsive.s(context, 37),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12 * _scale),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Safe Travel',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 14 * _scale,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Your Safety Companion',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12 * _scale,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () => widget.onNavigate(6),
                                          icon: const Icon(
                                            Icons.settings_rounded,
                                            color: Colors.white,
                                            size: 22 * 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: Responsive.s(context, 32)),
                                  // Hero text
                                  Text(
                                    'Hello,\n${widget.user?.name.split(' ').first ?? 'Traveler'}! 👋',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.s(context, 32),
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: Responsive.s(context, 12)),
                                  Text(
                                    'Ready for your next safe journey?',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: Responsive.s(context, 16),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(height: Responsive.s(context, 24)),
                                  // Status indicators
                                  Row(
                                    children: [
                                      _buildStatusChip(
                                        icon: Icons.wifi_rounded,
                                        text: 'Online',
                                        color: const Color(0xFF10B981),
                                        onTap: null,
                                      ),
                                      SizedBox(width: 12 * _scale),
                                      _buildStatusChip(
                                        icon: Icons.location_on_rounded,
                                        text: 'GPS Active',
                                        color: const Color(0xFF06B6D4),
                                        onTap: () => widget.onNavigate(
                                          3,
                                        ), // Navigate to map screen
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Actions Grid
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.s(context, 26),
                    vertical: Responsive.s(context, 16),
                  ),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final action = quickActions[index];
                      return Transform.translate(
                        offset: Offset(
                          0,
                          _slideAnimation.value * (index + 1) * 20,
                        ),
                        child: _buildActionCard(action, index),
                      );
                    }, childCount: quickActions.length),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: _screenSize.width > 900
                          ? 280
                          : _screenSize.width > 700
                              ? 230
                              : 180,
                      crossAxisSpacing: Responsive.s(context, 13),
                      mainAxisSpacing: Responsive.s(context, 13),
                      childAspectRatio: 1.0,
                    ),
                  ),
                ),

                // Current Location Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 24)),
                    child: _buildLocationCard(),
                  ),
                ),

                // Safety Status Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.s(context, 24)),
                    child: _buildSafetyStatusCard(),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 2, // Screen index 2 (Home)
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
            child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: (action['color'] as Color).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
                child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: action['action'] as VoidCallback,
                borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double cardSize = constraints.biggest.shortestSide > 0
                                ? constraints.biggest.shortestSide
                                : (MediaQuery.of(context).size.width * 0.25);
                            // Icon box is a fraction of the card size; keep it proportional
                            final double iconBoxSize = (cardSize * 0.36).clamp(cardSize * 0.22, cardSize * 0.5);
                            final double iconSize = (iconBoxSize * 0.52).clamp(20.0, 96.0);
                            final double horizontalPadding = (cardSize * 0.06).clamp(8.0, 20.0);
                            final double verticalPadding = (cardSize * 0.06).clamp(8.0, 20.0);
                            final double titleFont = (cardSize * 0.10).clamp(12.0, 18.0);
                            final double descFont = (cardSize * 0.075).clamp(10.0, 14.0);

                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: iconBoxSize,
                                      height: iconBoxSize,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            (action['color'] as Color).withOpacity(0.18),
                                            (action['color'] as Color).withOpacity(0.06),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(iconBoxSize * 0.22),
                                        border: Border.all(
                                          color: (action['color'] as Color).withOpacity(0.22),
                                          width: (iconBoxSize * 0.03).clamp(1.0, 2.5),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          action['icon'] as IconData,
                                          color: action['color'] as Color,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: cardSize * 0.08),
                                    Flexible(
                                      child: Text(
                                        action['title'] as String,
                                        style: TextStyle(
                                          fontSize: titleFont,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1F2937),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(height: cardSize * 0.03),
                                    Flexible(
                                      child: Text(
                                        action['description'] as String,
                                        style: TextStyle(
                                          fontSize: descFont,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey[600],
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => widget.onNavigate(3), // Navigate to map screen
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF06B6D4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentAddress,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isLoadingAddress ? 'Updating...' : 'Updated just now',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyStatusCard() {
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'All systems active',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildStatusRow(
              'Emergency Contacts',
              _isLoadingContacts
                  ? 'Loading...'
                  : '$_emergencyContactsCount contact${_emergencyContactsCount == 1 ? '' : 's'}',
              const Color(0xFF10B981),
            ),
            _buildStatusRow(
              'Location Sharing',
              'Active',
              const Color(0xFF06B6D4),
            ),
            _buildStatusRow('Offline Mode', 'Ready', const Color(0xFF8B5CF6)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for background pattern
class BackgroundPatternPainter extends CustomPainter {
  final double animationValue;

  BackgroundPatternPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw animated circles
    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * animationValue;
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.2),
        radius,
        paint,
      );
    }

    // Draw animated lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final startY = (i * 40.0) + (animationValue * 20);
      canvas.drawLine(
        Offset(0, startY),
        Offset(size.width * 0.3, startY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(BackgroundPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
