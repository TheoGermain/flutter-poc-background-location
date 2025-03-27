import 'package:flutter/foundation.dart';

class ConfigProvider extends ChangeNotifier {
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
