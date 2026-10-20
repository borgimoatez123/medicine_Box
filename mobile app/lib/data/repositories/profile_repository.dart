import "dart:convert";

import "package:flutter/foundation.dart";

import "../api_client.dart";
import "../../models/user_model.dart";
import "../../services/auth_storage.dart";
import "../../utils/constants/api_constants.dart";

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient, AuthStorage? authStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _storage;

  static const Set<String> _allowedProfileKeys = <String>{
    "firstName",
    "lastName",
    "email",
    "phone",
  };

  Future<UserModel> getProfile() async => getMe();

  Future<UserModel> getMe() async {
    final dynamic decoded = await _apiClient.get(ApiConstants.me);
    final Map<String, dynamic>? userJson = _extractPublicUser(decoded);
    if (userJson == null) {
      throw ProfileRepositoryException("Invalid profile response");
    }

    final UserModel user = UserModel.fromJson(userJson);
    await _cacheUser(user, userJson);
    return user;
  }

  Future<UserModel> getUserProfile(String userId) async {
    final dynamic decoded = await _apiClient.get(
      "${ApiConstants.users}/$userId",
    );
    final Map<String, dynamic>? userJson = _extractPublicUser(decoded);
    if (userJson == null) {
      throw ProfileRepositoryException("Invalid profile response");
    }
    final UserModel user = UserModel.fromJson(userJson);
    await _cacheUser(user, userJson);
    return user;
  }

  Future<UserModel> updateProfile(Map<String, dynamic> changes) async {
    return updateMe(changes);
  }

  Future<UserModel> updateMe(Map<String, dynamic> changes) async {
    final Map<String, dynamic> sanitized = _sanitizeUpdateBody(changes);
    if (sanitized.isEmpty) {
      return getMe();
    }

    final dynamic decoded;
    try {
      decoded = await _apiClient.patch(
        ApiConstants.me,
        body: sanitized,
      );
    } on ApiHttpException catch (e) {
      debugPrint("updateMe HTTP ${e.statusCode}: ${jsonEncode(e.payload)}");
      throw _enrichError(e);
    }

    final Map<String, dynamic> userJson =
        _extractPublicUser(decoded) ?? _asUserJson(sanitized);
    final UserModel user = UserModel.fromJson(userJson);
    await _cacheUser(user, userJson);
    return user;
  }

  Future<UserModel> updateUserProfile(
    String userId,
    Map<String, dynamic> changes,
  ) async {
    final Map<String, dynamic> sanitized = _sanitizeUpdateBody(changes);
    if (sanitized.isEmpty) {
      return getUserProfile(userId);
    }

    final dynamic decoded = await _apiClient.patch(
      "${ApiConstants.users}/$userId",
      body: sanitized,
    );
    final Map<String, dynamic> userJson =
        _extractPublicUser(decoded) ?? _asUserJson(sanitized);
    final UserModel user = UserModel.fromJson(userJson);
    await _cacheUser(user, userJson);
    return user;
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      "currentPassword": currentPassword,
      "newPassword": newPassword,
    };

    try {
      final dynamic decoded = await _apiClient.patch(
        ApiConstants.mePassword,
        body: body,
      );
      final String? msg = _extractTopLevelMessage(decoded);
      return msg;
    } on ApiHttpException catch (e) {
      debugPrint(
        "changePassword HTTP ${e.statusCode}: ${jsonEncode(e.payload)}",
      );
      throw _enrichError(e);
    }
  }

  Future<void> logout() async {
    final String? accessToken = await _storage.readAccessToken();
    if (accessToken == null || accessToken.trim().isEmpty) return;
    try {
      await _apiClient.post(
        ApiConstants.logout,
        body: const <String, dynamic>{},
      );
    } catch (_) {}
  }

  Future<void> forgotPassword({required String email}) async {
    await _apiClient.post(
      ApiConstants.forgotPassword,
      body: <String, dynamic>{"email": email.trim()},
    );
  }

  Future<void> resetPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.post(
      ApiConstants.resetPassword,
      body: <String, dynamic>{
        "currentPassword": currentPassword,
        "newPassword": newPassword,
        "confirmPassword": confirmPassword,
      },
    );
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete(ApiConstants.deleteMe);
  }

  Map<String, dynamic> _sanitizeUpdateBody(Map<String, dynamic> body) {
    final Map<String, dynamic> out = <String, dynamic>{};

    void addAllowed(String canonicalKey, dynamic rawValue) {
      if (!_allowedProfileKeys.contains(canonicalKey)) return;
      if (rawValue == null) {
        if (canonicalKey == "phone") {
          out[canonicalKey] = null;
        }
        return;
      }
      if (rawValue is String) {
        if (canonicalKey == "phone" && rawValue.trim().isEmpty) {
          out[canonicalKey] = null;
          return;
        }
        final String trimmed = canonicalKey == "phone"
            ? rawValue.trim()
            : (canonicalKey == "email"
                ? rawValue.trim()
                : rawValue.trim());
        if (trimmed.isEmpty && canonicalKey != "phone") return;
        if (trimmed.isEmpty) return;
        out[canonicalKey] = trimmed;
        return;
      }
      out[canonicalKey] = rawValue;
    }

    body.forEach((String key, dynamic value) {
      final String k = key.trim();
      final String canonical = _canonicalKey(k);
      if (!_allowedProfileKeys.contains(canonical)) return;
      addAllowed(canonical, value);
    });

    return out;
  }

  String _canonicalKey(String key) {
    switch (key) {
      case "firstName":
      case "firstname":
      case "first_name":
        return "firstName";
      case "lastName":
      case "lastname":
      case "last_name":
        return "lastName";
      case "email":
        return "email";
      case "phone":
      case "phoneNumber":
      case "mobile":
        return "phone";
      default:
        return key;
    }
  }

  Future<void> _cacheUser(UserModel user, Map<String, dynamic> userJson) async {
    try {
      await _storage.saveUserJson(jsonEncode(userJson));
    } catch (_) {}
    if (user.id.trim().isNotEmpty) {
      final String? accessToken = await _storage.readAccessToken();
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        try {
          await _storage.saveSession(
            accessToken: accessToken.trim(),
            userId: user.id.trim(),
          );
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic>? _extractPublicUser(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final dynamic status = decoded["status"];
    final bool hasEnvelope = status != null || decoded.containsKey("data");

    if (hasEnvelope) {
      final dynamic data = decoded["data"];
      if (data is Map<String, dynamic>) {
        final dynamic user = data["user"] ?? data["profile"] ?? data["me"];
        if (user is Map<String, dynamic>) return user;
        if (_looksLikePublicUser(data)) return data;
      }
      final dynamic user = decoded["user"] ?? decoded["profile"] ?? decoded["me"];
      if (user is Map<String, dynamic>) return user;
      if (_looksLikePublicUser(decoded)) return decoded;
      return null;
    }

    if (_looksLikePublicUser(decoded)) return decoded;
    return null;
  }

  bool _looksLikePublicUser(Map<String, dynamic> json) {
    final bool hasIdentifying = json.containsKey("id") ||
        json.containsKey("_id") ||
        json.containsKey("email");
    final bool hasPublicField = json.containsKey("firstName") ||
        json.containsKey("firstname") ||
        json.containsKey("lastName") ||
        json.containsKey("lastname") ||
        json.containsKey("phone");
    return hasIdentifying && hasPublicField;
  }

  Map<String, dynamic> _asUserJson(Map<String, dynamic> partial) {
    return Map<String, dynamic>.from(partial);
  }

  String? _extractTopLevelMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final dynamic msg = decoded["message"];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  Exception _enrichError(ApiHttpException e) {
    final dynamic payload = e.payload;
    if (payload is Map<String, dynamic>) {
      final dynamic msg = payload["message"] ??
          payload["error"] ??
          payload["errors"] ??
          payload["detail"];
      if (msg is String && msg.trim().isNotEmpty) {
        return ProfileRepositoryException(msg.trim());
      }
      if (msg is List && msg.isNotEmpty) {
        return ProfileRepositoryException(
          msg.map((dynamic e) => e.toString()).join(", "),
        );
      }
    }
    return ProfileRepositoryException(e.message);
  }
}

class ProfileRepositoryException implements Exception {
  ProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
