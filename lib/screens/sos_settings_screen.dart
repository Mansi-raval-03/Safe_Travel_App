import 'dart:async';
import 'package:flutter/material.dart';
import '../services/enhanced_sos_service.dart';

class SOSSettingsScreen extends StatefulWidget {
  @override
  _SOSSettingsScreenState createState() => _SOSSettingsScreenState();
}

class _SOSSettingsScreenState extends State<SOSSettingsScreen> {
  final EnhancedSOSService _sosService = EnhancedSOSService.instance;
  int _timerDuration = 2;
  bool _autoSendEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    await _sosService.initialize();
    
    setState(() {
      _timerDuration = _sosService.timerDuration;
      _autoSendEnabled = _sosService.autoSendEnabled;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    _sosService.setTimerDuration(_timerDuration);
    _sosService.setAutoSendEnabled(_autoSendEnabled);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ SOS settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SOS Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 30),
                              SizedBox(width: 12),
                              Text(
                                'Emergency SOS Settings',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Configure how your emergency alerts are sent',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Auto-Send Toggle
                  Card(
                    child: SwitchListTile(
                      title: Text(
                        'Auto-Send with Timer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _autoSendEnabled
                            ? 'Emergency alerts will be sent automatically after timer countdown'
                            : 'Emergency alerts require manual confirmation',
                      ),
                      value: _autoSendEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _autoSendEnabled = value;
                        });
                      },
                      activeColor: Colors.red,
                      secondary: Icon(
                        _autoSendEnabled ? Icons.timer : Icons.touch_app,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Timer Duration Setting
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timer Duration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Time before automatic sending (${_timerDuration} seconds)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          Slider(
                            value: _timerDuration.toDouble(),
                            min: 1.0,
                            max: 60.0,
                            divisions: 59,
                            label: '${_timerDuration}s',
                            onChanged: _autoSendEnabled ? (double value) {
                              setState(() {
                                _timerDuration = value.round();
                              });
                            } : null,
                            activeColor: Colors.red,
                            inactiveColor: Colors.grey,
                          ),
                          
                          // Quick preset buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPresetButton('1s', 1),
                              _buildPresetButton('2s', 2),
                              _buildPresetButton('5s', 5),
                              _buildPresetButton('15s', 15),
                              _buildPresetButton('60s', 60),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Information Section
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'How SOS Works',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoItem('📱', 'SMS messages sent to all emergency contacts'),
                          _buildInfoItem('💬', 'WhatsApp messages with location link'),
                          _buildInfoItem('📍', 'Your exact GPS coordinates included'),
                          _buildInfoItem('⏱️', 'Configurable countdown timer'),
                          _buildInfoItem('❌', 'Cancel anytime during countdown'),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Test Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showTestDialog();
                      },
                      icon: Icon(Icons.play_arrow),
                      label: Text('Test Timer (Preview Only)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: Icon(Icons.save),
                      label: Text('Save Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPresetButton(String label, int seconds) {
    bool isSelected = _timerDuration == seconds;
    return GestureDetector(
      onTap: _autoSendEnabled ? () {
        setState(() {
          _timerDuration = seconds;
        });
      } : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestDialog() {
    if (!_autoSendEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enable auto-send to test timer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            int remainingSeconds = _timerDuration;
            bool isCancelled = false;

            // Create a local timer for testing
            Timer.periodic(Duration(seconds: 1), (timer) {
              if (isCancelled) {
                timer.cancel();
                return;
              }
              
              remainingSeconds--;
              if (mounted && !isCancelled) {
                setState(() {});
              }

              if (remainingSeconds <= 0) {
                timer.cancel();
                if (!isCancelled && mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🚨 Timer test completed! (No messages sent)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            });

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange, size: 30),
                  SizedBox(width: 10),
                  Text('Testing Timer'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: remainingSeconds / _timerDuration,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    strokeWidth: 8,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Test countdown: $remainingSeconds seconds',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This is a preview only - no messages will be sent',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    isCancelled = true;
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: Text('Cancel Test'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}