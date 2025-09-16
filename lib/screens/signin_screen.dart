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
  _SigninScreenState createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
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
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                      SizedBox(height: 48),
                      
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
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Safe Travel',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sign in to your account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue.shade100,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 32),
                      
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
                                  SizedBox(height: 24),
                                  
                                  // Email Field
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _emailController,
                                        onChanged: (_) => _clearError('email'),
                                        decoration: InputDecoration(
                                          hintText: 'Enter your email',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: _errors.containsKey('email') ? Colors.red : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Color(0xFF3B82F6),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_errors.containsKey('email'))
                                        Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            _errors['email']!,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Password Field
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Password',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _passwordController,
                                        onChanged: (_) => _clearError('password'),
                                        obscureText: !_showPassword,
                                        decoration: InputDecoration(
                                          hintText: 'Enter your password',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: _errors.containsKey('password') ? Colors.red : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Color(0xFF3B82F6),
                                              width: 2,
                                            ),
                                          ),
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
                                      ),
                                      if (_errors.containsKey('password'))
                                        Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            _errors['password']!,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 16),
                                  
                                  // Remember Me & Forgot Password
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                            activeColor: Color(0xFF3B82F6),
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
                                        child: Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Sign In Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF3B82F6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(height: 32),
                                  
                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'Or continue with',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Social Login Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {},
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.g_mobiledata, color: Colors.grey.shade700),
                                              SizedBox(width: 8),
                                              Text(
                                                'Google',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {},
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.facebook, color: Colors.grey.shade700),
                                              SizedBox(width: 8),
                                              Text(
                                                'Facebook',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  Spacer(),
                                  
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
                                        child: Text(
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