import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  final Function(String, String, String, String) onSignup;
  final VoidCallback onNavigateToSignin;

  const SignupScreen({
    Key? key,
    required this.onSignup,
    required this.onNavigateToSignin,
  }) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    if (_passwordController.text.isEmpty) {
      newErrors['password'] = 'Password is required';
    } else if (_passwordController.text.length < 6) {
      newErrors['password'] = 'Password must be at least 6 characters';
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      newErrors['confirmPassword'] = 'Passwords do not match';
    }

    setState(() {
      _errors = newErrors;
    });
  }

  void _handleSubmit() {
    _validateForm();
    if (_errors.isEmpty) {
      widget.onSignup(
        _nameController.text,
        _emailController.text,
        _phoneController.text,
        _passwordController.text,
      );
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String fieldKey,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => _clearError(fieldKey),
          obscureText: isPassword && !_showPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _errors.containsKey(fieldKey) ? Colors.red : Colors.grey.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFF10B981),
                width: 2,
              ),
            ),
            suffixIcon: isPassword ? IconButton(
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
              ),
            ) : null,
          ),
        ),
        if (_errors.containsKey(fieldKey))
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              _errors[fieldKey]!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF047857)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status Bar
              Container(
                height: 48,
                color: Colors.black.withOpacity(0.2),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '9:41',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Spacer(),
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
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(height: 32),
                      
                      // Logo and Title
                      Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.shield,
                              size: 40,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Join Safe Travel',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create your account for safer journeys',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade100,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Form Container
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  SizedBox(height: 16),
                                  
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          // Name Field
                                          _buildTextField(
                                            controller: _nameController,
                                            label: 'Full Name',
                                            hint: 'Enter your full name',
                                            fieldKey: 'name',
                                          ),
                                          
                                          SizedBox(height: 16),
                                          
                                          // Email Field
                                          _buildTextField(
                                            controller: _emailController,
                                            label: 'Email',
                                            hint: 'Enter your email',
                                            fieldKey: 'email',
                                            keyboardType: TextInputType.emailAddress,
                                          ),
                                          
                                          SizedBox(height: 16),
                                          
                                          // Phone Field
                                          _buildTextField(
                                            controller: _phoneController,
                                            label: 'Phone Number',
                                            hint: '+1 (555) 123-4567',
                                            fieldKey: 'phone',
                                            keyboardType: TextInputType.phone,
                                          ),
                                          
                                          SizedBox(height: 16),
                                          
                                          // Password Field
                                          _buildTextField(
                                            controller: _passwordController,
                                            label: 'Password',
                                            hint: 'Create a password',
                                            fieldKey: 'password',
                                            isPassword: true,
                                          ),
                                          
                                          SizedBox(height: 16),
                                          
                                          // Confirm Password Field
                                          _buildTextField(
                                            controller: _confirmPasswordController,
                                            label: 'Confirm Password',
                                            hint: 'Confirm your password',
                                            fieldKey: 'confirmPassword',
                                            isPassword: true,
                                          ),
                                          
                                          SizedBox(height: 24),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Create Account Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Sign In Link
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: widget.onNavigateToSignin,
                                        child: Text(
                                          'Sign in',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}