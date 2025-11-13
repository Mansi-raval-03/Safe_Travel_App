import 'package:flutter/material.dart';
import '../models/trip_event.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/trip_service.dart';

class TripsScreen extends StatefulWidget {
  final String userId;
  const TripsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  // Simple static suggestions; will be augmented from history later
  final List<String> _staticSuggestions = ['Work', 'Home', 'Airport', 'Meeting', 'Hospital', 'School'];
  List<String> _filteredSuggestions = [];
  DateTime? _start;
  DateTime? _end;
  double _destLat = 0.0;
  double _destLong = 0.0;
  List<TripEvent> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadLocalTrips();
    // Attempt sync in background
    TripService.syncLocalTrips(widget.userId);
    _fetchFromServer();
  }

  Future<void> _loadLocalTrips() async {
    final local = await TripService.getLocalTrips();
    setState(() => _trips = List<TripEvent>.from(local));
    // Build suggestions from local history titles
    final titles = _trips.map((t) => t.title).toList();
    _filteredSuggestions = ([..._staticSuggestions, ...titles]).toSet().toList();
  }

  Future<void> _fetchFromServer() async {
    final server = await TripService.fetchUserTrips(widget.userId);
    // Merge server-provided trips with local cache, avoiding duplicates by id
    final merged = <String, TripEvent>{};
    for (final t in _trips) merged[t.id] = t; // existing local items
    for (final s in server) merged[s.id] = s; // server overrides/adds
    setState(() => _trips = merged.values.toList());
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _start = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _end = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _createTrip() async {
    if (_titleController.text.isEmpty || _start == null || _end == null) return;
    final id = const Uuid().v4();
    final trip = TripEvent(
      id: id,
      userId: widget.userId,
      title: _titleController.text,
      startTime: _start!,
      endTime: _end!,
      destination: TripLocation.fromCoordinates(_destLat, _destLong),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: DateTime.now(),
    );

    // Save locally and attempt to sync
    await TripService.saveLocalTrip(trip);
    await TripService.syncLocalTrips(widget.userId);
    _titleController.clear();
    _notesController.clear();
    setState(() => _trips.add(trip));
    // update suggestions
    if (!_filteredSuggestions.contains(trip.title)) {
      setState(() {
        _filteredSuggestions.insert(0, trip.title);
        if (_filteredSuggestions.length > 20) _filteredSuggestions = _filteredSuggestions.sublist(0, 20);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title with simple suggestion chips
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Trip Title'),
              onChanged: (v) {
                setState(() {
                  // filter suggestions by prefix
                  _filteredSuggestions = ([..._staticSuggestions, ..._trips.map((t)=>t.title)])
                      .where((s) => s.toLowerCase().startsWith(v.toLowerCase())).toSet().toList();
                });
              },
            ),
            const SizedBox(height: 8),
            if (_filteredSuggestions.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, i) {
                    final s = _filteredSuggestions[i];
                    return ChoiceChip(
                      label: Text(s),
                      selected: false,
                      onSelected: (_) {
                        setState(() {
                          _titleController.text = s;
                        });
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _filteredSuggestions.length,
                ),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _pickStart, child: Text(_start == null ? 'Pick Start' : dateFmt.format(_start!)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _pickEnd, child: Text(_end == null ? 'Pick End' : dateFmt.format(_end!)))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Dest Lat'), keyboardType: TextInputType.number, onChanged: (v) => _destLat = double.tryParse(v) ?? 0.0)),
              const SizedBox(width: 8),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Dest Long'), keyboardType: TextInputType.number, onChanged: (v) => _destLong = double.tryParse(v) ?? 0.0)),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _createTrip, child: const Text('Create Trip')),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _trips.length,
                itemBuilder: (context, idx) {
                  final t = _trips[idx];
                  return Card(
                    child: ListTile(
                      title: Text(t.title),
                      subtitle: Text('${dateFmt.format(t.startTime)} → ${dateFmt.format(t.endTime)}\nStatus: ${t.status.apiValue}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
