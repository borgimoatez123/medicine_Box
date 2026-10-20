import "../../data/api_client.dart";
import "../../models/user.dart";
import "../../services/auth_service.dart";
import "../../services/auth_storage.dart";

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    AuthService? authService,
    AuthStorage? storage,
  }) : _authService = authService ?? AuthService(apiClient: apiClient),
       _storage = storage ?? AuthStorage();

  final AuthService _authService;
  final AuthStorage _storage;

  Future<({User user, String? token})> login({
    required String email,
    required String password,
  }) async {
    final AuthResult result = await _authService.login(
      email: email,
      password: password,
    );
    await _persist(result);
    return (user: result.user, token: result.token);
  }

  Future<({User user, String? token})> register(User user) async {
    final AuthResult result = await _authService.register(user);
    if (result.token != null && result.token!.isNotEmpty) {
      await _persist(result);
    }
    return (user: result.user, token: result.token);
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    await _storage.clearSession();
  }

  Future<bool> hasValidSession() => _storage.hasValidAccessToken();

  Future<String?> readAccessToken() => _storage.readAccessToken();

  Future<String?> readUserId() => _storage.readUserId();

  Future<void> saveUserJson(Map<String, dynamic> user) async {
    try {
      await _storage.saveUserJson(
        user
            .map<String, dynamic>(
              (String k, dynamic v) => MapEntry<String, dynamic>(k, v),
            )
            .toString(),
      );
    } catch (_) {}
  }

  Future<void> _persist(AuthResult result) async {
    final Map<String, dynamic> raw = result.raw;
    final Map<String, dynamic>? data = raw["data"] is Map<String, dynamic>
        ? raw["data"] as Map<String, dynamic>
        : null;

    final dynamic token =
        (data ?? raw)["token"] ??
        (data ?? raw)["accessToken"] ??
        (data ?? raw)["access_token"] ??
        result.token;
    final String? accessToken = token is String && token.trim().isNotEmpty
        ? token.trim()
        : null;

    final dynamic refresh =
        (data ?? raw)["refreshToken"] ?? (data ?? raw)["refresh_token"];
    final String? refreshToken = refresh is String && refresh.trim().isNotEmpty
        ? refresh.trim()
        : null;

    final dynamic userJson = (data ?? raw)["user"] ?? raw["user"];
    final Map<String, dynamic>? userMap = userJson is Map<String, dynamic>
        ? userJson
        : null;
    final dynamic id =
        userMap?["id"] ?? userMap?["_id"] ?? raw["userId"] ?? result.user.id;
    final String? userId = id == null ? null : id.toString();

    if (accessToken == null || accessToken.isEmpty) return;

    await _storage.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );
  }

  static const String registerPath = "/auth/register";
  static const String loginPath = "/auth/login";
  static const String logoutPath = "/auth/logout";
}
