import 'package:flutter/foundation.dart';

class ConfigProvider extends ChangeNotifier {
  Config _config = Config();

  bool get shouldDisplayLastLocationOnly => _config.shouldDisplayLastLocationOnly;

  bool get shouldDisplayLinesBetweenLocations => _config.shouldDisplayLinesBetweenLocations;

  void updateShouldDisplayLastLocationOnly(final bool value) {
    _config = Config(
      shouldDisplayLastLocationOnly: value,
      shouldDisplayLinesBetweenLocations: value ? false : shouldDisplayLinesBetweenLocations,
    );
    notifyListeners();
  }

  void updateShouldDisplayLinesBetweenLocations(final bool value) {
    _config = Config(
      shouldDisplayLastLocationOnly: value ? false : shouldDisplayLastLocationOnly,
      shouldDisplayLinesBetweenLocations: value,
    );
    notifyListeners();
  }
}

class Config {
  Config({this.shouldDisplayLastLocationOnly = false, this.shouldDisplayLinesBetweenLocations = false});

  final bool shouldDisplayLastLocationOnly;
  final bool shouldDisplayLinesBetweenLocations;
}
