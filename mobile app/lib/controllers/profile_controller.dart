import "dart:convert";

import "package:flutter/foundation.dart";

import "../models/user_model.dart";
import "../services/auth_storage.dart";
import "../services/profile_service.dart";

class ProfileController extends ChangeNotifier {
  ProfileController({ProfileService? profileService, AuthStorage? authStorage})
    : _profileService = profileService ?? ProfileService(),
      _authStorage = authStorage ?? AuthStorage();

  final ProfileService _profileService;
  final AuthStorage _authStorage;

  UserModel? _user;
  UserModel? get user => _user;

  UserModel? _original;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isChangingPassword = false;
  bool get isChangingPassword => _isChangingPassword;

  String? _error;
  String? get error => _error;

  String? _lastPasswordMessage;
  String? get lastPasswordMessage => _lastPasswordMessage;

  Future<void> loadUserProfile() async {
    if (_isLoading) return;
    _error = null;

    final String? cached = await _authStorage.readUserJson();
    if (cached != null && cached.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          _user = UserModel.fromJson(decoded);
          _original = _user;
          notifyListeners();
        }
      } catch (_) {}
    }

    _isLoading = true;
    notifyListeners();

    try {
      final UserModel fetched = await _profileService.getMe();
      _user = fetched;
      _original = fetched;
      _error = null;
    } on ProfileServiceException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String firstname,
    required String lastname,
    required String email,
    String? phone,
  }) async {
    if (_isSaving) return;

    final Map<String, dynamic> changes = <String, dynamic>{};
    final UserModel? base = _original ?? _user;

    void upsertCanonical(String canonicalKey, dynamic value) {
      changes[canonicalKey] = value;
    }

    final String newFirst = firstname.trim();
    final String oldFirst = (base?.firstName ?? base?.firstname ?? "").trim();
    if (newFirst != oldFirst) {
      upsertCanonical("firstName", newFirst);
    }

    final String newLast = lastname.trim();
    final String oldLast = (base?.lastName ?? base?.lastname ?? "").trim();
    if (newLast != oldLast) {
      upsertCanonical("lastName", newLast);
    }

    final String newEmail = email.trim();
    final String oldEmail = (base?.email ?? "").trim();
    if (newEmail != oldEmail) {
      upsertCanonical("email", newEmail);
    }

    final String? oldPhone = base?.phone == null ? null : base!.phone?.trim();
    final bool hadOldPhone = oldPhone != null && oldPhone.isNotEmpty;
    final bool inputIsNull = phone == null;
    final String inputTrimmed = (phone ?? "").trim();
    final bool inputIsEmpty = !inputIsNull && inputTrimmed.isEmpty;
    final bool hasNewValue = !inputIsNull && !inputIsEmpty;

    if (hadOldPhone && inputIsEmpty) {
      upsertCanonical("phone", null);
    } else if (hasNewValue && inputTrimmed != (oldPhone ?? "")) {
      upsertCanonical("phone", inputTrimmed);
    } else if (!hadOldPhone && hasNewValue) {
      upsertCanonical("phone", inputTrimmed);
    }

    if (changes.isEmpty) return;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final UserModel updated = await _profileService.updateMe(changes);
      _user = updated;
      _original = updated;
    } on ProfileServiceException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_isChangingPassword) return null;
    if (currentPassword.isEmpty) {
      throw const ProfileControllerException("Current password is required");
    }
    if (newPassword.length < 8) {
      throw const ProfileControllerException(
        "New password must be at least 8 characters long",
      );
    }

    _isChangingPassword = true;
    _lastPasswordMessage = null;
    notifyListeners();

    try {
      final String? msg = await _profileService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _lastPasswordMessage = msg;
      return msg;
    } on ProfileServiceException catch (e) {
      throw ProfileControllerException(e.message);
    } catch (e) {
      throw ProfileControllerException(e.toString());
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _profileService.logout();
    await _authStorage.clearSession();
    _user = null;
    _original = null;
  }

  Future<void> forgotPassword({required String email}) async {
    await _profileService.forgotPassword(email: email);
  }

  Future<void> resetPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      throw const ProfileControllerException("Passwords do not match");
    }
    await _profileService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> deleteAccount() async {
    await _profileService.deleteAccount();
    await _authStorage.clearSession();
    _user = null;
    _original = null;
  }
}

class ProfileControllerException implements Exception {
  const ProfileControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
