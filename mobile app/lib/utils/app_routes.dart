/// Purpose:
/// - Centralizes named route paths used by the application.
///
/// Responsibilities:
/// - Provide a single source of truth for route names.
/// - Enable future implementation of a route generator and guarded routes
///   (e.g., auth-gated navigation).
///
/// Used by:
/// - lib/main.dart (routing setup, future)
/// - All screens for navigation (future)
class AppRoutes {
  static const String splash = "/splash";
  static const String auth = "/auth";
  static const String home = "/home";
  static const String profile = "/profile";
  static const String patients = "/patients";
  static const String medications = "/medications";
  static const String prescriptions = "/prescriptions";
  static const String smartBox = "/smart-box";
  static const String notifications = "/notifications";
  static const String reports = "/reports";
  static const String settings = "/settings";
}
