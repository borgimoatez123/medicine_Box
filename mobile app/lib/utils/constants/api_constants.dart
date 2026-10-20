class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://192.168.1.170:3000/api",
  );

  static const String healthUrl = String.fromEnvironment(
    "HEALTH_URL",
    defaultValue: "http://192.168.1.170:3000/health",
  );

  static const String register = "/auth/register";
  static const String login = "/auth/login";
  static const String logout = "/auth/logout";
  static const String forgotPassword = "/auth/forgot-password";
  static const String resetPassword = "/auth/reset-password";

  static const String patients = "/patients";
  @Deprecated(
    "Do not use /patients/user/:userId. "
    "Use GET /patients which filters by authenticated JWT user automatically.",
  )
  static const String patientsByUser = "/patients/user";

  static const String medications = "/medications";
  @Deprecated(
    "Do not use /medications/patient/:patientId. "
    "Use GET /medications?patientId=... which filters by authenticated JWT user automatically.",
  )
  static const String medicationsByPatient = "/medications/patient";

  static const String schedules = "/schedules";

  static const String medicineBoxes = "/medicine-boxes";
  static const String activateMedicineBox = "/medicine-boxes/activate";
  static const String medicineBoxSensors = "/medicine-boxes";
  static const String drawers = "/drawers";
  static const String drawerMedications = "/drawer-medications";

  static const String alerts = "/alerts";
  static const String alertsByPatient = "/alerts/patient";

  static const String devices = "/devices";
  static const String medicationEvents = "/devices/medication-events";

  static const String me = "/users/me";
  static const String mePassword = "/users/me/password";
  static const String deleteMe = "/users/me";
  static const String users = "/users";
  static const String profile = "/users/profile";
}
