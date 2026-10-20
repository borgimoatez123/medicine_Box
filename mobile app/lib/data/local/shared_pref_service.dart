import "package:shared_preferences/shared_preferences.dart";

class SharedPrefService {
  SharedPrefService._();
  static final SharedPrefService instance = SharedPrefService._();

  static const String themeModeKey = "app_theme_mode";

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _ensure async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> getString(String key) async {
    try {
      return (await _ensure).getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setString(String key, String value) async {
    try {
      return (await _ensure).setString(key, value);
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(String key) async {
    try {
      return (await _ensure).remove(key);
    } catch (_) {
      return false;
    }
  }
}
