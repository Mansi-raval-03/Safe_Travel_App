import 'package:flutter/material.dart';
import '../services/fake_call_service.dart';
import '../utils/responsive.dart';
import 'fake_call_in_progress_screen.dart';

/// Full-screen fake incoming call UI
/// Displays caller information and call control buttons
class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerNumber;
  
  const FakeCallScreen({
    Key? key,
    this.callerName = 'Mom',
    this.callerNumber,
  }) : super(key: key);

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> with SingleTickerProviderStateMixin {
  final FakeCallService _fakeCallService = FakeCallService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for avatar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Handle accept button press
  void _handleAccept() async {
    await _fakeCallService.acceptCall();
    
    if (mounted) {
      // Navigate to in-call screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FakeCallInProgressScreen(
            callerName: widget.callerName,
          ),
        ),
      );
    }
  }

  /// Handle decline button press
  void _handleDecline() async {
    await _fakeCallService.declineCall();
    
    if (mounted) {
      // Close the fake call screen
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button dismiss
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(20.0 * Responsive.scale(context)),
                child: Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: Responsive.s(context, 16),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Caller avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: Responsive.s(context, 120),
                      height: Responsive.s(context, 120),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade800,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3 * Responsive.scale(context),
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: Responsive.s(context, 60),
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: Responsive.s(context, 30)),
              
              // Caller name
              Text(
                widget.callerName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.s(context, 32),
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: Responsive.s(context, 10)),
              
              // Caller number or label
              Text(
                widget.callerNumber ?? 'Mobile',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: Responsive.s(context, 18),
                ),
              ),
              
              SizedBox(height: Responsive.s(context, 20)),
              
              // Ringing indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16 * Responsive.scale(context), vertical: 8 * Responsive.scale(context)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_in_talk,
                      size: Responsive.s(context, 16),
                      color: Colors.white.withOpacity(0.7),
                    ),
                    SizedBox(width: Responsive.s(context, 8)),
                    Text(
                      'Ringing...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: Responsive.s(context, 14),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Call action buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.s(context, 40), vertical: Responsive.s(context, 40)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline button (Red)
                    _buildCallButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      label: 'Decline',
                      onPressed: _handleDecline,
                    ),
                    
                    // Accept button (Green)
                    _buildCallButton(
                      icon: Icons.call,
                      color: Colors.green,
                      label: 'Accept',
                      onPressed: _handleAccept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build call control button
  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: Responsive.s(context, 70),
            height: Responsive.s(context, 70),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(
              icon,
              size: Responsive.s(context, 32),
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: Responsive.s(context, 10)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.s(context, 14),
          ),
        ),
      ],
    );
  }
}
