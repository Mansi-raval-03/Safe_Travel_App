import 'package:flutter/material.dart';
import '../services/location_sharing_service.dart';

/// Widget for displaying location sharing status with timer
class LocationSharingStatusWidget extends StatelessWidget {
  final bool isActive;
  final Duration? remainingTime;
  final VoidCallback? onStop;
  final VoidCallback? onShare;

  const LocationSharingStatusWidget({
    Key? key,
    required this.isActive,
    this.remainingTime,
    this.onStop,
    this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location sharing active',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              if (remainingTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${remainingTime!.inMinutes}:${(remainingTime!.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your location is being shared in real-time. Others can track your movements.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget for location sharing timer display
class LocationSharingTimerWidget extends StatelessWidget {
  final Duration? remainingTime;
  final bool isActive;

  const LocationSharingTimerWidget({
    Key? key,
    this.remainingTime,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isActive || remainingTime == null) {
      return const SizedBox.shrink();
    }

    final minutes = remainingTime!.inMinutes;
    final seconds = remainingTime!.inSeconds % 60;
    final isLowTime = remainingTime!.inMinutes < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLowTime ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowTime ? Colors.orange.shade300 : Colors.green.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 12,
            color: isLowTime ? Colors.orange.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isLowTime ? Colors.orange.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for selecting location sharing duration
class LocationSharingDurationDialog extends StatelessWidget {
  final Function(Duration) onDurationSelected;

  const LocationSharingDurationDialog({
    Key? key,
    required this.onDurationSelected,
  }) : super(key: key);

  static final List<Map<String, dynamic>> _durations = [
    {
      'duration': const Duration(minutes: 15),
      'label': '15 minutes',
      'description': 'Quick sharing session',
      'icon': Icons.access_time,
    },
    {
      'duration': const Duration(minutes: 30),
      'label': '30 minutes',
      'description': 'Medium duration sharing',
      'icon': Icons.schedule,
    },
    {
      'duration': const Duration(hours: 1),
      'label': '1 hour',
      'description': 'Long sharing session',
      'icon': Icons.timelapse,
    },
    {
      'duration': const Duration(hours: 2),
      'label': '2 hours',
      'description': 'Extended sharing session',
      'icon': Icons.more_time,
    },
    {
      'duration': const Duration(hours: 4),
      'label': '4 hours',
      'description': 'All-day sharing',
      'icon': Icons.all_inclusive,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share_location, color: Colors.blue),
          SizedBox(width: 8),
          Text('Share Live Location'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select how long you want to share your location:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ..._durations.map((duration) => 
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onDurationSelected(duration['duration'] as Duration);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      duration['icon'] as IconData,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duration['label'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            duration['description'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Privacy level selector widget
class PrivacyLevelSelector extends StatelessWidget {
  final SharingPrivacyLevel currentLevel;
  final Function(SharingPrivacyLevel) onLevelChanged;

  const PrivacyLevelSelector({
    Key? key,
    required this.currentLevel,
    required this.onLevelChanged,
  }) : super(key: key);

  static final Map<SharingPrivacyLevel, Map<String, dynamic>> _privacyLevels = {
    SharingPrivacyLevel.public: {
      'label': 'Public',
      'description': 'Share with anyone who has the link',
      'icon': Icons.public,
      'color': Colors.orange,
    },
    SharingPrivacyLevel.friends: {
      'label': 'Friends',
      'description': 'Share with friends and contacts',
      'icon': Icons.people,
      'color': Colors.blue,
    },
    SharingPrivacyLevel.family: {
      'label': 'Family',
      'description': 'Share with family members only',
      'icon': Icons.family_restroom,
      'color': Colors.green,
    },
    SharingPrivacyLevel.emergency: {
      'label': 'Emergency',
      'description': 'Maximum detail for emergency situations',
      'icon': Icons.emergency,
      'color': Colors.red,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ..._privacyLevels.entries.map((entry) {
          final level = entry.key;
          final info = entry.value;
          final isSelected = level == currentLevel;

          return GestureDetector(
            onTap: () => onLevelChanged(level),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? (info['color'] as Color).withOpacity(0.1) : Colors.white,
                border: Border.all(
                  color: isSelected ? (info['color'] as Color) : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    info['icon'] as IconData,
                    size: 20,
                    color: info['color'] as Color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? (info['color'] as Color) : Colors.black,
                          ),
                        ),
                        Text(
                          info['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: info['color'] as Color,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Quick action buttons for location sharing
class LocationSharingQuickActions extends StatelessWidget {
  final bool isLocationAvailable;
  final VoidCallback? onQuickShare15Min;
  final VoidCallback? onQuickShare1Hour;
  final VoidCallback? onCustomDuration;

  const LocationSharingQuickActions({
    Key? key,
    required this.isLocationAvailable,
    this.onQuickShare15Min,
    this.onQuickShare1Hour,
    this.onCustomDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLocationAvailable ? onQuickShare15Min : null,
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('15 min'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLocationAvailable ? onQuickShare1Hour : null,
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('1 hour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLocationAvailable ? onCustomDuration : null,
                icon: const Icon(Icons.more_time, size: 16),
                label: const Text('Custom'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue.shade300),
                  disabledForegroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        if (!isLocationAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Location must be enabled to share',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Location accuracy indicator widget
class LocationAccuracyIndicator extends StatelessWidget {
  final double? accuracy;
  final bool isLocationAvailable;

  const LocationAccuracyIndicator({
    Key? key,
    this.accuracy,
    required this.isLocationAvailable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLocationAvailable || accuracy == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text(
              'No location',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    Color color;
    String description;
    IconData icon;

    if (accuracy! <= 5) {
      color = Colors.green;
      description = 'Excellent';
      icon = Icons.gps_fixed;
    } else if (accuracy! <= 10) {
      color = Colors.blue;
      description = 'Good';
      icon = Icons.gps_fixed;
    } else if (accuracy! <= 50) {
      color = Colors.orange;
      description = 'Fair';
      icon = Icons.gps_not_fixed;
    } else {
      color = Colors.red;
      description = 'Poor';
      icon = Icons.gps_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$description (${accuracy!.toStringAsFixed(0)}m)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}