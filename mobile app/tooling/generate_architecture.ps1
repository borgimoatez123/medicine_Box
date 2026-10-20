$ErrorActionPreference = "Stop"

function Write-DartFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Ensure-Dir {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

$Root = Split-Path -Parent $PSScriptRoot

Ensure-Dir (Join-Path $Root "lib")

Ensure-Dir (Join-Path $Root "lib\controllers")
Ensure-Dir (Join-Path $Root "lib\data\local")
Ensure-Dir (Join-Path $Root "lib\data\remote")
Ensure-Dir (Join-Path $Root "lib\data\repositories")
Ensure-Dir (Join-Path $Root "lib\models")
Ensure-Dir (Join-Path $Root "lib\screens")
Ensure-Dir (Join-Path $Root "lib\services")
Ensure-Dir (Join-Path $Root "lib\utils")
Ensure-Dir (Join-Path $Root "lib\widgets")
Ensure-Dir (Join-Path $Root "lib\assets\images")
Ensure-Dir (Join-Path $Root "lib\assets\icons")
Ensure-Dir (Join-Path $Root "lib\assets\animations")
Ensure-Dir (Join-Path $Root "lib\assets\fonts")

$screenModules = @(
  "splash",
  "auth",
  "home",
  "profile",
  "patients",
  "medications",
  "prescriptions",
  "smart_box",
  "notifications",
  "reports",
  "settings"
)

foreach ($module in $screenModules) {
  Ensure-Dir (Join-Path $Root "lib\screens\$module")
  Ensure-Dir (Join-Path $Root "lib\screens\$module\widgets")
  Ensure-Dir (Join-Path $Root "lib\screens\$module\components")
}

$widgetBuckets = @(
  "buttons",
  "cards",
  "dialogs",
  "forms",
  "inputs",
  "navigation",
  "loading",
  "appbars",
  "bottom_sheets",
  "empty_state",
  "common"
)

foreach ($bucket in $widgetBuckets) {
  Ensure-Dir (Join-Path $Root "lib\widgets\$bucket")
}

Write-DartFile (Join-Path $Root "lib\main.dart") @'
/// Purpose:
/// - Defines the application bootstrap entry point for the Smart Medication
///   Management System (AI-powered) connected to an IoT Smart Medicine Dispenser.
///
/// Responsibilities:
/// - Wire together app-wide configuration (routing, theming, localization, and
///   dependency composition) once implementation starts.
/// - Provide a single place to initialize critical runtime concerns such as
///   JWT session restore, Supabase initialization, notification setup, and
///   connectivity monitoring.
///
/// Used by:
/// - All future screens, as the root application entry and composition boundary.
class AppBootstrap {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\auth_controller.dart") @'
/// Purpose:
/// - Coordinates authentication-related presentation logic for the app.
///
/// Responsibilities:
/// - Orchestrate sign-in/sign-up/logout flows and token/session lifecycle.
/// - Mediate between UI and data layer (repositories/services) for auth.
/// - Expose authentication state to future UI without coupling to any
///   specific state-management library.
///
/// Used by:
/// - lib/screens/auth/screen.dart
/// - lib/screens/splash/screen.dart
/// - lib/screens/settings/screen.dart
class AuthController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\patient_controller.dart") @'
/// Purpose:
/// - Coordinates patient management presentation logic.
///
/// Responsibilities:
/// - Orchestrate patient CRUD flows and selection of active patient context.
/// - Bridge UI to repositories/services for patient data retrieval and updates.
///
/// Used by:
/// - lib/screens/patients/screen.dart
/// - lib/screens/home/screen.dart
/// - lib/screens/prescriptions/screen.dart
class PatientController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\medication_controller.dart") @'
/// Purpose:
/// - Coordinates medication management presentation logic.
///
/// Responsibilities:
/// - Orchestrate medication CRUD flows and medication catalog browsing.
/// - Mediate UI interactions with data layer (repositories/services).
///
/// Used by:
/// - lib/screens/medications/screen.dart
/// - lib/screens/prescriptions/screen.dart
class MedicationController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\prescription_controller.dart") @'
/// Purpose:
/// - Coordinates prescription management presentation logic.
///
/// Responsibilities:
/// - Orchestrate prescription CRUD flows and schedule-related operations.
/// - Coordinate verification requirements (OCR/AI) at a presentation level.
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/home/screen.dart
/// - lib/screens/reports/screen.dart
class PrescriptionController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\notification_controller.dart") @'
/// Purpose:
/// - Coordinates notification-related presentation logic.
///
/// Responsibilities:
/// - Orchestrate notification preferences and in-app notification state.
/// - Coordinate push notification registration lifecycle (later implementation).
///
/// Used by:
/// - lib/screens/notifications/screen.dart
/// - lib/screens/settings/screen.dart
class NotificationController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\report_controller.dart") @'
/// Purpose:
/// - Coordinates reporting and analytics presentation logic.
///
/// Responsibilities:
/// - Orchestrate report retrieval, filtering, and export triggers.
/// - Mediate between UI and reporting repositories/services.
///
/// Used by:
/// - lib/screens/reports/screen.dart
/// - lib/screens/home/screen.dart
class ReportController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\smart_box_controller.dart") @'
/// Purpose:
/// - Coordinates Smart Medicine Dispenser (IoT Box) presentation logic.
///
/// Responsibilities:
/// - Orchestrate pairing/configuration flows and device status presentation.
/// - Mediate between UI and Smart Box repositories/services.
///
/// Used by:
/// - lib/screens/smart_box/screen.dart
/// - lib/screens/home/screen.dart
class SmartBoxController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\profile_controller.dart") @'
/// Purpose:
/// - Coordinates user profile presentation logic.
///
/// Responsibilities:
/// - Orchestrate profile retrieval/update flows and user preferences.
/// - Mediate between UI and profile repositories/services.
///
/// Used by:
/// - lib/screens/profile/screen.dart
/// - lib/screens/settings/screen.dart
class ProfileController {}
'@

Write-DartFile (Join-Path $Root "lib\controllers\settings_controller.dart") @'
/// Purpose:
/// - Coordinates application settings presentation logic.
///
/// Responsibilities:
/// - Orchestrate app-wide settings such as theme mode, localization, and
///   notification preferences.
/// - Provide a stable interface for settings screens without binding to any
///   state-management framework yet.
///
/// Used by:
/// - lib/screens/settings/screen.dart
class SettingsController {}
'@

Write-DartFile (Join-Path $Root "lib\data\local\local_storage.dart") @'
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
'@

Write-DartFile (Join-Path $Root "lib\data\local\shared_pref_service.dart") @'
/// Purpose:
/// - Defines a SharedPreferences-based local persistence adapter.
///
/// Responsibilities:
/// - Persist lightweight app settings (locale, theme preference, flags).
/// - Provide a dedicated adapter for SharedPreferences to keep repositories
///   storage-agnostic.
///
/// Used by:
/// - lib/data/local/local_storage.dart
/// - lib/controllers/settings_controller.dart
/// - lib/screens/settings/screen.dart
class SharedPrefService {}
'@

Write-DartFile (Join-Path $Root "lib\data\local\sqlite_service.dart") @'
/// Purpose:
/// - Defines a SQLite persistence adapter for structured offline data.
///
/// Responsibilities:
/// - Provide offline-first data caching for patients/medications/prescriptions.
/// - Encapsulate database initialization, migrations, and query execution.
///
/// Used by:
/// - lib/data/repositories/patient_repository.dart
/// - lib/data/repositories/medication_repository.dart
/// - lib/data/repositories/prescription_repository.dart
class SqliteService {}
'@

Write-DartFile (Join-Path $Root "lib\data\remote\api_client.dart") @'
/// Purpose:
/// - Defines the network client abstraction for REST/Supabase requests.
///
/// Responsibilities:
/// - Provide a single integration point for HTTP requests, headers, and error
///   mapping (JWT, refresh, retries) once implemented.
/// - Standardize request/response handling across repositories.
///
/// Used by:
/// - lib/data/repositories/auth_repository.dart
/// - lib/data/repositories/patient_repository.dart
/// - lib/data/repositories/medication_repository.dart
/// - lib/data/repositories/prescription_repository.dart
/// - lib/data/repositories/report_repository.dart
/// - lib/data/repositories/smart_box_repository.dart
class ApiClient {}
'@

Write-DartFile (Join-Path $Root "lib\data\remote\api_constants.dart") @'
/// Purpose:
/// - Centralizes API configuration constants (base URLs, endpoints, timeouts).
///
/// Responsibilities:
/// - Provide environment-aware configuration for REST API and Supabase.
/// - Standardize endpoint naming and reduce string duplication across the app.
///
/// Used by:
/// - lib/data/remote/api_client.dart
/// - lib/data/repositories/*_repository.dart
class ApiConstants {}
'@

Write-DartFile (Join-Path $Root "lib\data\remote\api_response.dart") @'
/// Purpose:
/// - Represents a normalized, transport-level API response wrapper.
///
/// Responsibilities:
/// - Provide a consistent shape for success/failure responses and metadata.
/// - Enable repositories to map transport errors to domain-friendly models.
///
/// Used by:
/// - lib/data/remote/api_client.dart
/// - lib/data/repositories/*_repository.dart
class ApiResponse {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\auth_repository.dart") @'
/// Purpose:
/// - Defines authentication data access and session persistence boundaries.
///
/// Responsibilities:
/// - Abstract remote auth operations (REST/Supabase auth) from controllers.
/// - Manage token storage (JWT) via local storage adapters.
///
/// Used by:
/// - lib/controllers/auth_controller.dart
/// - lib/services/auth_service.dart
class AuthRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\patient_repository.dart") @'
/// Purpose:
/// - Defines patient data access boundaries (remote + local cache).
///
/// Responsibilities:
/// - Provide patient CRUD and search operations.
/// - Encapsulate caching strategy (SQLite) and remote sync rules.
///
/// Used by:
/// - lib/controllers/patient_controller.dart
/// - lib/services/patient_service.dart
class PatientRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\medication_repository.dart") @'
/// Purpose:
/// - Defines medication data access boundaries (remote + local cache).
///
/// Responsibilities:
/// - Provide medication CRUD and reference data retrieval.
/// - Encapsulate caching and synchronization for medication data.
///
/// Used by:
/// - lib/controllers/medication_controller.dart
/// - lib/services/medication_service.dart
class MedicationRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\prescription_repository.dart") @'
/// Purpose:
/// - Defines prescription data access boundaries (remote + local cache).
///
/// Responsibilities:
/// - Provide prescription CRUD, schedules, and adherence state retrieval.
/// - Encapsulate offline caching and remote sync for prescriptions.
///
/// Used by:
/// - lib/controllers/prescription_controller.dart
/// - lib/services/prescription_service.dart
class PrescriptionRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\notification_repository.dart") @'
/// Purpose:
/// - Defines notification data access boundaries.
///
/// Responsibilities:
/// - Retrieve and store notification history and preferences.
/// - Coordinate push token registration persistence (future).
///
/// Used by:
/// - lib/controllers/notification_controller.dart
/// - lib/services/notification_service.dart
class NotificationRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\report_repository.dart") @'
/// Purpose:
/// - Defines reporting data access boundaries.
///
/// Responsibilities:
/// - Retrieve adherence reports, audit logs, and analytics from backend.
/// - Provide export-ready data sets for future reporting screens.
///
/// Used by:
/// - lib/controllers/report_controller.dart
/// - lib/services/report_service.dart
class ReportRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\smart_box_repository.dart") @'
/// Purpose:
/// - Defines Smart Medicine Dispenser (IoT Box) data access boundaries.
///
/// Responsibilities:
/// - Provide device pairing, configuration, and telemetry retrieval operations.
/// - Encapsulate communication strategy (REST, BLE, MQTT) in the future.
///
/// Used by:
/// - lib/controllers/smart_box_controller.dart
/// - lib/services/smart_box_service.dart
class SmartBoxRepository {}
'@

Write-DartFile (Join-Path $Root "lib\data\repositories\profile_repository.dart") @'
/// Purpose:
/// - Defines user profile data access boundaries.
///
/// Responsibilities:
/// - Retrieve/update profile information and account settings.
/// - Provide local persistence for profile-related preferences as needed.
///
/// Used by:
/// - lib/controllers/profile_controller.dart
/// - lib/services/auth_service.dart
/// - lib/services/patient_service.dart
class ProfileRepository {}
'@

Write-DartFile (Join-Path $Root "lib\models\user_model.dart") @'
/// Purpose:
/// - Represents an authenticated application user.
///
/// Responsibilities:
/// - Provide a stable data contract for user identity and account metadata.
/// - Support mapping from REST/Supabase auth payloads to app-friendly shapes.
///
/// Used by:
/// - lib/screens/profile/screen.dart
/// - lib/screens/settings/screen.dart
/// - lib/controllers/auth_controller.dart
class UserModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\patient_model.dart") @'
/// Purpose:
/// - Represents a patient managed within the application.
///
/// Responsibilities:
/// - Provide a stable contract for patient demographics and identifiers.
/// - Support offline caching and sync with backend in the future.
///
/// Used by:
/// - lib/screens/patients/screen.dart
/// - lib/screens/prescriptions/screen.dart
/// - lib/controllers/patient_controller.dart
class PatientModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\medication_model.dart") @'
/// Purpose:
/// - Represents a medication entity within the application.
///
/// Responsibilities:
/// - Define medication attributes and identifiers for prescriptions and catalog.
/// - Support mapping from OCR/AI verification results to medication records.
///
/// Used by:
/// - lib/screens/medications/screen.dart
/// - lib/screens/prescriptions/screen.dart
/// - lib/controllers/medication_controller.dart
class MedicationModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\prescription_model.dart") @'
/// Purpose:
/// - Represents a prescription including dosage and scheduling metadata.
///
/// Responsibilities:
/// - Provide the core contract used by reminders, smart box dispensing,
///   adherence tracking, and reporting.
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/home/screen.dart
/// - lib/controllers/prescription_controller.dart
class PrescriptionModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\notification_model.dart") @'
/// Purpose:
/// - Represents an in-app notification or reminder item.
///
/// Responsibilities:
/// - Provide a contract for notification rendering and history tracking.
/// - Support mapping from push notification payloads to persistent records.
///
/// Used by:
/// - lib/screens/notifications/screen.dart
/// - lib/controllers/notification_controller.dart
class NotificationModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\report_model.dart") @'
/// Purpose:
/// - Represents a report entity (adherence summary, audit, analytics).
///
/// Responsibilities:
/// - Define a stable contract for report types and aggregated metrics.
/// - Enable export and sharing features in the future.
///
/// Used by:
/// - lib/screens/reports/screen.dart
/// - lib/controllers/report_controller.dart
class ReportModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\smart_box_model.dart") @'
/// Purpose:
/// - Represents a Smart Medicine Dispenser (IoT Box) device.
///
/// Responsibilities:
/// - Define device identity, connectivity status, and configuration metadata.
/// - Support pairing and telemetry mapping from backend/edge services.
///
/// Used by:
/// - lib/screens/smart_box/screen.dart
/// - lib/controllers/smart_box_controller.dart
class SmartBoxModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\medicine_box_model.dart") @'
/// Purpose:
/// - Represents the physical medicine box layout and constraints.
///
/// Responsibilities:
/// - Model compartments/drawers and capacity rules for dispensing.
/// - Support mapping device configuration to a UI-friendly structure.
///
/// Used by:
/// - lib/screens/smart_box/screen.dart
/// - lib/services/smart_box_service.dart
class MedicineBoxModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\drawer_model.dart") @'
/// Purpose:
/// - Represents a single drawer/compartment in the medicine dispenser.
///
/// Responsibilities:
/// - Provide a contract for drawer indexing, capacity, and assigned medication.
/// - Support configuration and verification flows in the future.
///
/// Used by:
/// - lib/screens/smart_box/screen.dart
/// - lib/models/medicine_box_model.dart
class DrawerModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\api_error_model.dart") @'
/// Purpose:
/// - Represents a normalized API error returned by REST/Supabase services.
///
/// Responsibilities:
/// - Provide a stable structure for error codes, messages, and debug metadata.
/// - Support consistent error display and logging across the app.
///
/// Used by:
/// - lib/data/remote/api_client.dart
/// - lib/utils/logger.dart
/// - lib/screens/common error handling (future)
class ApiErrorModel {}
'@

Write-DartFile (Join-Path $Root "lib\models\response_model.dart") @'
/// Purpose:
/// - Represents a generic response wrapper used throughout the app.
///
/// Responsibilities:
/// - Provide a consistent way to propagate success/failure results from
///   repositories/services to controllers and UI.
///
/// Used by:
/// - lib/services/*_service.dart
/// - lib/controllers/*_controller.dart
class ResponseModel {}
'@

Write-DartFile (Join-Path $Root "lib\services\auth_service.dart") @'
/// Purpose:
/// - Defines domain-level authentication operations.
///
/// Responsibilities:
/// - Coordinate auth flows using AuthRepository and local persistence.
/// - Provide reusable auth operations to controllers without UI concerns.
///
/// Used by:
/// - lib/controllers/auth_controller.dart
/// - lib/screens/auth/screen.dart
class AuthService {}
'@

Write-DartFile (Join-Path $Root "lib\services\patient_service.dart") @'
/// Purpose:
/// - Defines domain-level patient operations.
///
/// Responsibilities:
/// - Coordinate patient CRUD and business validations (future).
/// - Provide reusable patient operations across multiple screens.
///
/// Used by:
/// - lib/controllers/patient_controller.dart
/// - lib/screens/patients/screen.dart
class PatientService {}
'@

Write-DartFile (Join-Path $Root "lib\services\medication_service.dart") @'
/// Purpose:
/// - Defines domain-level medication operations.
///
/// Responsibilities:
/// - Coordinate medication CRUD and catalog retrieval (future).
/// - Provide reusable operations for prescriptions and verification flows.
///
/// Used by:
/// - lib/controllers/medication_controller.dart
/// - lib/screens/medications/screen.dart
class MedicationService {}
'@

Write-DartFile (Join-Path $Root "lib\services\prescription_service.dart") @'
/// Purpose:
/// - Defines domain-level prescription operations.
///
/// Responsibilities:
/// - Coordinate prescription schedules, adherence, and verification triggers.
/// - Provide a shared domain API for home reminders and reports.
///
/// Used by:
/// - lib/controllers/prescription_controller.dart
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/home/screen.dart
class PrescriptionService {}
'@

Write-DartFile (Join-Path $Root "lib\services\notification_service.dart") @'
/// Purpose:
/// - Defines notification orchestration and push integration operations.
///
/// Responsibilities:
/// - Coordinate local reminders and push notifications (future).
/// - Provide notification preference application and scheduling.
///
/// Used by:
/// - lib/controllers/notification_controller.dart
/// - lib/screens/notifications/screen.dart
/// - lib/screens/settings/screen.dart
class NotificationService {}
'@

Write-DartFile (Join-Path $Root "lib\services\report_service.dart") @'
/// Purpose:
/// - Defines report orchestration and transformation operations.
///
/// Responsibilities:
/// - Coordinate report retrieval and formatting for UI/export (future).
/// - Provide reusable report operations across the app.
///
/// Used by:
/// - lib/controllers/report_controller.dart
/// - lib/screens/reports/screen.dart
class ReportService {}
'@

Write-DartFile (Join-Path $Root "lib\services\smart_box_service.dart") @'
/// Purpose:
/// - Defines Smart Box orchestration operations.
///
/// Responsibilities:
/// - Coordinate device pairing, configuration, and status monitoring (future).
/// - Provide a domain API to controllers without UI coupling.
///
/// Used by:
/// - lib/controllers/smart_box_controller.dart
/// - lib/screens/smart_box/screen.dart
class SmartBoxService {}
'@

Write-DartFile (Join-Path $Root "lib\services\ai_service.dart") @'
/// Purpose:
/// - Defines AI verification integration boundary.
///
/// Responsibilities:
/// - Provide a stable contract to request AI-based medication verification
///   and receive structured results (future).
/// - Encapsulate integration with external AI services and model endpoints.
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/medications/screen.dart
/// - lib/screens/smart_box/screen.dart
class AiService {}
'@

Write-DartFile (Join-Path $Root "lib\services\ocr_service.dart") @'
/// Purpose:
/// - Defines OCR verification integration boundary.
///
/// Responsibilities:
/// - Provide a stable contract to extract medication label data from images.
/// - Encapsulate OCR provider selection and parsing rules (future).
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/medications/screen.dart
class OcrService {}
'@

Write-DartFile (Join-Path $Root "lib\services\camera_service.dart") @'
/// Purpose:
/// - Defines camera capture integration boundary.
///
/// Responsibilities:
/// - Provide a stable contract to open camera, capture images, and manage
///   permissions (future).
/// - Serve OCR and AI verification workflows.
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/medications/screen.dart
/// - lib/screens/smart_box/screen.dart
class CameraService {}
'@

Write-DartFile (Join-Path $Root "lib\services\connectivity_service.dart") @'
/// Purpose:
/// - Defines connectivity monitoring and network reachability boundary.
///
/// Responsibilities:
/// - Provide a stable contract to observe connectivity changes (future).
/// - Enable offline-first behavior and graceful error handling.
///
/// Used by:
/// - lib/screens/home/screen.dart
/// - lib/screens/splash/screen.dart
/// - lib/data/remote/api_client.dart
class ConnectivityService {}
'@

Write-DartFile (Join-Path $Root "lib\utils\app_colors.dart") @'
/// Purpose:
/// - Centralizes application color tokens for consistent theming.
///
/// Responsibilities:
/// - Define semantic colors (primary, success, warning) for light/dark themes.
/// - Ensure the UI remains accessible and consistent across screens.
///
/// Used by:
/// - lib/utils/app_theme.dart
/// - lib/screens/*/widgets/*
class AppColors {}
'@

Write-DartFile (Join-Path $Root "lib\utils\app_strings.dart") @'
/// Purpose:
/// - Centralizes user-facing strings and localization keys.
///
/// Responsibilities:
/// - Provide a single place for English/French/Arabic keys and labels.
/// - Support future integration with Flutter localization tooling.
///
/// Used by:
/// - All screens for text labels (future)
/// - lib/screens/settings/screen.dart (locale selection)
class AppStrings {}
'@

Write-DartFile (Join-Path $Root "lib\utils\app_images.dart") @'
/// Purpose:
/// - Centralizes image asset paths used throughout the app.
///
/// Responsibilities:
/// - Provide strongly-named asset references for images (future).
/// - Reduce duplication and prevent typo-related asset load issues.
///
/// Used by:
/// - lib/screens/splash/screen.dart
/// - lib/screens/auth/screen.dart
/// - lib/screens/home/screen.dart
class AppImages {}
'@

Write-DartFile (Join-Path $Root "lib\utils\app_icons.dart") @'
/// Purpose:
/// - Centralizes icon asset paths and icon identifiers.
///
/// Responsibilities:
/// - Provide a consistent icon naming strategy across the UI.
/// - Support adaptive icons for light/dark mode in the future.
///
/// Used by:
/// - All screens for navigation and action icons (future)
class AppIcons {}
'@

Write-DartFile (Join-Path $Root "lib\utils\app_routes.dart") @'
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
'@

Write-DartFile (Join-Path $Root "lib\utils\app_theme.dart") @'
/// Purpose:
/// - Defines the application theming boundary.
///
/// Responsibilities:
/// - Provide placeholders for Light Theme and Dark Theme configuration.
/// - Centralize typography, component styling, and theme tokens.
///
/// Used by:
/// - lib/main.dart (theme setup, future)
/// - lib/screens/settings/screen.dart (theme mode selection)
class AppTheme {}
'@

Write-DartFile (Join-Path $Root "lib\utils\validators.dart") @'
/// Purpose:
/// - Centralizes form and input validation contracts.
///
/// Responsibilities:
/// - Provide reusable validation helpers for emails, passwords, and medical
///   identifiers (future).
/// - Keep validation consistent across all features.
///
/// Used by:
/// - lib/screens/auth/screen.dart
/// - lib/screens/profile/screen.dart
/// - lib/screens/patients/screen.dart
class Validators {}
'@

Write-DartFile (Join-Path $Root "lib\utils\constants.dart") @'
/// Purpose:
/// - Centralizes non-UI constants used across the application.
///
/// Responsibilities:
/// - Store reusable constants for timeouts, limits, and feature flags.
/// - Provide a stable reference point for environment configuration.
///
/// Used by:
/// - lib/data/remote/api_constants.dart
/// - lib/services/connectivity_service.dart
class AppConstants {}
'@

Write-DartFile (Join-Path $Root "lib\utils\extensions.dart") @'
/// Purpose:
/// - Defines Dart/Flutter extension placeholders used across the app.
///
/// Responsibilities:
/// - Provide a dedicated location for future safe extensions on common types
///   (String, DateTime, BuildContext) without mixing concerns.
///
/// Used by:
/// - All screens and services (future)
class AppExtensions {}
'@

Write-DartFile (Join-Path $Root "lib\utils\date_formatter.dart") @'
/// Purpose:
/// - Centralizes date and time formatting rules.
///
/// Responsibilities:
/// - Provide locale-aware formatting for English/French/Arabic (future).
/// - Standardize formatting used in notifications, prescriptions, and reports.
///
/// Used by:
/// - lib/screens/prescriptions/screen.dart
/// - lib/screens/notifications/screen.dart
/// - lib/screens/reports/screen.dart
class DateFormatter {}
'@

Write-DartFile (Join-Path $Root "lib\utils\logger.dart") @'
/// Purpose:
/// - Defines the logging boundary for the application.
///
/// Responsibilities:
/// - Provide a centralized interface for logs and error reporting (future).
/// - Support privacy-aware logging for healthcare data (no PHI leakage).
///
/// Used by:
/// - lib/data/remote/api_client.dart
/// - lib/services/*_service.dart
/// - lib/controllers/*_controller.dart
class AppLogger {}
'@

Write-DartFile (Join-Path $Root "lib\utils\helpers.dart") @'
/// Purpose:
/// - Centralizes small, reusable helper contracts used across the app.
///
/// Responsibilities:
/// - Provide a dedicated place for future utility helpers that do not belong
///   to validators, extensions, or formatting.
///
/// Used by:
/// - All layers as needed (future)
class AppHelpers {}
'@

Write-DartFile (Join-Path $Root "lib\screens\splash\screen.dart") @'
/// Purpose:
/// - Defines the Splash screen entry module for initial app startup.
///
/// Responsibilities:
/// - Display startup/loading state while the app restores session, loads
///   configuration, initializes notifications, and checks connectivity (future).
/// - Decide initial navigation target (auth vs home) once implemented.
///
/// Used by:
/// - The application bootstrap flow defined in lib/main.dart (future).
class SplashScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\auth\screen.dart") @'
/// Purpose:
/// - Defines the Authentication screen module.
///
/// Responsibilities:
/// - Provide user interfaces for login, registration, and password recovery
///   once implementation starts.
/// - Integrate with AuthController to coordinate authentication flows.
///
/// Used by:
/// - lib/screens/splash/screen.dart (navigation)
/// - lib/screens/settings/screen.dart (logout, future)
class AuthScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\home\screen.dart") @'
/// Purpose:
/// - Defines the Home screen module and primary navigation entry after login.
///
/// Responsibilities:
/// - Provide an overview of schedules, upcoming doses, and device status (future).
/// - Surface navigation to patients, medications, prescriptions, notifications,
///   reports, and smart box configuration.
///
/// Used by:
/// - lib/screens/splash/screen.dart (post-auth navigation, future)
class HomeScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\profile\screen.dart") @'
/// Purpose:
/// - Defines the user Profile screen module.
///
/// Responsibilities:
/// - Display and edit user profile data (future).
/// - Integrate with ProfileController for profile retrieval and updates.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
/// - lib/screens/settings/screen.dart (profile options, future)
class ProfileScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\patients\screen.dart") @'
/// Purpose:
/// - Defines the Patients screen module.
///
/// Responsibilities:
/// - List, create, and manage patients (future).
/// - Integrate with PatientController to coordinate patient flows.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
/// - lib/screens/prescriptions/screen.dart (patient selection, future)
class PatientsScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\medications\screen.dart") @'
/// Purpose:
/// - Defines the Medications screen module.
///
/// Responsibilities:
/// - List, create, and manage medications (future).
/// - Integrate with MedicationController for medication CRUD workflows.
/// - Support OCR/AI assisted verification for medications (future).
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
/// - lib/screens/prescriptions/screen.dart (medication selection, future)
class MedicationsScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\prescriptions\screen.dart") @'
/// Purpose:
/// - Defines the Prescriptions screen module.
///
/// Responsibilities:
/// - Create and manage prescriptions with schedules and adherence metadata (future).
/// - Integrate with PrescriptionController for orchestration of flows.
/// - Trigger OCR/AI verification and smart box assignment (future).
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
/// - lib/screens/reports/screen.dart (report drill-down, future)
class PrescriptionsScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\smart_box\screen.dart") @'
/// Purpose:
/// - Defines the Smart Box (IoT Dispenser) configuration screen module.
///
/// Responsibilities:
/// - Pair/configure the device and manage drawers/compartments (future).
/// - Integrate with SmartBoxController for device orchestration.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
class SmartBoxScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\notifications\screen.dart") @'
/// Purpose:
/// - Defines the Notifications screen module.
///
/// Responsibilities:
/// - Display notification history and manage reminders (future).
/// - Integrate with NotificationController for notification orchestration.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
/// - lib/screens/settings/screen.dart (preferences, future)
class NotificationsScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\reports\screen.dart") @'
/// Purpose:
/// - Defines the Reports screen module.
///
/// Responsibilities:
/// - Display adherence and system reports, with filtering and export (future).
/// - Integrate with ReportController for report orchestration.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
class ReportsScreen {}
'@

Write-DartFile (Join-Path $Root "lib\screens\settings\screen.dart") @'
/// Purpose:
/// - Defines the Settings screen module.
///
/// Responsibilities:
/// - Provide configuration for theme (dark mode), localization (EN/FR/AR),
///   notifications, and account actions (future).
/// - Integrate with SettingsController for app-wide settings orchestration.
///
/// Used by:
/// - lib/screens/home/screen.dart (navigation, future)
class SettingsScreen {}
'@

Write-Host "Architecture scaffolding generated successfully."

