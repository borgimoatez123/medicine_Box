import "package:flutter/foundation.dart";

import "../models/user.dart";
import "../services/auth_service.dart";
import "../services/auth_storage.dart";

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService, AuthStorage? storage})
    : _authService = authService ?? AuthService(),
      _storage = storage ?? AuthStorage();

  final AuthService _authService;
  final AuthStorage _storage;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<void> login({required String email, required String password}) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final AuthResult result = await _authService.login(
        email: email,
        password: password,
      );

      _currentUser = result.user;
      await _persistAuth(
        raw: result.raw,
        fallbackToken: result.token,
        fallbackUserId: result.user.id,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
    String phone = "",
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final User user = User(
        firstName: firstname.trim(),
        lastName: lastname.trim(),
        email: email.trim(),
        password: password,
        phone: phone.trim().isEmpty ? null : phone.trim(),
      );

      final AuthResult result = await _authService.register(user);
      _currentUser = result.user;

      if (result.token != null && result.token!.isNotEmpty) {
        await _persistAuth(
          raw: result.raw,
          fallbackToken: result.token,
          fallbackUserId: result.user.id,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistAuth({
    required Map<String, dynamic> raw,
    String? fallbackToken,
    String? fallbackUserId,
  }) async {
    final Map<String, dynamic>? data = raw["data"] is Map<String, dynamic>
        ? raw["data"] as Map<String, dynamic>
        : null;

    final dynamic token =
        (data ?? raw)["token"] ??
        (data ?? raw)["accessToken"] ??
        (data ?? raw)["access_token"] ??
        fallbackToken;
    final String? accessToken = token is String && token.trim().isNotEmpty
        ? token.trim()
        : null;

    final dynamic refreshTokenDyn =
        (data ?? raw)["refreshToken"] ?? (data ?? raw)["refresh_token"];
    final String? refreshToken =
        refreshTokenDyn is String && refreshTokenDyn.trim().isNotEmpty
        ? refreshTokenDyn.trim()
        : null;

    final dynamic userJson = (data ?? raw)["user"] ?? raw["user"];
    final Map<String, dynamic>? userMap = userJson is Map<String, dynamic>
        ? userJson
        : null;
    final dynamic id =
        userMap?["id"] ?? userMap?["_id"] ?? raw["userId"] ?? fallbackUserId;
    final String? userId = id == null ? null : id.toString();

    final String? tokenValue = accessToken;
    if (tokenValue == null || tokenValue.isEmpty) return;

    await _storage.saveSession(
      accessToken: tokenValue,
      refreshToken: refreshToken,
      userId: userId,
    );
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    await _storage.clearSession();
    _currentUser = null;
  }
}
