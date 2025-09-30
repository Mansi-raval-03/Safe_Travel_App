import 'package:flutter/material.dart';
import '../services/location_sharing_service.dart';
import '../services/native_location_sharing_service.dart';

/// Widget to display native location sharing options
class NativeLocationSharingSheet extends StatefulWidget {
  final LocationSharingService sharingService;
  final String? customMessage;

  const NativeLocationSharingSheet({
    Key? key,
    required this.sharingService,
    this.customMessage,
  }) : super(key: key);

  @override
  State<NativeLocationSharingSheet> createState() => _NativeLocationSharingSheetState();
}

class _NativeLocationSharingSheetState extends State<NativeLocationSharingSheet> {
  List<SharingOption> _sharingOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharingOptions();
  }

  Future<void> _loadSharingOptions() async {
    try {
      final options = await widget.sharingService.getAvailableSharingOptions();
      setState(() {
        _sharingOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading sharing options: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Text(
            'Share Live Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Choose how you want to share your location',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Loading or sharing options
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_sharingOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No sharing apps available',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sharingOptions.length,
                itemBuilder: (context, index) {
                  final option = _sharingOptions[index];
                  return _buildSharingOptionTile(option);
                },
              ),
            ),
          
          // Fallback option
          if (!_isLoading && _sharingOptions.isNotEmpty) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('More sharing options'),
              subtitle: const Text('Use system sharing dialog'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await widget.sharingService.shareLocationWithPlatform(
                    customMessage: widget.customMessage,
                  );
                } catch (e) {
                  _showErrorSnackBar('Error sharing location: $e');
                }
              },
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSharingOptionTile(SharingOption option) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: option.isNativeLocation ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          option.icon,
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Row(
        children: [
          Text(option.name),
          if (option.isNativeLocation) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(option.description),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: () => _shareViaApp(option),
    );
  }

  Future<void> _shareViaApp(SharingOption option) async {
    Navigator.pop(context);
    
    try {
      final success = await widget.sharingService.shareLocationViaApp(
        option.id,
        customMessage: widget.customMessage,
      );
      
      if (success) {
        _showSuccessSnackBar(
          option.isNativeLocation 
              ? 'Live location shared via ${option.name}!'
              : 'Location shared via ${option.name}!'
        );
      } else {
        _showErrorSnackBar('Failed to share via ${option.name}. App may not be installed.');
      }
    } catch (e) {
      _showErrorSnackBar('Error sharing via ${option.name}: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Helper function to show the native sharing sheet
Future<void> showNativeLocationSharingSheet({
  required BuildContext context,
  required LocationSharingService sharingService,
  String? customMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return NativeLocationSharingSheet(
        sharingService: sharingService,
        customMessage: customMessage,
      );
    },
  );
}