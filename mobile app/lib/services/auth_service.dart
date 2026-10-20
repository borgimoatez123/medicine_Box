import "../data/api_client.dart";
import "../models/user.dart";
import "../utils/constants/api_constants.dart";

typedef AuthResult = ({User user, String? token, Map<String, dynamic> raw});

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.login,
        body: <String, dynamic>{
          "email": email.trim(),
          "password": password,
        },
      );

      return _parseEnvelope(decoded, allowNullUser: false);
    } on ApiHttpException catch (e) {
      throw AuthServiceException(
        _extractErrorMessage(e.payload) ?? e.message,
      );
    } on ApiClientException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  Future<AuthResult> register(User user) async {
    try {
      final Map<String, dynamic> body = user.toJson();
      body.remove("id");
      body.remove("role");
      body.remove("passwordHash");

      final dynamic decoded = await _apiClient.post(
        ApiConstants.register,
        body: body,
      );

      return _parseEnvelope(decoded, allowNullUser: false);
    } on ApiHttpException catch (e) {
      throw AuthServiceException(
        _extractErrorMessage(e.payload) ?? e.message,
      );
    } on ApiClientException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  Future<void> logout({String? token}) async {
    try {
      await _apiClient.post(ApiConstants.logout);
    } on ApiHttpException catch (e) {
      throw AuthServiceException(
        _extractErrorMessage(e.payload) ?? e.message,
      );
    } on ApiClientException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  static AuthResult _parseEnvelope(dynamic decoded, {required bool allowNullUser}) {
    final Map<String, dynamic> envelope = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    final dynamic status = envelope["status"] ?? envelope["success"];
    final bool isSuccess = (status is bool && status == true) ||
        (status is String && status.toLowerCase() == "success") ||
        (status is String && status.toLowerCase() == "ok") ||
        status == null;

    final dynamic message = envelope["message"] ?? envelope["error"];
    if (!isSuccess) {
      throw AuthServiceException(
        (message is String && message.trim().isNotEmpty)
            ? message.trim()
            : "Request failed",
      );
    }

    final dynamic data = envelope["data"] ?? envelope;
    final Map<String, dynamic>? dataMap =
        data is Map<String, dynamic> ? data : null;

    final dynamic userJson =
        (dataMap?["user"]) ?? (envelope["user"]);
    final User? user = userJson is Map<String, dynamic>
        ? User.fromJson(userJson)
        : (allowNullUser ? null : User.fromJson(const <String, dynamic>{}));

    final dynamic tokenDyn = (dataMap ?? envelope)["token"] ??
        (dataMap ?? envelope)["accessToken"] ??
        (dataMap ?? envelope)["access_token"];
    final String? token = tokenDyn is String && tokenDyn.trim().isNotEmpty
        ? tokenDyn.trim()
        : null;

    final Map<String, dynamic> raw = Map<String, dynamic>.from(envelope);
    if (dataMap != null) {
      raw["data"] = Map<String, dynamic>.from(dataMap);
    }

    return (
      user: user ??
          User(
            firstName: "",
            lastName: "",
            email: "",
            password: "",
          ),
      token: token,
      raw: raw,
    );
  }

  static String? _extractErrorMessage(dynamic payload) {
    if (payload == null) return null;
    if (payload is String && payload.trim().isNotEmpty) return payload.trim();
    if (payload is Map<String, dynamic>) {
      final dynamic msg = payload["message"] ??
          payload["error"] ??
          payload["errors"] ??
          payload["detail"];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      if (msg is List && msg.isNotEmpty) {
        return msg.map((dynamic e) => e.toString()).join(", ");
      }
    }
    return null;
  }
}

class AuthServiceException implements Exception {
  AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
