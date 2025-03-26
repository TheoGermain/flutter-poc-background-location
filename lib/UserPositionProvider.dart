import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:poc_gps_bateaux/UserPositionData.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
class UserPositionProvider extends ChangeNotifier {
  static const String userPositionsKey = 'user_positions';

  List<UserPositionData> _items = [];
  bool _isTracking = false;

  UnmodifiableListView<UserPositionData> get items => UnmodifiableListView(_items);

  bool get isTracking => _isTracking;

  UserPositionProvider() {
    _getUserPositions().then((value) {
      _items = value;
      notifyListeners();
    });
    _initializeService();
  }

  LocationSettings get locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        //(Optional) Set foreground notification config to keep the app alive
        //when going to the background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> _handlePermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  Future<void> startRecordingLocations() async {
    try {
      await _handlePermission();
      _isTracking = true;
      notifyListeners();
      final service = FlutterBackgroundService();
      await service.startService();
    } catch (e) {
      print("HERE: $e"); // Add to Log
    }
  }

  void stopTracking() {
    FlutterBackgroundService().invoke("stop");
    _isTracking = false;
    notifyListeners();
  }

  void _addPosition(final UserPositionData position) async {
    final prefs = await SharedPreferences.getInstance();
    final userPositions = await _getUserPositions();
    final newUserPositions = [...userPositions, position];
    _items = newUserPositions;
    notifyListeners();
    prefs.setString(userPositionsKey, jsonEncode(newUserPositions.map((e) => e.toJson()).toList()));
  }

  Future<List<UserPositionData>> _getUserPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsPositions = prefs.getString(userPositionsKey);
    final jsonPositions = prefsPositions == null ? [] : jsonDecode(prefsPositions) as List<dynamic>;
    return jsonPositions.map((e) => UserPositionData.fromJson(e)).toList();
  }

  void clear() async {
    final prefs = await SharedPreferences.getInstance();
    _items.clear();
    await prefs.remove(userPositionsKey);
    notifyListeners();
  }

  Future<void> _initializeService() async {
    final service = FlutterBackgroundService();

    print("[POC] Initializing background service");
    print("[POC] isRunning ${await service.isRunning()}");

    await service.configure(
      iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart, onBackground: onIosBackground),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        onStart: onStart,
        autoStartOnBoot: false,
        isForegroundMode: false, // true ???
      ),
    );
  }
}*/

@pragma('vm:entry-point')
class UserPositionsBackgroundService {
  static final UserPositionsBackgroundService _instance = UserPositionsBackgroundService._internal();

  static ValueNotifier<List<UserPositionData>> items = ValueNotifier<List<UserPositionData>>([]);
  static ValueNotifier<bool> isTracking = ValueNotifier(false);

  static const String userPositionsKey = 'user_positions';

  static LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        //(Optional) Set foreground notification config to keep the app alive
        //when going to the background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  factory UserPositionsBackgroundService() {
    return _instance;
  }

  UserPositionsBackgroundService._internal();

  static init() {
    final service = FlutterBackgroundService();

    items.addListener(() => print("[POC] items changed: ${items.value.length}"));

    print("[POC] UserPositionsBackgroundService.init");
    _retrieveUserLocationsFromPrefs().then((value) {
      print("[POC] locations from prefs : $value");
      items.value = List.from(value);
    });
    service.isRunning().then((value) {
      print("[POC] isRunning $value");
      isTracking.value = value;
    });
  }

  static Future<void> startRecordingLocations() async {
    try {
      await _handlePermission();
      await _initializeService();
      isTracking.value = true;
    } catch (e) {
      print("HERE: $e"); // Add to Log
    }
  }

  static Future<void> _handlePermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  static Future<List<UserPositionData>> _retrieveUserLocationsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsPositions = prefs.getString(userPositionsKey);
    final jsonPositions = prefsPositions == null ? [] : jsonDecode(prefsPositions) as List<dynamic>;
    return jsonPositions.map((e) => UserPositionData.fromJson(e)).toList();
  }

  static updateItems() async {
    final userPositions = await _retrieveUserLocationsFromPrefs();
    print("HERE - ${userPositions.length} positions");
    items.value = List.from(userPositions);
  }

  static void _addPosition(final UserPositionData position) async {
    print("[POC] Adding position: ${position.toJson()}");
    final prefs = await SharedPreferences.getInstance();
    final userPositions = await _retrieveUserLocationsFromPrefs();
    final newUserPositions = [...userPositions, position];
    items.value = List.from(newUserPositions);
    prefs.setString(userPositionsKey, jsonEncode(newUserPositions.map((e) => e.toJson()).toList()));
    print("[POC] Position added - ${items.value.length} positions");
  }

  static Future<void> _initializeService() async {
    final service = FlutterBackgroundService();

    print("[POC] Initializing background service");

    await service.configure(
      iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart, onBackground: onIosBackground),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        autoStartOnBoot: false,
        isForegroundMode: true,
      ),
    );
  }

  static void stopTracking() {
    FlutterBackgroundService().invoke("stop");
    isTracking.value = false;
  }

  static void clear() async {
    final prefs = await SharedPreferences.getInstance();
    items.value = [];
    await prefs.remove(userPositionsKey);
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print("[POC] onIosBackground");
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    print("[POC] onStart entry point");

    service.on("stop").listen((event) {
      service.stopSelf();
      print("[POC] Background process is now stopped");
    });

    service.on("start").listen((event) {
      print("[POC] Background process is now started");
    });

    Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(locationSettings: _locationSettings);
        _addPosition(
          UserPositionData(position: LatLng(position.latitude, position.longitude), timestamp: DateTime.now()),
        );

        print('[POC] Location tracked: ${position.latitude}, ${position.longitude}'); // Add to Log
      } catch (e) {
        print('[POC] Error tracking location: $e'); // Add to Log
      }
    });
  }
}
