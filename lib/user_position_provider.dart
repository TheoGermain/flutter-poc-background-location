import 'dart:async';
import 'dart:collection';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:hive_flutter/adapters.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:poc_gps_bateaux/user_position_data.dart';
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'main.dart';

class UserPositionProvider extends ChangeNotifier {
  static const String userPositionsKey = 'user_positions';
  static const String sendLocationTaskId = 'send_locations';
  static const String oneTimeSyncUniqueNameId = 'sync-task';

  final bool isBackgroundTaskEnabled;
  List<UserPositionData> _items = [];
  bool _isTracking = false;
  Timer? _timer;

  UnmodifiableListView<UserPositionData> get items => UnmodifiableListView(_items);

  Future<bool> get isTracking =>
      isBackgroundTaskEnabled ? BackgroundLocationTrackerManager.isTracking() : Future.value(_isTracking);

  UserPositionProvider(this.isBackgroundTaskEnabled) {
    retrieveUserPositionsFromLocalStorage();
  }

  geo.LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return geo.AndroidSettings(accuracy: geo.LocationAccuracy.high, intervalDuration: const Duration(seconds: 15));
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return geo.AppleSettings(
        accuracy: geo.LocationAccuracy.high,
        activityType: geo.ActivityType.otherNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> initBackgroundService() async {
    Workmanager().initialize(callbackDispatcher);

    if (await BackgroundLocationTrackerManager.isTracking()) {
      return;
    }
    await BackgroundLocationTrackerManager.initialize(
      backgroundCallback,
      config: BackgroundLocationTrackerConfig(
        loggingEnabled: true,
        androidConfig: const AndroidConfig(
          notificationIcon: 'explore',
          trackingInterval: Duration(seconds: 15),
          distanceFilterMeters: null,
        ),
        iOSConfig: IOSConfig(
          activityType: ActivityType.AUTOMOTIVE, // ActivityType.FITNESS,
          distanceFilterMeters: null,
          restartAfterKill: true,
        ),
      ),
    );
    logger.i('[POC] BackgroundLocationTrackerManager initialized, isTracking: $_isTracking');
  }

  Future<void> _handlePermission() async {
    final bool serviceEnabled = (await Permission.location.serviceStatus).isEnabled;
    logger.d('[POC] Location service enabled: $serviceEnabled');
    final foregroundLocationPermissionStatus = await Permission.locationWhenInUse.status;
    logger.d('[POC] foregroundLocationPermission permission status: $foregroundLocationPermissionStatus');

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    if (foregroundLocationPermissionStatus != PermissionStatus.granted) {
      await Permission.locationWhenInUse.request().then((status) async {
        if (status == PermissionStatus.granted && isBackgroundTaskEnabled) {
          await Permission.locationAlways.request();
        }
      });
    }
  }

  Future<void> startRecordingLocations() async {
    try {
      await _handlePermission();
      _isTracking = true;
      notifyListeners();
      if (isBackgroundTaskEnabled) {
        _startLocationTracking();
      } else {
        _timer = Timer.periodic(Duration(seconds: 15), (timer) {
          _getPosition();
        });
      }
    } catch (e) {
      logger.e("[POC] Error when start recording locations: $e");
    }
  }

  void stopTracking() {
    if (isBackgroundTaskEnabled) {
      _stopLocationTracking();
    }
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    _isTracking = false;
    notifyListeners();
  }

  void _addPosition(final UserPositionData position) async {
    final locationBox = await _getLocationBox();
    await locationBox.add({
      'timestamp': position.timestamp.toIso8601String(),
      'latitude': position.position.latitude,
      'longitude': position.position.longitude,
      'isAlreadySent': false,
    });
    locationBox.close();
    final newUserPositions = [..._items, position];
    _items = newUserPositions;
    notifyListeners();
  }

  Future<void> retrieveUserPositionsFromLocalStorage() async {
    final locationBox = await _getLocationBox();
    final values = locationBox.values;
    locationBox.close();
    final positions =
        values.map((data) {
          return UserPositionData(
            position: LatLng(data['latitude'] as double, data['longitude'] as double),
            timestamp: DateTime.parse(data['timestamp'] as String),
            alreadySent: data['isAlreadySent'] as bool,
          );
        }).toList();
    positions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _items = positions;
    notifyListeners();
  }

  void clear() async {
    final locationBox = await _getLocationBox();
    await locationBox.clear();
    await locationBox.close();
    _items.clear();
    notifyListeners();
  }

  Future<Box> _getLocationBox() async {
    if (!Hive.isBoxOpen('locationBox')) {
      return Hive.openBox('locationBox');
    } else {
      return Hive.box('locationBox');
    }
  }

  Future<void> _getPosition() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(locationSettings: _locationSettings);
      _addPosition(
        UserPositionData(
          position: LatLng(position.latitude, position.longitude),
          timestamp: DateTime.now(),
          alreadySent: false,
        ),
      );
      // preloadTiles(lastPosition: LatLng(position.latitude, position.longitude));
      logger.i('[POC] Location tracked: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      logger.e('[POC] Error tracking location: $e');
    }
  }

  Future _startLocationTracking() async {
    logger.i('[POC] Start location tracking');
    await BackgroundLocationTrackerManager.startTracking();
  }

  Future _stopLocationTracking() async {
    logger.i('[POC] Stopping location tracking');
    await BackgroundLocationTrackerManager.stopTracking();
  }
}

@pragma('vm:entry-point')
void backgroundCallback() async {
  BackgroundLocationTrackerManager.handleBackgroundUpdated((data) async {
    WidgetsFlutterBinding.ensureInitialized();
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    try {
      Box locationBox;
      if (!Hive.isBoxOpen('locationBox')) {
        locationBox = await Hive.openBox('locationBox');
      } else {
        locationBox = Hive.box('locationBox');
      }
      await locationBox.add({
        'latitude': data.lat,
        'longitude': data.lon,
        'timestamp': DateTime.now().toIso8601String(),
        'isAlreadySent': false,
      });
      await locationBox.close();

      Workmanager().registerOneOffTask(
        UserPositionProvider.oneTimeSyncUniqueNameId,
        UserPositionProvider.sendLocationTaskId,
        initialDelay: Duration(seconds: 5),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      logger.e("[POC] Error storing background location: $e");
    }
  });
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    if (task == UserPositionProvider.sendLocationTaskId) {
      Box locationBox;
      if (!Hive.isBoxOpen('locationBox')) {
        locationBox = await Hive.openBox('locationBox');
      } else {
        locationBox = Hive.box('locationBox');
      }
      try {
        final db = FirebaseFirestore.instance;
        final unsentLocations = locationBox.values.where((element) => element['isAlreadySent'] == false).toList();
        final batch = db.batch();
        for (var location in unsentLocations) {
          batch.set(db.collection('locations').doc(), {
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'timestamp': location['timestamp'],
          });
        }
        await batch.commit();

        // Marquer toutes les données non envoyées comme envoyées
        final keys = locationBox.keys.toList();
        for (var key in keys) {
          final data = locationBox.get(key);
          if (data != null && data['isAlreadySent'] == false) {
            await locationBox.put(key, {...data, 'isAlreadySent': true});
          }
        }
      } catch (_) {
        return Future.value(false);
      } finally {
        await locationBox.close();
      }
    }
    return Future.value(true);
  });
}
