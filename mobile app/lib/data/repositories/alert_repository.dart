import "../api_client.dart";
import "../../models/alert_model.dart";
import "../../services/auth_storage.dart";
import "../../utils/constants/api_constants.dart";

class AlertRepository {
  AlertRepository({ApiClient? apiClient, AuthStorage? authStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<String> _requireAccessToken() async {
    final String? token = await _authStorage.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw AlertRepositoryException("Missing access token");
    }
    return token.trim();
  }

  Map<String, String> _authHeaders(String token) {
    return <String, String>{"Authorization": "Bearer $token"};
  }

  List<AlertModel> _extractList(dynamic decoded) {
    if (decoded == null) return <AlertModel>[];
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => AlertModel.fromJson(e))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> e) => AlertModel.fromJson(e))
            .toList();
      }
      if (data is Map<String, dynamic>) {
        final dynamic items =
            data["alerts"] ?? data["reminders"] ?? data["items"];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => AlertModel.fromJson(e))
              .toList();
        }
      }
      final dynamic items =
          decoded["alerts"] ??
          decoded["reminders"] ??
          decoded["items"] ??
          decoded["notifications"] ??
          decoded["result"];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> e) => AlertModel.fromJson(e))
            .toList();
      }
    }
    return <AlertModel>[];
  }

  Future<List<AlertModel>> getAlertsByPatient(String patientId) async {
    final String token = await _requireAccessToken();
    final String pid = patientId.trim();
    if (pid.isEmpty) {
      throw AlertRepositoryException("Missing patient id");
    }
    final dynamic decoded = await _apiClient.get(
      "${ApiConstants.alertsByPatient}/$pid",
      headers: _authHeaders(token),
    );
    return _extractList(decoded);
  }
}

class AlertRepositoryException implements Exception {
  AlertRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
