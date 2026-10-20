import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../utils/jwt_utils.dart";

class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final FlutterSecureStorage _storage;

  static const String _kAccessToken = "accessToken";
  static const String _kRefreshToken = "refreshToken";
  static const String _kUserId = "userId";
  static const String _kUserJson = "userJson";

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken.trim());
    }
    if (userId != null && userId.trim().isNotEmpty) {
      await _storage.write(key: _kUserId, value: userId.trim());
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<String?> readUserId() => _storage.read(key: _kUserId);

  Future<void> saveUserJson(String json) async {
    await _storage.write(key: _kUserJson, value: json);
  }

  Future<String?> readUserJson() => _storage.read(key: _kUserJson);

  Future<bool> hasValidAccessToken() async {
    final String? token = await readAccessToken();
    if (token == null || token.trim().isEmpty) return false;
    return !JwtUtils.isExpired(token.trim());
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kUserJson);
  }
}
