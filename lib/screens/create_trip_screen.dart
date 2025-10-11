import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip_event.dart';
import '../services/location_service.dart';
import '../services/trip_event_service.dart';
import '../widgets/bottom_navigation.dart';

class CreateTripScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback? onTripCreated;

  const CreateTripScreen({
    Key? key,
    required this.onNavigate,
    this.onTripCreated,
  }) : super(key: key);

  @override
  _CreateTripScreenState createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _destinationAddressController = TextEditingController();
  final _destinationNameController = TextEditingController();
  
  // Form values
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  TravelMode _selectedTravelMode = TravelMode.other;
  TripLocation? _selectedDestination;
  Position? _currentPosition;
  
  // Alert threshold settings
  int _locationTimeoutMinutes = 30;
  int _destinationToleranceMeters = 500;
  
  // UI state
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isLocationPickerVisible = false;
  String? _errorMessage;
  
  // Map controller for location selection
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _destinationAddressController.dispose();
    _destinationNameController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final year = dateTime.year;
    
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$month $day, $year\n$hour:$minute $period';
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);
      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to get current location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isStartTime 
        ? (now.add(Duration(hours: 1)))  // Default to 1 hour from now
        : (_startDateTime?.add(Duration(hours: 2)) ?? now.add(Duration(hours: 3)));
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
      helpText: isStartTime ? 'Select Start Date' : 'Select End Date',
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: isStartTime ? 'Select Start Time' : 'Select End Time',
      );
      
      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        
        setState(() {
          if (isStartTime) {
            _startDateTime = selectedDateTime;
            // Auto-adjust end time if it's before start time
            if (_endDateTime != null && _endDateTime!.isBefore(selectedDateTime)) {
              _endDateTime = selectedDateTime.add(Duration(hours: 2));
            }
          } else {
            // Validate end time is after start time
            if (_startDateTime != null && selectedDateTime.isBefore(_startDateTime!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('End time must be after start time')),
              );
              return;
            }
            _endDateTime = selectedDateTime;
          }
        });
      }
    }
  }

  void _showLocationPicker() {
    setState(() => _isLocationPickerVisible = true);
  }

  void _hideLocationPicker() {
    setState(() => _isLocationPickerVisible = false);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Set initial camera position to current location if available
    if (_currentPosition != null) {
      controller.animateCamera(CameraUpdate.newLatLng(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      ));
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _markers = {
        Marker(
          markerId: MarkerId('selected_location'),
          position: position,
          infoWindow: InfoWindow(
            title: 'Selected Destination',
            snippet: 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _confirmLocationSelection() {
    if (_selectedLocation != null) {
      setState(() {
        _selectedDestination = TripLocation(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _destinationAddressController.text.trim(),
          name: _destinationNameController.text.trim(),
        );
        _isLocationPickerVisible = false;
      });
    }
  }

  void _useCurrentLocationAsDestination() async {
    if (_currentPosition != null) {
      setState(() {
        _selectedDestination = TripLocation(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          address: 'Current Location',
          name: 'My Current Location',
        );
        _destinationAddressController.text = 'Current Location';
        _destinationNameController.text = 'My Current Location';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Current location not available')),
      );
    }
  }

  Future<void> _saveTripEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDateTime == null || _endDateTime == null) {
      setState(() => _errorMessage = 'Please select both start and end times');
      return;
    }

    if (_selectedDestination == null) {
      setState(() => _errorMessage = 'Please select a destination');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Create the trip event using builder pattern
      // TODO: Get actual user ID from auth service
      const userId = 'temp_user_id'; // This should come from authenticated user
      
      final tripEvent = TripEventBuilder()
          .setTitle(_titleController.text.trim())
          .setStartTime(_startDateTime!)
          .setEndTime(_endDateTime!)
          .setDestination(_selectedDestination!)
          .setNotes(_notesController.text.trim())
          .setTravelMode(_selectedTravelMode)
          .build(userId);

      // Save to API and local storage via TripEventService
      final result = await TripEventService.createTripEvent(tripEvent);
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            action: result.isOfflineCache ? SnackBarAction(
              label: 'Offline',
              textColor: Colors.white,
              onPressed: () {},
            ) : null,
          ),
        );

        // Clear form
        _titleController.clear();
        _notesController.clear();
        _destinationAddressController.clear();
        _destinationNameController.clear();
        setState(() {
          _startDateTime = null;
          _endDateTime = null;
          _selectedDestination = null;
          _selectedLocation = null;
          _markers.clear();
          _selectedTravelMode = TravelMode.other;
          _errorMessage = null;
        });

        // Notify parent if callback provided
        if (widget.onTripCreated != null) {
          widget.onTripCreated!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.isOfflineCache ? Colors.orange : Colors.red,
          ),
        );
        
        if (!result.isOfflineCache) {
          setState(() => _errorMessage = result.message);
        }
      }
      
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create trip: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Trip Event'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLocationPickerVisible ? _buildLocationPicker() : _buildMainForm(),
      bottomNavigationBar: _isLocationPickerVisible 
          ? null 
          : BottomNavigation(
              currentIndex: 2, // Assuming this is a new screen
              onNavigate: widget.onNavigate,
            ),
    );
  }

  Widget _buildMainForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),

            // Trip Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Trip Title',
                hintText: 'e.g., Meeting with John, Visit to Mall',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a trip title';
                }
                if (value.trim().length > 200) {
                  return 'Title must be less than 200 characters';
                }
                return null;
              },
              maxLength: 200,
            ),
            SizedBox(height: 16),

            // DateTime Selection Row
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeCard(
                    'Start Time',
                    _startDateTime,
                    () => _selectDateTime(context, true),
                    Icons.play_arrow,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeCard(
                    'End Time',
                    _endDateTime,
                    () => _selectDateTime(context, false),
                    Icons.stop,
                    Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Travel Mode Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travel Mode',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: TravelMode.values.map((mode) {
                        return ChoiceChip(
                          label: Text(_getTravelModeLabel(mode)),
                          selected: _selectedTravelMode == mode,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTravelMode = mode);
                            }
                          },
                          avatar: Icon(_getTravelModeIcon(mode), size: 18),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Destination Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    if (_selectedDestination != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedDestination!.name?.isNotEmpty ?? false)
                              Text(
                                _selectedDestination!.name!,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            if (_selectedDestination!.address?.isNotEmpty ?? false)
                              Text(_selectedDestination!.address!),
                            Text(
                              'Lat: ${_selectedDestination!.latitude.toStringAsFixed(6)}, '
                              'Lng: ${_selectedDestination!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showLocationPicker,
                            icon: Icon(Icons.map),
                            label: Text('Select on Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingLocation ? null : _useCurrentLocationAsDestination,
                            icon: _isLoadingLocation 
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.my_location),
                            label: Text('Use Current'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Alert Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      leading: Icon(Icons.timer),
                      title: Text('Location Timeout'),
                      subtitle: Text('${_locationTimeoutMinutes} minutes'),
                      trailing: PopupMenuButton<int>(
                        onSelected: (value) {
                          setState(() => _locationTimeoutMinutes = value);
                        },
                        itemBuilder: (context) => [5, 15, 30, 60, 120]
                            .map((minutes) => PopupMenuItem(
                                  value: minutes,
                                  child: Text('$minutes minutes'),
                                ))
                            .toList(),
                        child: Icon(Icons.arrow_drop_down),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.place),
                      title: Text('Destination Tolerance'),
                      subtitle: Text('${_destinationToleranceMeters} meters'),
                      trailing: PopupMenuButton<int>(
                        onSelected: (value) {
                          setState(() => _destinationToleranceMeters = value);
                        },
                        itemBuilder: (context) => [100, 250, 500, 1000, 2000]
                            .map((meters) => PopupMenuItem(
                                  value: meters,
                                  child: Text('$meters meters'),
                                ))
                            .toList(),
                        child: Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Additional details about your trip...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              maxLength: 1000,
              validator: (value) {
                if (value != null && value.length > 1000) {
                  return 'Notes must be less than 1000 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTripEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating Trip...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle),
                        SizedBox(width: 8),
                        Text('Create Trip Event'),
                      ],
                    ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard(String label, DateTime? dateTime, VoidCallback onTap, IconData icon, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              dateTime != null
                  ? _formatDateTime(dateTime)
                  : 'Tap to select',
              style: TextStyle(
                color: dateTime != null ? Colors.black87 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Destination'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _hideLocationPicker,
        ),
        actions: [
          TextButton(
            onPressed: _selectedLocation != null ? _confirmLocationSelection : null,
            child: Text(
              'CONFIRM',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Location input fields
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _destinationNameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name',
                    hintText: 'e.g., Home, Office, Shopping Mall',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _destinationAddressController,
                  decoration: InputDecoration(
                    labelText: 'Address (Optional)',
                    hintText: 'Enter full address if known',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : LatLng(37.7749, -122.4194), // Default to San Francisco
                zoom: 15,
              ),
              onTap: _onMapTapped,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          
          // Instruction text
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on the map to select your destination. The red marker will show your selected location.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTravelModeLabel(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.publicTransport:
        return 'Transit';
      case TravelMode.cycling:
        return 'Cycling';
      case TravelMode.other:
        return 'Other';
    }
  }

  IconData _getTravelModeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.driving:
        return Icons.directions_car;
      case TravelMode.publicTransport:
        return Icons.directions_bus;
      case TravelMode.cycling:
        return Icons.directions_bike;
      case TravelMode.other:
        return Icons.help_outline;
    }
  }
}