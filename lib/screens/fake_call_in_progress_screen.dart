import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fake_call_service.dart';

/// In-progress fake call screen
/// Displays call timer and end call button
class FakeCallInProgressScreen extends StatefulWidget {
  final String callerName;
  
  const FakeCallInProgressScreen({
    Key? key,
    required this.callerName,
  }) : super(key: key);

  @override
  State<FakeCallInProgressScreen> createState() => _FakeCallInProgressScreenState();
}

class _FakeCallInProgressScreenState extends State<FakeCallInProgressScreen> {
  final FakeCallService _fakeCallService = FakeCallService();
  
  // Call timer
  late Timer _timer;
  int _elapsedSeconds = 0;
  
  // Recording state
  bool _isRecording = false;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Start call duration timer
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  /// Format elapsed time as MM:SS
  String _formatDuration() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Handle end call button press
  void _handleEndCall() async {
    await _fakeCallService.endCall();
    
    if (mounted) {
      // Return to previous screen (should be signin)
      Navigator.of(context).pop();
    }
  }

  /// Toggle recording state
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isRecording ? '🔴 Recording started' : '⏹️ Recording stopped',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: _isRecording ? Colors.red : Colors.grey,
      ),
    );
    
    print(_isRecording ? '🔴 Recording started' : '⏹️ Recording stopped');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button dismiss during call
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
                  'Safe Travel Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Caller avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade800,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Call duration timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Call status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Call controls grid (optional features)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 30,
                  crossAxisSpacing: 30,
                  children: [
                    _buildControlButton(
                      icon: Icons.mic_off,
                      label: 'Mute',
                      isEnabled: false,
                    ),
                    _buildControlButton(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      isEnabled: false,
                    ),
                    _buildControlButton(
                      icon: Icons.volume_up,
                      label: 'Speaker',
                      isEnabled: false,
                    ),
                    // New row with recording button
                    _buildRecordButton(),
                    _buildControlButton(
                      icon: Icons.add,
                      label: 'Add Call',
                      isEnabled: false,
                    ),
                    _buildControlButton(
                      icon: Icons.video_call,
                      label: 'Video',
                      isEnabled: false,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // End call button
              GestureDetector(
                onTap: _handleEndCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                'End Call',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Build call control button
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isEnabled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade800.withOpacity(0.5),
          ),
          child: Icon(
            icon,
            size: 24,
            color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build recording button with toggle functionality
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording 
                  ? Colors.red.withOpacity(0.8) 
                  : Colors.grey.shade800.withOpacity(0.5),
            ),
            child: Icon(
              _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
              size: 24,
              color: _isRecording ? Colors.white : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? 'Stop Rec' : 'Record',
            style: TextStyle(
              color: _isRecording ? Colors.red : Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
