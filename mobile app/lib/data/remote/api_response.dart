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
