import "../data/api_client.dart";
import "../data/repositories/profile_repository.dart";
import "../models/user_model.dart";

class ProfileService {
  ProfileService({ProfileRepository? repository})
    : _repository = repository ?? ProfileRepository();

  final ProfileRepository _repository;

  Future<UserModel> getProfile() async {
    try {
      return await _repository.getProfile();
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<UserModel> getMe() async {
    try {
      return await _repository.getMe();
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<UserModel> getUserProfile(String userId) async {
    try {
      return await _repository.getUserProfile(userId);
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> changes) async {
    try {
      return await _repository.updateProfile(changes);
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<UserModel> updateMe(Map<String, dynamic> changes) async {
    try {
      return await _repository.updateMe(changes);
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<UserModel> updateUserProfile(
    String userId,
    Map<String, dynamic> changes,
  ) async {
    try {
      return await _repository.updateUserProfile(userId, changes);
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      return await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {}
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      await _repository.forgotPassword(email: email);
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<void> resetPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _repository.resetPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } on ProfileRepositoryException catch (e) {
      throw ProfileServiceException(e.message);
    } on ApiClientException catch (e) {
      throw ProfileServiceException(e.message);
    } catch (e) {
      throw ProfileServiceException(e.toString());
    }
  }
}

class ProfileServiceException implements Exception {
  ProfileServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
