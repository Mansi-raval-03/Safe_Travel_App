import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../models/user.dart';
import '../widgets/bottom_navigation.dart';
import '../services/emergency_contact_service.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  final Function(User) onUpdateUser;
  final VoidCallback onSignout;
  final Function(int) onNavigate;

  const ProfileScreen({
    Key? key,
    required this.user,
    required this.onUpdateUser,
    required this.onNavigate,
    required this.onSignout,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  bool _isEditing = false;
  Map<String, String> _errors = {};
  
  // Profile Image (placeholder for future implementation)
  String? _profileImageUrl;
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _emergencyContactsController;
  
  // Statistics from Database
  int _emergencyContactsCount = 0;

  int _safetyScore = 0;
  double _profileCompleteness = 0.0;
  int _activeDays = 0;

  // Safety tips data
  final List<Map<String, dynamic>> _safetyTipsList = [
    {
      'title': 'Share Your Location',
      'description': 'Always share your live location with trusted contacts when traveling alone.',
      'icon': Icons.location_on,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Stay Alert',
      'description': 'Keep your phone charged and stay aware of your surroundings at all times.',
      'icon': Icons.visibility,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Emergency Contacts',
      'description': 'Keep important emergency numbers saved and easily accessible.',
      'icon': Icons.phone,
      'color': Color(0xFFEF4444),
    },
    {
      'title': 'Safe Routes',
      'description': 'Use well-lit and populated routes, especially during night travel.',
      'icon': Icons.route,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Trust Your Instincts',
      'description': 'If something feels wrong, trust your gut and move to a safe location.',
      'icon': Icons.psychology,
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'SOS Features',
      'description': 'Familiarize yourself with emergency SOS features on your device.',
      'icon': Icons.sos,
      'color': Color(0xFFEC4899),
    },
  ];
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _loadProfileData();
  }
  
  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _bloodTypeController = TextEditingController();
    _allergiesController = TextEditingController();
    _medicalConditionsController = TextEditingController();
    _emergencyContactsController = TextEditingController();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    // Only start animations if widget is still mounted
    if (mounted) {
      _fadeController.forward();
      _slideController.forward();
    }
  }
  
  Future<void> _loadProfileData() async {
    try {
      // Load emergency contacts count
      final contacts = await EmergencyContactService.getAllContacts();
      _emergencyContactsCount = contacts.length;
      
      // Load statistics from database

      
      // Calculate profile completeness
      _calculateProfileCompleteness();
      
      // Set safety score based on profile completeness and contacts
      _safetyScore = (_profileCompleteness * 70 + 
                     (_emergencyContactsCount > 0 ? 30 : 0)).round();
      
      // Simulate active days (could be loaded from user preferences or database)
      _activeDays = DateTime.now().difference(DateTime(2025, 1, 1)).inDays;
      
      if (mounted) {
        setState(() {
          // Loading complete
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        setState(() {
          // Loading failed
        });
      }
    }
  }
  
  void _calculateProfileCompleteness() {
    double completeness = 0.0;
    int totalFields = 6;
    
    final userName = widget.user?.name;
    if (userName != null && userName.isNotEmpty) completeness += 1.0;
    final userEmail = widget.user?.email;
    if (userEmail != null && userEmail.isNotEmpty) completeness += 1.0;
    final userPhone = widget.user?.phone;
    if (userPhone != null && userPhone.isNotEmpty) completeness += 1.0;
    if (_bloodTypeController.text.isNotEmpty) completeness += 1.0;
    if (_emergencyContactsCount > 0) completeness += 1.0;
    if (_profileImageUrl != null) completeness += 1.0;
    
    _profileCompleteness = (completeness / totalFields) * 100;
  }

  @override
  void dispose() {
    // Stop and dispose animation controllers to prevent callbacks after unmount
    _fadeController.stop();
    _slideController.stop();
    _fadeController.dispose();
    _slideController.dispose();
    
    // Dispose text controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _emergencyContactsController.dispose();
    
    super.dispose();
  }

  void _validateForm() {
    Map<String, String> newErrors = {};

    if (_nameController.text.trim().isEmpty) {
      newErrors['name'] = 'Name is required';
    }

    if (_emailController.text.trim().isEmpty) {
      newErrors['email'] = 'Email is required';
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      newErrors['email'] = 'Email format is invalid';
    }

    if (_phoneController.text.trim().isEmpty) {
      newErrors['phone'] = 'Phone number is required';
    }

    if (mounted) {
      setState(() {
        _errors = newErrors;
      });
    }
  }

  void _saveProfile() {
    _validateForm();
    if (_errors.isEmpty && widget.user != null) {
      widget.onUpdateUser(
        widget.user!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  void _cancelEdit() {
    if (mounted) {
      setState(() {
        _nameController.text = widget.user?.name ?? '';
        _emailController.text = widget.user?.email ?? '';
        _phoneController.text = widget.user?.phone ?? '';
        _isEditing = false;
        _errors.clear();
      });
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field) && mounted) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Colors.white,
            ],
            stops: [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.all(Responsive.s(context, 20)),
                        child: Column(
                          children: [
                            _buildProfileCard(),
                            SizedBox(height: Responsive.s(context, 20)),
                            _buildStatsCards(),
                            SizedBox(height: Responsive.s(context, 20)),
                            _buildEmergencyInfoCard(),
                            SizedBox(height: Responsive.s(context, 20)),
                            _buildQuickActionsGrid(),
                            SizedBox(height: Responsive.s(context, 20)),
                            _buildAboutSignOutCard(),
                            SizedBox(height: Responsive.s(context, 100)),
                          ],
                        ),
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
        currentIndex: 7, // Screen index 7 (Profile)
        onNavigate: widget.onNavigate,
      ),
    );
  }



  // Modern Header with Gradient Background
  Widget _buildModernHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 20), vertical: Responsive.s(context, 15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onNavigate(2),
                icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: EdgeInsets.all(8),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.s(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!_isEditing)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: () {
                  if (mounted) {
                    setState(() => _isEditing = true);
                  }
                },
                icon: Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit Profile',
              ),
            )
          else
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: _saveProfile,
                    icon: Icon(Icons.check, color: Colors.white),
                    tooltip: 'Save Changes',
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: _cancelEdit,
                    icon: Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cancel',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Modern Profile Card
  Widget _buildProfileCard() {
    return Container(
      padding: EdgeInsets.all(Responsive.s(context, 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar with Status Ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: Responsive.s(context, 100),
                height: Responsive.s(context, 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: CircleAvatar(
                  radius: Responsive.s(context, 48),
                  backgroundColor: Colors.transparent,
                  backgroundImage: _profileImageUrl != null 
                      ? NetworkImage(_profileImageUrl!) 
                      : null,
                  child: _profileImageUrl == null
                      ? Text(
                          () {
                            final userName = widget.user?.name;
                            return (userName != null && userName.isNotEmpty) 
                                ? userName[0].toUpperCase()
                                : 'U';
                          }(),
                          style: TextStyle(
                            fontSize: Responsive.s(context, 36),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              // Profile Completeness Ring
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: _profileCompleteness / 100,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _profileCompleteness > 80
                        ? Colors.green
                        : _profileCompleteness > 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.s(context, 16)),
          
          // User Name and Email
          if (_isEditing) ...[
            _buildEditTextField('Full Name', _nameController, Icons.person),
            SizedBox(height: 12),
            _buildEditTextField('Email', _emailController, Icons.email),
            SizedBox(height: 12),
            _buildEditTextField('Phone', _phoneController, Icons.phone),
          ] else ...[
            Text(
              widget.user?.name ?? 'Unknown User',
              style: TextStyle(
                fontSize: Responsive.s(context, 24),
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: Responsive.s(context, 4)),
            Text(
              widget.user?.email ?? 'No email provided',
              style: TextStyle(
                fontSize: Responsive.s(context, 16),
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: Responsive.s(context, 8)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 12), vertical: Responsive.s(context, 6)),
              decoration: BoxDecoration(
                color: _profileCompleteness > 80
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Profile ${_profileCompleteness.toInt()}% Complete',
                style: TextStyle(
                  fontSize: Responsive.s(context, 12),
                  fontWeight: FontWeight.w600,
                  color: _profileCompleteness > 80 ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Statistics Cards
  Widget _buildStatsCards() {
    // Emergency Contacts stat removed per request
    return const SizedBox.shrink();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Emergency Information Card
  Widget _buildEmergencyInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services_outlined, 
                   color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 12),
              Text(
                'Emergency Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          if (_isEditing) ...[
            _buildEditTextField('Blood Type', _bloodTypeController, Icons.bloodtype),
            SizedBox(height: 12),
            _buildEditTextField('Allergies', _allergiesController, Icons.warning_amber_outlined),
            SizedBox(height: 12),
            _buildEditTextField('Medical Conditions', _medicalConditionsController, Icons.local_hospital_outlined),
          ] else ...[
            _buildInfoRow('Blood Type', _bloodTypeController.text.isEmpty ? 'Not specified' : _bloodTypeController.text, Icons.bloodtype),
            _buildInfoRow('Allergies', _allergiesController.text.isEmpty ? 'None specified' : _allergiesController.text, Icons.warning_amber_outlined),
            _buildInfoRow('Medical Conditions', _medicalConditionsController.text.isEmpty ? 'None specified' : _medicalConditionsController.text, Icons.local_hospital_outlined),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutSignOutCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        errorText: _errors[label.toLowerCase().replaceAll(' ', '')],
      ),
      onChanged: (value) => _clearError(label.toLowerCase().replaceAll(' ', '')),
    );
  }

  // Enhanced Quick Actions Grid
  Widget _buildQuickActionsGrid() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildActionCard(
                'Safety Tips',
                Icons.tips_and_updates_outlined,
                Color(0xFF10B981),
                _showSafetyTipsDialog,
              ),
              _buildActionCard(
                'Privacy Settings',
                Icons.privacy_tip_outlined,
                Color(0xFF8B5CF6),
                () => widget.onNavigate(6),
              ),
              _buildActionCard(
                'App Settings',
                Icons.settings_outlined,
                Color(0xFFF59E0B),
                () => widget.onNavigate(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade50,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Safety Tips Dialog
  void _showSafetyTipsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Safety Tips',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _safetyTipsList.map((tip) => _buildSafetyTipCard(tip)).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSafetyTipCard(Map<String, dynamic> tip) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tip['icon'] as IconData,
                color: tip['color'] as Color,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            tip['description'] as String,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}