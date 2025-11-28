import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/fake_call_service.dart';
import '../services/emergency_siren_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'fake_call_screen.dart';

class SigninScreen extends StatefulWidget {
  final Function(String email, String password, bool rememberMe) onSignin;
  final Function() onNavigateToSignup;
  final bool isLoading;
  final String? errorMessage;

  const SigninScreen({
    Key? key,
    required this.onSignin,
    required this.onNavigateToSignup,
    this.isLoading = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  _SigninScreenState createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? false;
      if (remember) {
        final savedEmail = prefs.getString('saved_email') ?? '';
        final savedPassword = prefs.getString('saved_password') ?? '';
        setState(() {
          _rememberMe = true;
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    } catch (e) {
      // ignore errors - not critical
      print('Failed to load remembered credentials: $e');
    }
  }
  
  // Emergency services
  final FakeCallService _fakeCallService = FakeCallService();
  final EmergencySirenService _sirenService = EmergencySirenService();
  bool _isSirenActive = false;

  void _handleSubmit() {
    // Validate form before submitting
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      return;
    }
    
    // Call signin with validation and pass remember-me flag
    widget.onSignin(_emailController.text.trim(), _passwordController.text, _rememberMe);
  }

  /// Handle fake call button press
  void _handleFakeCall() {
    print('📱 Fake Call button pressed');
    
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
    print('🚨 Siren button pressed');
    
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.s(context, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Responsive.s(context, 40)),
              _buildHeader(),
              SizedBox(height: Responsive.s(context, 48)),
              _buildForm(),
              SizedBox(height: Responsive.s(context, 32)),
              if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: Responsive.s(context, 16)),
                  padding: EdgeInsets.all(Responsive.s(context, 12)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFFF6B6B),
                        size: 20,
                      ),
                      SizedBox(width: Responsive.s(context, 8)),
                      Expanded(
                        child: Text(
                          widget.errorMessage!,
                          style: TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: Responsive.s(context, 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildSignInButton(),
              SizedBox(height: Responsive.s(context, 24)),
              _buildEmergencyButtons(),
              SizedBox(height: Responsive.s(context, 32)),
              _buildSignUpLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: Responsive.s(context, 80),
          height: Responsive.s(context, 80),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(Responsive.s(context, 16)),
            child: Icon(
              Icons.security_outlined,
              color: Colors.white,
              size: Responsive.s(context, 40),
            ),
          ),
        ),
        SizedBox(height: Responsive.s(context, 24)),
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: Responsive.s(context, 32),
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: Responsive.s(context, 8)),
        Text(
          'Sign in to your account to continue',
          style: TextStyle(
            fontSize: Responsive.s(context, 16),
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(
            fontSize: Responsive.s(context, 16),
            color: Color(0xFF1F2937),
          ),
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email',
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFF6B7280),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        SizedBox(height: Responsive.s(context, 20)),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(
            fontSize: Responsive.s(context, 16),
            color: Color(0xFF1F2937),
          ),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF6B7280),
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF64748B),
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        SizedBox(height: Responsive.s(context, 20)),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _rememberMe = !_rememberMe;
                });
              },
              child: Row(
                children: [
                  Container(
                    width: Responsive.s(context, 20),
                    height: Responsive.s(context, 20),
                    decoration: BoxDecoration(
                      color: _rememberMe ? const Color(0xFF2563EB) : Colors.transparent,
                      border: Border.all(
                        color: _rememberMe ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _rememberMe
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  SizedBox(width: Responsive.s(context, 8)),
                  Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: Responsive.s(context, 14),
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                _showForgotPasswordDialog();
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: Responsive.s(context, 14),
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController _fpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: _fpController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your account email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = _fpController.text.trim();
                if (email.isEmpty) return;

                // Indicate processing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending reset code...')),
                );

                try {
                  final result = await AuthService.forgotPassword(email);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message)),
                  );

                  if (result.success) {
                    Navigator.of(context).pop();
                    // Show OTP + new password dialog
                    _showResetPasswordDialog(email);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request failed: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog(String email) {
    final TextEditingController _otpController = TextEditingController();
    final TextEditingController _newPassController = TextEditingController();
    final TextEditingController _confirmPassController = TextEditingController();
    bool _obscureNew = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Enter code & new password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('A 6-digit code was sent to $email'),
                SizedBox(height: Responsive.s(context, 12)),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OTP'),
                ),
                SizedBox(height: Responsive.s(context, 8)),
                TextField(
                  controller: _newPassController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() { _obscureNew = !_obscureNew; }),
                      icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.s(context, 8)),
                TextField(
                  controller: _confirmPassController,
                  obscureText: _obscureNew,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Resend code
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resending code...')));
                  try {
                    final r = await AuthService.forgotPassword(email);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
                  } catch (e) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resend failed: ${e.toString()}')));
                  }
                },
                child: const Text('Resend'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final otp = _otpController.text.trim();
                  final p1 = _newPassController.text;
                  final p2 = _confirmPassController.text;
                  if (otp.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a 6-digit code')));
                    return;
                  }
                  if (p1.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                    return;
                  }
                  if (p1 != p2) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }

                  // Call reset
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating password...')));
                  try {
                    final res = await AuthService.resetPassword(email, otp, p1);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                    if (res.success) Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString()}')));
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      }
    );
  }

  Widget _buildSignInButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: Responsive.s(context, 16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
          ),
          elevation: 0,
        ),
        child: widget.isLoading
            ? SizedBox(
                height: Responsive.s(context, 20),
                width: Responsive.s(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Sign In',
                style: TextStyle(
                  fontSize: Responsive.s(context, 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Build emergency feature buttons (Fake Call & Siren)
  Widget _buildEmergencyButtons() {
    return Column(
      children: [
        // Section divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 16)),
              child: Text(
                'Emergency Features',
                style: TextStyle(
                  fontSize: Responsive.s(context, 12),
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        SizedBox(height: Responsive.s(context, 20)),
        
        // Emergency buttons row
        Row(
          children: [
            // Fake Call button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleFakeCall,
                icon: Icon(Icons.phone_in_talk, size: Responsive.s(context, 20)),
                label: Text(
                  'Fake Call',
                  style: TextStyle(fontSize: Responsive.s(context, 14), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: Responsive.s(context, 14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: Responsive.s(context, 12)),
            
            // Emergency Siren button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleSirenToggle,
                icon: Icon(
                  _isSirenActive ? Icons.volume_off : Icons.emergency,
                  size: Responsive.s(context, 20),
                ),
                label: Text(
                  _isSirenActive ? 'Stop Siren' : 'Siren',
                  style: TextStyle(fontSize: Responsive.s(context, 14), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isSirenActive ? Colors.grey.shade600 : const Color(0xFFEF4444),
                  side: BorderSide(
                    color: _isSirenActive ? Colors.grey.shade400 : const Color(0xFFEF4444),
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(vertical: Responsive.s(context, 14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Responsive.s(context, 12)),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Info text
        SizedBox(height: Responsive.s(context, 12)),
        Text(
          'Emergency tools available without login',
          style: TextStyle(
            fontSize: Responsive.s(context, 11),
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            fontSize: Responsive.s(context, 14),
            color: Color(0xFF6B7280),
          ),
        ),
        GestureDetector(
          onTap: widget.onNavigateToSignup,
          child: Text(
            'Sign up',
            style: TextStyle(
              fontSize: Responsive.s(context, 14),
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}