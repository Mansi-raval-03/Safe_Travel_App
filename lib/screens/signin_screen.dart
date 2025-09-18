import 'package:flutter/material.dart';

class SigninScreen extends StatefulWidget {
  final Function(String, String) onSignin;
  final VoidCallback onNavigateToSignup;

  const SigninScreen({
    Key? key,
    required this.onSignin,
    required this.onNavigateToSignup,
  }) : super(key: key);

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    Map<String, String> newErrors = {};

    if (_emailController.text.trim().isEmpty) {
      newErrors['email'] = 'Email is required';
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_emailController.text)) {
      newErrors['email'] = 'Email format is invalid';
    }

    if (_passwordController.text.isEmpty) {
      newErrors['password'] = 'Password is required';
    }

    setState(() {
      _errors = newErrors;
    });
  }

  void _handleSubmit() {
    _validateForm();
    if (_errors.isEmpty) {
      widget.onSignin(_emailController.text, _passwordController.text);
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),

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
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shield,
                              size: 40,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Safe Travel',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue.shade100,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Form Container
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
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),

                                // Email Field
                                _buildTextField(
                                  label: "Email",
                                  controller: _emailController,
                                  hint: "Enter your email",
                                  error: _errors['email'],
                                  onChanged: (_) => _clearError('email'),
                                ),

                                const SizedBox(height: 24),

                                // Password Field
                                _buildTextField(
                                  label: "Password",
                                  controller: _passwordController,
                                  hint: "Enter your password",
                                  error: _errors['password'],
                                  obscure: !_showPassword,
                                  onChanged: (_) => _clearError('password'),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Remember Me & Forgot Password
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                          activeColor: const Color(0xFF3B82F6),
                                        ),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Sign In Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Divider
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        'Or continue with',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Social Login Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: Colors.grey.shade300,
                                              width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.g_translate,
                                                color: Colors.red),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Google',
                                              style: TextStyle(
                                                  color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: Colors.grey.shade300,
                                              width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.facebook,
                                                color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Facebook',
                                              style: TextStyle(
                                                  color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Sign Up Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Don\'t have an account? ',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: widget.onNavigateToSignup,
                                      child: const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          color: Color(0xFF3B82F6),
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

  // Reusable text field builder
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? error,
    bool obscure = false,
    Function(String)? onChanged,
    Widget? suffixIcon,
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
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.grey.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.only(top: 4),
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
