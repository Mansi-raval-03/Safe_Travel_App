import 'package:flutter/material.dart';
import '../services/fake_call_service.dart';
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
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
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
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade800,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 30),
              
              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Caller number or label
              Text(
                widget.callerNumber ?? 'Mobile',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Ringing indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_in_talk,
                      size: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ringing...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Call action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
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
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(
              icon,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
