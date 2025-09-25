import 'package:flutter/material.dart';
import '../models/user.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/basic_info_section.dart';
import '../widgets/profile/emergency_info_section.dart';
import '../widgets/profile/profile_stats_section.dart';
import '../widgets/profile/verification_status_section.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  final Function(User) onUpdateUser;
  final Function(int) onNavigate;

  const ProfileScreen({
    Key? key,
    required this.user,
    required this.onUpdateUser,
    required this.onNavigate,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  Map<String, String> _errors = {};
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyInfoController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _allergiesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _emergencyInfoController = TextEditingController();
    _medicalConditionsController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _allergiesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyInfoController.dispose();
    _medicalConditionsController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
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

    setState(() {
      _errors = newErrors;
    });
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
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = widget.user?.name ?? '';
      _emailController.text = widget.user?.email ?? '';
      _phoneController.text = widget.user?.phone ?? '';
      _isEditing = false;
      _errors.clear();
    });
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildStatusBar(),
          _buildHeader(),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ProfileHeader(
                      user: widget.user,
                      isEditing: _isEditing,
                    ),
                    SizedBox(height: 16),
                    BasicInfoSection(
                      user: widget.user,
                      isEditing: _isEditing,
                      nameController: _nameController,
                      emailController: _emailController,
                      phoneController: _phoneController,
                      errors: _errors,
                      onClearError: _clearError,
                    ),
                    SizedBox(height: 16),
                    EmergencyInfoSection(
                      isEditing: _isEditing,
                      emergencyInfoController: _emergencyInfoController,
                      medicalConditionsController: _medicalConditionsController,
                      bloodTypeController: _bloodTypeController,
                      allergiesController: _allergiesController,
                    ),
                    SizedBox(height: 16),
                    ProfileStatsSection(),
                    SizedBox(height: 16),
                    VerificationStatusSection(),
                    SizedBox(height: 16),
                    _buildQuickActions(),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 4,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
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
                '9:41',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Text(
                'Profile',
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
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => widget.onNavigate(2),
                  icon: Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.all(4),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.person, color: Color(0xFF3B82F6)),
                SizedBox(width: 8),
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (!_isEditing)
              OutlinedButton(
                onPressed: () => setState(() => _isEditing = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 4),
                    Text('Edit Profile'),
                  ],
                ),
              )
            else
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _cancelEdit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 16),
                        SizedBox(width: 4),
                        Text('Cancel'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => widget.onNavigate(5),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Column(
              children: [
                Icon(Icons.phone, size: 20),
                SizedBox(height: 4),
                Text(
                  'Emergency Contacts',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => widget.onNavigate(6),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Column(
              children: [
                Icon(Icons.shield, size: 20),
                SizedBox(height: 4),
                Text(
                  'Privacy Settings',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Column(
              children: [
                Icon(Icons.info, size: 20),
                SizedBox(height: 4),
                Text(
                  'Safety Tips',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}