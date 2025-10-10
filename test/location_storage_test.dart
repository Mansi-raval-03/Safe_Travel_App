import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/services/location_service.dart';
import '../lib/services/offline_database_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('Location Storage Tests', () {
    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('Should store location data to SQLite database', () async {
      // Create a mock position
      final mockPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 3.0,
        heading: 180.0,
        speed: 2.5,
        speedAccuracy: 1.0,
        headingAccuracy: 5.0,
      );

      // Store location directly using OfflineDatabaseService
      final offlineDb = OfflineDatabaseService.instance;
      final storedId = await offlineDb.storeLocationData(mockPosition);

      // Verify location was stored
      expect(storedId, greaterThan(0));

      // Retrieve the stored location
      final recentLocations = await offlineDb.getRecentStoredLocations(limit: 1);
      expect(recentLocations.length, equals(1));

      final storedLocation = recentLocations.first;
      expect(storedLocation['latitude'], equals(37.7749));
      expect(storedLocation['longitude'], equals(-122.4194));
      expect(storedLocation['accuracy'], equals(5.0));
    });

    test('Should retrieve recent stored locations', () async {
      final offlineDb = OfflineDatabaseService.instance;
      
      // Clear existing data for clean test
      await offlineDb.clearAllData();
      
      // Store multiple mock locations with proper timing intervals
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749, longitude: -122.4194, timestamp: now.subtract(Duration(minutes: 10)),
          accuracy: 5.0, altitude: 10.0, altitudeAccuracy: 3.0, heading: 180.0, speed: 2.5,
          speedAccuracy: 1.0, headingAccuracy: 5.0,
        ),
        Position(
          latitude: 37.7849, longitude: -122.4294, timestamp: now.subtract(Duration(minutes: 5)),
          accuracy: 4.0, altitude: 12.0, altitudeAccuracy: 3.0, heading: 190.0, speed: 3.0,
          speedAccuracy: 1.0, headingAccuracy: 5.0,
        ),
        Position(
          latitude: 37.7949, longitude: -122.4394, timestamp: now,
          accuracy: 3.0, altitude: 15.0, altitudeAccuracy: 3.0, heading: 200.0, speed: 3.5,
          speedAccuracy: 1.0, headingAccuracy: 5.0,
        ),
      ];

      // Store all positions
      for (final position in positions) {
        await offlineDb.storeLocationData(position);
      }

      // Retrieve recent locations
      final recentLocations = await offlineDb.getRecentStoredLocations(limit: 3);
      expect(recentLocations.length, equals(3));
      
      // Verify all test locations are present
      final latitudes = recentLocations.map((loc) => loc['latitude'] as double).toList();
      expect(latitudes, contains(37.7749));
      expect(latitudes, contains(37.7849)); 
      expect(latitudes, contains(37.7949));
    });

    test('Should track unsynced locations', () async {
      final offlineDb = OfflineDatabaseService.instance;
      
      // Store a mock location
      final mockPosition = Position(
        latitude: 40.7128, longitude: -74.0060, timestamp: DateTime.now(),
        accuracy: 5.0, altitude: 10.0, altitudeAccuracy: 3.0, heading: 180.0, speed: 2.5,
        speedAccuracy: 1.0, headingAccuracy: 5.0,
      );
      
      await offlineDb.storeLocationData(mockPosition);

      // Get unsynced locations
      final unsyncedLocations = await offlineDb.getUnsyncedLocations();
      expect(unsyncedLocations.length, greaterThan(0));

      // Verify the location is marked as unsynced
      final location = unsyncedLocations.firstWhere(
        (loc) => loc['latitude'] == 40.7128 && loc['longitude'] == -74.0060,
        orElse: () => {},
      );
      expect(location.isNotEmpty, isTrue);
      expect(location['is_synced'], equals(0));
    });
  });
}