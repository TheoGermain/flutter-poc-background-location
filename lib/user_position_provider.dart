import 'dart:async';
import 'dart:collection';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:hive_flutter/adapters.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:poc_gps_bateaux/user_position_data.dart';

class UserPositionProvider extends ChangeNotifier {
  static const String userPositionsKey = 'user_positions';

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

  Future<void> _handlePermission() async {
    final bool serviceEnabled = (await Permission.location.serviceStatus).isEnabled;
    var status = isBackgroundTaskEnabled ? await Permission.locationAlways.status : await Permission.location.status;

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    if (status == PermissionStatus.denied) {
      status =
          isBackgroundTaskEnabled ? await Permission.locationAlways.request() : await Permission.location.request();
      if (status != PermissionStatus.granted) {
        return Future.error('Location permissions are denied');
      }
    }
    /*if (permission == geo.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }*/
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
      print("[POC] Error when start recording locations: $e");
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
    await locationBox.put(position.timestamp.toIso8601String(), {
      'lat': position.position.latitude,
      'lon': position.position.longitude,
    });
    locationBox.close();
    final newUserPositions = [..._items, position];
    _items = newUserPositions;
    notifyListeners();
  }

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

  void clear() async {
    final locationBox = await _getLocationBox();
    locationBox.clear();
    locationBox.close();
    _items.clear();
    notifyListeners();
  }

  Future<void> initBackgroundService() async {
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
        iOSConfig: IOSConfig(activityType: ActivityType.NAVIGATION, distanceFilterMeters: null, restartAfterKill: true),
      ),
    );
    print('[POC] BackgroundLocationTrackerManager initialized, isTracking: $_isTracking');
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
    } catch (e) {}
  });
}
