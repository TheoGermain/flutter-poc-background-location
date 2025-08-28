import 'dart:async';
import 'dart:collection';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:hive_flutter/adapters.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poc_gps_bateaux/UserPositionData.dart';
import 'dart:developer' as developer;

class UserPositionProvider extends ChangeNotifier {
  static const String userPositionsKey = 'user_positions';

  final bool isBackgroundTaskEnabled;
  List<UserPositionData> _items = [];
  bool _isTracking = false;
  Timer? _timer;

  UnmodifiableListView<UserPositionData> get items => UnmodifiableListView(_items);

  bool get isTracking => _isTracking;

  UserPositionProvider(this.isBackgroundTaskEnabled) {
    retrieveUserPositionsFromLocalStorage();
  }

  geo.LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 50,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 15),
        //(Optional) Set foreground notification config to keep the app alive
        //when going to the background
        /*foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationText: "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ),*/
      );
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

  Future<void> _handlePermission() async {
    final bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  Future<void> startRecordingLocations() async {
    try {
      await _handlePermission();
      _isTracking = true;
      notifyListeners();
      //await _getPosition();
      if (isBackgroundTaskEnabled) {
        _startLocationTracking();
        /*BackgroundFetch.start()
            .then((int status) {
              print('[BackgroundFetch] start success: $status');
            })
            .catchError((e) {
              print('[BackgroundFetch] start FAILURE: $e');
            });*/
      } else {
        _timer = Timer.periodic(Duration(seconds: 15), (timer) {
          _getPosition();
        });
      }
    } catch (e) {
      print("[POC] Error when start recording locations: $e");
    }
  }

  void stopTracking() {
    if (isBackgroundTaskEnabled) {
      _stopLocationTracking();
      /*BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });*/
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
    await locationBox.put(position.timestamp.toIso8601String(), {
      'lat': position.position.latitude,
      'lon': position.position.longitude,
    });
    locationBox.close();
    final newUserPositions = [..._items, position];
    _items = newUserPositions;
    notifyListeners();
  }

  /*void _addPosition(final UserPositionData position) async {
    final prefs = await SharedPreferences.getInstance();
    final userPositions = await _retrieveUserPositionsFromPrefs();
    final newUserPositions = [...userPositions, position];
    _items = newUserPositions;
    notifyListeners();
    prefs.setString(userPositionsKey, jsonEncode(newUserPositions.map((e) => e.toJson()).toList()));
  }*/

  Future<void> retrieveUserPositionsFromLocalStorage() async {
    final locationBox = await _getLocationBox();
    final entries = locationBox.toMap();
    locationBox.close();
    final positions =
        entries.entries.map((e) {
          final data = e.value as Map;
          return UserPositionData(
            position: LatLng(data['lat'] as double, data['lon'] as double),
            timestamp: DateTime.parse(e.key),
          );
        }).toList();
    positions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _items = positions;
    notifyListeners();
  }

  /*Future<List<UserPositionData>> _retrieveUserPositionsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsPositions = prefs.getString(userPositionsKey);
    final jsonPositions = prefsPositions == null ? [] : jsonDecode(prefsPositions) as List<dynamic>;
    return jsonPositions.map((e) => UserPositionData.fromJson(e)).toList();
  }*/

  void clear() async {
    final locationBox = await _getLocationBox();
    locationBox.clear();
    locationBox.close();
    _items.clear();
    notifyListeners();
  }

  /*void clear() async {
    final prefs = await SharedPreferences.getInstance();
    _items.clear();
    await prefs.remove(userPositionsKey);
    notifyListeners();
  }*/

  Future<void> initBackgroundService() async {
    await BackgroundLocationTrackerManager.initialize(
      backgroundCallback,
      config: BackgroundLocationTrackerConfig(
        loggingEnabled: true,
        androidConfig: const AndroidConfig(
          notificationIcon: 'explore',
          trackingInterval: Duration(seconds: 15),
          distanceFilterMeters: null,
        ),
        iOSConfig: IOSConfig(activityType: ActivityType.NAVIGATION, distanceFilterMeters: null, restartAfterKill: true),
      ),
    );
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    print('[POC] BackgroundLocationTrackerManager initialized, isTracking: $_isTracking');
    notifyListeners();
  }

  /*Future<void> _initService() async {
    final int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: true,
        enableHeadless: false,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE,
      ),
      (String taskId) async {
        print("[BackgroundFetch] Event received $taskId");
        await _getPosition();
        BackgroundFetch.finish(taskId);
      },
      (String taskId) async {
        print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
        BackgroundFetch.finish(taskId);
      },
    );
    print('[BackgroundFetch] configure success: $status');
  }*/

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
        UserPositionData(position: LatLng(position.latitude, position.longitude), timestamp: DateTime.now()),
      );
      // preloadTiles(lastPosition: LatLng(position.latitude, position.longitude));
      print('[POC] Location tracked: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('[POC] Error tracking location: $e');
    }
  }

  Future _startLocationTracking() async {
    print('[POC] Start location tracking');
    await BackgroundLocationTrackerManager.startTracking();
  }

  Future _stopLocationTracking() async {
    print('[POC] Stopping location tracking');
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
      await locationBox.put(DateTime.now().toIso8601String(), {'lat': data.lat, 'lon': data.lon});
      await locationBox.close();

      // Ajouter un log pour confirmer le traitement
      developer.log('[POC] Background location saved: ${data.lat}, ${data.lon}');
    } catch (e) {
      developer.log('[POC] Error in background callback: $e');
    }
  });
}
