import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigProvider extends ChangeNotifier {
  static const String enableBackgroundTasksKey = 'enable_background_tasks';

  ConfigProvider() {
    SharedPreferences.getInstance().then((prefs) {
      final enableBackgroundTasks = prefs.getBool(enableBackgroundTasksKey) ?? false;
      _config = _config.copy(enableBackgroundTasks: enableBackgroundTasks);
      notifyListeners();
    });
  }

  Config _config = Config();

  bool get shouldDisplayLastLocationOnly => _config.shouldDisplayLastLocationOnly;

  bool get shouldDisplayLinesBetweenLocations => _config.shouldDisplayLinesBetweenLocations;

  bool get enableBackgroundTasks => _config.enableBackgroundTasks;

  void updateShouldDisplayLastLocationOnly(final bool value) {
    _config = _config.copy(
      shouldDisplayLastLocationOnly: value,
      shouldDisplayLinesBetweenLocations: value ? false : shouldDisplayLinesBetweenLocations,
    );
    notifyListeners();
  }

  void updateShouldDisplayLinesBetweenLocations(final bool value) {
    _config = _config.copy(
      shouldDisplayLastLocationOnly: value ? false : shouldDisplayLastLocationOnly,
      shouldDisplayLinesBetweenLocations: value,
    );
    notifyListeners();
  }

  void updateEnableBackgroundTasks(final bool value) {
    _config = _config.copy(enableBackgroundTasks: value);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(enableBackgroundTasksKey, value);
    });
    notifyListeners();
  }
}

class Config {
  Config({
    this.shouldDisplayLastLocationOnly = false,
    this.shouldDisplayLinesBetweenLocations = false,
    this.enableBackgroundTasks = false,
  });

  final bool shouldDisplayLastLocationOnly;
  final bool shouldDisplayLinesBetweenLocations;
  final bool enableBackgroundTasks;

  Config copy({
    bool? shouldDisplayLastLocationOnly,
    bool? shouldDisplayLinesBetweenLocations,
    bool? enableBackgroundTasks,
  }) {
    return Config(
      shouldDisplayLastLocationOnly: shouldDisplayLastLocationOnly ?? this.shouldDisplayLastLocationOnly,
      shouldDisplayLinesBetweenLocations: shouldDisplayLinesBetweenLocations ?? this.shouldDisplayLinesBetweenLocations,
      enableBackgroundTasks: enableBackgroundTasks ?? this.enableBackgroundTasks,
    );
  }
}
