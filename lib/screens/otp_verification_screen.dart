import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/otp_service.dart';
import '../services/verification_storage_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String? userName;
  final Function(bool)? onVerificationComplete;

  const OTPVerificationScreen({
    Key? key,
    required this.email,
    this.userName,
    this.onVerificationComplete,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final OTPService _otpService = OTPService();
  final VerificationStorageService _storageService = VerificationStorageService.instance;
  
  // Controllers for each OTP digit
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  
  // State variables
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';
  String _successMessage = '';
  
  // Timer for countdown
  Timer? _countdownTimer;
  int _resendCountdown = 0;
  
  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _startResendCountdown(60); // Initial 60 second countdown
    _checkExistingVerification();
  }

  @override
  void dispose() {
    _disposeControllers();
    _countdownTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Initialize OTP input controllers and focus nodes
  void _initializeControllers() {
    _controllers = List.generate(6, (index) => TextEditingController());
    _focusNodes = List.generate(6, (index) => FocusNode());
  }

  /// Initialize animations
  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  /// Dispose controllers and focus nodes
  void _disposeControllers() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
  }

  /// Check if email is already verified
  Future<void> _checkExistingVerification() async {
    try {
      final isVerified = await _storageService.isEmailVerified(widget.email);
      if (isVerified && mounted) {
        _showSuccessMessage('Email already verified!');
        widget.onVerificationComplete?.call(true);
      }
    } catch (e) {
      // Continue with normal flow if check fails
    }
  }

  /// Start countdown timer for resend button
  void _startResendCountdown(int seconds) {
    setState(() {
      _resendCountdown = seconds;
    });
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Get current OTP string
  String _getCurrentOTP() {
    return _controllers.map((controller) => controller.text).join();
  }

  /// Clear all OTP inputs
  void _clearOTP() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  /// Show shake animation for incorrect OTP
  void _shakeInputs() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  /// Handle OTP input change
  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Move to next field if not the last one
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered, try to verify
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    }
  }

  /// Verify OTP with backend
  Future<void> _verifyOTP() async {
    final otp = _getCurrentOTP();
    
    if (otp.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final result = await _otpService.verifyOTP(widget.email, otp);
      
      if (result.success) {
        await _storageService.saveVerifiedEmail(widget.email, {
          'verifiedAt': DateTime.now().toIso8601String(),
          'userName': widget.userName,
        });
        
        _showSuccessMessage('Email verified successfully! 🎉');
        
        // Delay navigation to show success message
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            widget.onVerificationComplete?.call(true);
          }
        });
        
      } else {
        _showError(result.message);
        _shakeInputs();
        _clearOTP();
      }
      
    } catch (e) {
      _showError('Verification failed. Please try again.');
      _shakeInputs();
      _clearOTP();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Resend OTP
  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final result = await _otpService.resendOTP(widget.email);
      
      if (result.success) {
        _showSuccessMessage('New OTP sent to your email! 📧');
        _startResendCountdown(60);
        _clearOTP();
      } else {
        _showError(result.message);
      }
      
    } catch (e) {
      _showError('Failed to resend OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  /// Show error message
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = '';
    });
    
    // Auto-clear error after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _errorMessage = '';
        });
      }
    });
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Header illustration
              _buildHeaderIllustration(),
              
              const SizedBox(height: 32),
              
              // Title and description
              _buildTitleSection(),
              
              const SizedBox(height: 40),
              
              // OTP Input fields
              _buildOTPInputs(),
              
              const SizedBox(height: 30),
              
              // Error/Success messages
              _buildMessageSection(),
              
              const SizedBox(height: 30),
              
              // Verify button
              _buildVerifyButton(),
              
              const SizedBox(height: 24),
              
              // Resend section
              _buildResendSection(),
              
              const SizedBox(height: 40),
              
              // Help section
              _buildHelpSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIllustration() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read,
              color: Colors.white,
              size: 50,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a verification code to',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            widget.email,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPInputs() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 45,
                height: 55,
                child: TextFormField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => _onOTPChanged(index, value),
                  onTap: () {
                    if (_controllers[index].text.isNotEmpty) {
                      _controllers[index].selection = TextSelection.fromPosition(
                        TextPosition(offset: _controllers[index].text.length),
                      );
                    }
                  },
                  onFieldSubmitted: (_) {
                    if (index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildMessageSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _errorMessage.isNotEmpty || _successMessage.isNotEmpty ? 60 : 0,
      child: Column(
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_successMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 2,
          shadowColor: Colors.blue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Verify Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          'Didn\'t receive the code?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resendCountdown > 0 || _isResending ? null : _resendOTP,
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade600,
            disabledForegroundColor: Colors.grey.shade400,
          ),
          child: _isResending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _resendCountdown > 0
                      ? 'Resend in ${_resendCountdown}s'
                      : 'Resend Code',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Need help?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Check your spam/junk folder\n'
            '• Make sure ${widget.email} is correct\n'
            '• Code expires in 5 minutes\n'
            '• Contact support if problems persist',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Add support contact functionality
            },
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Contact Support'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}