import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class NetworkDiagnosticsWidget extends StatefulWidget {
  const NetworkDiagnosticsWidget({Key? key}) : super(key: key);

  @override
  _NetworkDiagnosticsWidgetState createState() => _NetworkDiagnosticsWidgetState();
}

class _NetworkDiagnosticsWidgetState extends State<NetworkDiagnosticsWidget> {
  String _connectionStatus = 'Testing...';
  bool _isLoading = true;
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing connection...';
      _statusColor = Colors.orange;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.currentBaseUrl.replaceAll('/api/v1', '')}/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = ' Backend server is running properly';
          _statusColor = Colors.green;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _connectionStatus = ' Backend server is accessible\n(API endpoints are working)';
          _statusColor = Colors.green;
        });
      } else {
        setState(() {
          _connectionStatus = ' Server responded with status ${response.statusCode}\n(Check server configuration)';
          _statusColor = Colors.orange;
        });
      }
    } on SocketException {
      setState(() {
        _connectionStatus = ' Cannot connect to backend server.\nCheck internet connection or server status.';
        _statusColor = Colors.red;
      });
    } on TimeoutException {
      setState(() {
        _connectionStatus = ' Connection timeout (5s).\nServer might be slow or unreachable.';
        _statusColor = Colors.orange;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = ' Network error: ${e.toString()}';
        _statusColor = Colors.red;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        border: Border.all(color: _statusColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check,
                color: _statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Network Diagnostics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _statusColor,
                  ),
                )
              else
                IconButton(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.refresh, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _connectionStatus,
              style: TextStyle(
                fontSize: 14,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Backend URL: ${ApiConfig.currentBaseUrl}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
