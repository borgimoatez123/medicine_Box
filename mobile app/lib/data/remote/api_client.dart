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
