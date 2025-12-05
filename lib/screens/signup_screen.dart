import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class SignUpScreen extends StatefulWidget {
  final Function(String, String, String, String) onSignup; // name, email, phone, password
  final VoidCallback onNavigateToSignin;
  final bool isLoading;
  final String errorMessage;

  const SignUpScreen({
    Key? key,
    required this.onSignup,
    required this.onNavigateToSignin,
    this.isLoading = false,
    this.errorMessage = '',
  }) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
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

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) {
      newErrors['name'] = 'Name is required';
    } else if (name.length < 2) {
      newErrors['name'] = 'Name must be at least 2 characters';
    } else if (name.length > 50) {
      newErrors['name'] = 'Name must be less than 50 characters';
    }

    if (email.isEmpty) {
      newErrors['email'] = 'Email is required';
    } else if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      newErrors['email'] = 'Email format is invalid';
    }

    if (phone.isEmpty) {
      newErrors['phone'] = 'Phone number is required';
    } else if (!RegExp(r'^[\+]?[1-9][0-9]{0,15}$').hasMatch(phone)) {
      newErrors['phone'] = 'Phone number format is invalid';
    }

    if (password.isEmpty) {
      newErrors['password'] = 'Password is required';
    } else if (password.length < 6) {
      newErrors['password'] = 'Password must be at least 6 characters';
    }

    if (confirm != password) {
      newErrors['confirmPassword'] = 'Passwords do not match';
    }

    setState(() {
      _errors = newErrors;
    });
  }

  void _handleSubmit() {
    final valid = _formKey.currentState?.validate() ?? true;
    _validateForm();

    if (valid && _errors.isEmpty && !widget.isLoading) {
      widget.onSignup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: Responsive.s(context, 48)),

              Column(
                children: [
                  Container(
                    width: Responsive.s(context, 80),
                    height: Responsive.s(context, 80),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add,
                      size: Responsive.s(context, 40),
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  SizedBox(height: Responsive.s(context, 24)),
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: Responsive.s(context, 32),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: Responsive.s(context, 8)),
                  Text(
                    'Sign up to get started',
                    style: TextStyle(
                      fontSize: Responsive.s(context, 16),
                      color: Colors.blue.shade100,
                    ),
                  ),
                ],
              ),

              SizedBox(height: Responsive.s(context, 24)),

              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.s(context, 24)),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: Responsive.s(context, 16)),

                            if (widget.errorMessage.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(Responsive.s(context, 12)),
                                margin: EdgeInsets.only(bottom: Responsive.s(context, 16)),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(Responsive.s(context, 8)),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                                    SizedBox(width: Responsive.s(context, 8)),
                                    Expanded(
                                      child: Text(
                                        widget.errorMessage,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: Responsive.s(context, 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            _buildTextField(
                              label: 'Full Name',
                              controller: _nameController,
                              error: _errors['name'],
                              onChanged: () => _clearError('name'),
                              keyboardType: TextInputType.name,
                              validator: (val) {
                                final v = val?.trim() ?? '';
                                if (v.isEmpty) return 'Name is required';
                                if (v.length < 2) return 'Name must be at least 2 characters';
                                if (v.length > 50) return 'Name must be less than 50 characters';
                                return null;
                              },
                            ),
                            SizedBox(height: Responsive.s(context, 16)),

                            _buildTextField(
                              label: 'Email',
                              controller: _emailController,
                              error: _errors['email'],
                              onChanged: () => _clearError('email'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                final v = val?.trim() ?? '';
                                if (v.isEmpty) return 'Email is required';
                                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Email format is invalid';
                                return null;
                              },
                            ),
                            SizedBox(height: Responsive.s(context, 16)),

                            _buildTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              error: _errors['phone'],
                              onChanged: () => _clearError('phone'),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                final v = val?.trim() ?? '';
                                if (v.isEmpty) return 'Phone number is required';
                                if (!RegExp(r'^[\+]?[1-9][0-9]{0,15}$').hasMatch(v)) return 'Phone number format is invalid';
                                return null;
                              },
                            ),
                            SizedBox(height: Responsive.s(context, 16)),

                            _buildTextField(
                              label: 'Password',
                              controller: _passwordController,
                              error: _errors['password'],
                              obscureText: !_showPassword,
                              onChanged: () => _clearError('password'),
                              validator: (val) {
                                final v = val ?? '';
                                if (v.isEmpty) return 'Password is required';
                                if (v.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              label: 'Confirm Password',
                              controller: _confirmPasswordController,
                              error: _errors['confirmPassword'],
                              obscureText: !_showConfirmPassword,
                              onChanged: () => _clearError('confirmPassword'),
                              validator: (val) {
                                final v = val ?? '';
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword = !_showConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.s(context, 24)),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: Responsive.s(context, 48),
                              child: ElevatedButton(
                                onPressed: widget.isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
                                  ),
                                ),
                                child: widget.isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: Responsive.s(context, 18),
                                            height: Responsive.s(context, 18),
                                            child: const CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: Responsive.s(context, 12)),
                                          Text(
                                            'Signing up...',
                                            style: TextStyle(
                                              fontSize: Responsive.s(context, 16),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontSize: Responsive.s(context, 18),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: Responsive.s(context, 16)),

                            // Sign In Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: Responsive.s(context, 14),
                                  ),
                                ),
                                TextButton(
                                  onPressed: widget.onNavigateToSignin,
                                  child: Text(
                                    'Sign in',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: Responsive.s(context, 14),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? error,
    bool obscureText = false,
    VoidCallback? onChanged,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.s(context, 16),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: Responsive.s(context, 8)),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 16), vertical: Responsive.s(context, 16)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.grey.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 2,
              ),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: Responsive.s(context, 4)),
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
