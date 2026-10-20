import "../api_client.dart";
import "../../models/medication_event_model.dart";
import "../../utils/constants/api_constants.dart";

class MedicationEventRepository {
  MedicationEventRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Fetches medication events.
  ///
  /// The backend JWT already scopes the authenticated user's patients.
  /// When [patientId] is supplied, it is passed as a query parameter for
  /// backend-side filtering; never use the user ID in its place.
  Future<MedicationEventListResult> getMedicationEvents({
    String? patientId,
    int limit = 20,
    int offset = 0,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      "limit": limit > 0 ? limit : 20,
      "offset": offset >= 0 ? offset : 0,
    };
    final String? pid = patientId?.trim();
    if (pid != null && pid.isNotEmpty) {
      query["patientId"] = pid;
    }
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.medicationEvents,
        queryParameters: query,
      );
      return parseMedicationEventListResponse(decoded);
    } catch (e) {
      throw MedicationEventRepositoryException(_friendly(e));
    }
  }

  String _friendly(dynamic e) {
    final int? status = _httpStatus(e);
    if (status == 401) {
      return "Your session has expired. Please log in again.";
    }
    if (status == 403) {
      return "You are not authorized to view these medication events.";
    }
    if (status == 404) {
      return "Medication events are currently unavailable.";
    }
    if (status != null && status >= 500) {
      return "The server is currently unavailable. Please try again later.";
    }
    final String lower = e.toString().toLowerCase();
    if (lower.contains("timeout") || lower.contains("timed out")) {
      return "The request timed out. Please try again.";
    }
    if (lower.contains("socket") ||
        lower.contains("dns") ||
        lower.contains("unreachable") ||
        lower.contains("failed host") ||
        lower.contains("failed to connect")) {
      return "Unable to connect to the medicine box server.\nPlease check your connection and try again.";
    }
    return "Unable to load medication events. Please try again.";
  }

  int? _httpStatus(dynamic e) {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic code = e.statusCode;
      if (code is int) return code;
    } catch (_) {}
    final String s = e.toString();
    final RegExpMatch? m = RegExp(r"\b(\d{3})\b").firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

class MedicationEventRepositoryException implements Exception {
  MedicationEventRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
