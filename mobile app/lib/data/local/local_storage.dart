/// Purpose:
/// - Defines a local storage abstraction boundary used by repositories.
///
/// Responsibilities:
/// - Provide a unified interface for persisting small key/value data and
///   secure tokens when implementation starts.
/// - Hide underlying persistence mechanisms (SharedPreferences, secure storage,
///   SQLite) from the rest of the app.
///
/// Used by:
/// - lib/data/repositories/auth_repository.dart
/// - lib/data/repositories/profile_repository.dart
/// - lib/screens/splash/screen.dart
class LocalStorage {}
