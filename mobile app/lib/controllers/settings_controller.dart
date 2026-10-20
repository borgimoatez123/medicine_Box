import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../data/local/shared_pref_service.dart";

class SettingsController extends ChangeNotifier {
  SettingsController._internal();
  static final SettingsController instance = SettingsController._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _initialized = false;
  bool get initialized => _initialized;

  static ThemeMode _parseMode(String? raw) {
    switch (raw) {
      case "light":
        return ThemeMode.light;
      case "dark":
        return ThemeMode.dark;
      case "system":
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "light";
      case ThemeMode.dark:
        return "dark";
      case ThemeMode.system:
        return "system";
    }
  }

  Future<void> load() async {
    final String? raw = await SharedPrefService.instance
        .getString(SharedPrefService.themeModeKey);
    _themeMode = _parseMode(raw);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode && _initialized) return;
    _themeMode = mode;
    notifyListeners();
    await SharedPrefService.instance.setString(
      SharedPrefService.themeModeKey,
      _serializeMode(mode),
    );
  }
}
