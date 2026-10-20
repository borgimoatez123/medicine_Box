import "dart:io";

import "../data/api_client.dart";
import "../data/repositories/patient_repository.dart";
import "../models/patient.dart";

class PatientService {
  PatientService({PatientRepository? repository, ApiClient? apiClient})
    : _repository = repository ?? PatientRepository(apiClient: apiClient);

  final PatientRepository _repository;

  Future<Patient> createPatient({
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    int? heightCm,
    String? bloodType,
    String? allergies,
    String? notes,
    String? avatarUrl,
  }) async {
    final String name = fullName.trim();
    if (name.isEmpty) {
      throw PatientServiceException("fullName is required");
    }
    if (weightKg != null && weightKg <= 0) {
      throw PatientServiceException("Value must be greater than 0");
    }
    if (heightCm != null && heightCm <= 0) {
      throw PatientServiceException("Value must be greater than 0");
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      if (!_isValidUrl(avatarUrl.trim())) {
        throw PatientServiceException("Invalid URL");
      }
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      "fullName": name,
      if (dateOfBirth != null) "dateOfBirth": dateOfBirth,
      if (gender != null && gender.trim().isNotEmpty) "gender": gender.trim(),
      if (weightKg != null) "weightKg": weightKg,
      if (heightCm != null) "heightCm": heightCm,
      if (bloodType != null && bloodType.trim().isNotEmpty)
        "bloodType": bloodType.trim(),
      if (allergies != null && allergies.trim().isNotEmpty)
        "allergies": allergies.trim(),
      if (notes != null && notes.trim().isNotEmpty) "notes": notes.trim(),
      "avatarUrl": avatarUrl == null || avatarUrl.trim().isEmpty
          ? null
          : avatarUrl.trim(),
    };
    try {
      return await _repository.createPatient(payload);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<PatientPageResult> listMyPatients({int page = 1, int? limit}) async {
    try {
      return await _repository.listMyPatients(page: page, limit: limit);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<Patient> getPatientById(String patientId) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientServiceException("Missing patient id");
    }
    try {
      return await _repository.getPatientById(id);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<Patient> updatePatient(
    String patientId, {
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    int? heightCm,
    String? bloodType,
    String? allergies,
    String? notes,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientServiceException("Missing patient id");
    }
    if (weightKg != null && weightKg <= 0) {
      throw PatientServiceException("Value must be greater than 0");
    }
    if (heightCm != null && heightCm <= 0) {
      throw PatientServiceException("Value must be greater than 0");
    }
    final String? avatar = clearAvatarUrl
        ? null
        : (avatarUrl == null
              ? null
              : (avatarUrl.trim().isEmpty ? null : avatarUrl.trim()));
    if (!clearAvatarUrl && avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      if (!_isValidUrl(avatarUrl.trim())) {
        throw PatientServiceException("Invalid URL");
      }
    }
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (fullName != null) patch["fullName"] = fullName.trim();
    if (dateOfBirth != null) patch["dateOfBirth"] = dateOfBirth;
    if (gender != null) patch["gender"] = gender.trim();
    if (weightKg != null) patch["weightKg"] = weightKg;
    if (heightCm != null) patch["heightCm"] = heightCm;
    if (bloodType != null) patch["bloodType"] = bloodType.trim();
    if (allergies != null) patch["allergies"] = allergies.trim();
    if (notes != null) patch["notes"] = notes.trim();
    if (clearAvatarUrl || avatarUrl != null) patch["avatarUrl"] = avatar;

    try {
      return await _repository.updatePatient(id, patch);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<void> deletePatient(String patientId) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientServiceException("Missing patient id");
    }
    try {
      await _repository.deletePatient(id);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<PatientAvatarResult> uploadPatientAvatar(
    String patientId,
    File imageFile,
  ) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientServiceException("Missing patient id");
    }
    try {
      return await _repository.uploadPatientAvatar(id, imageFile);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  Future<void> deletePatientAvatar(String patientId) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientServiceException("Missing patient id");
    }
    try {
      await _repository.deletePatientAvatar(id);
    } on PatientRepositoryException catch (e) {
      throw PatientServiceException(e.message);
    } catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  static bool _isValidUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      if (uri.scheme.isEmpty) return false;
      if (uri.host.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}

class PatientServiceException implements Exception {
  PatientServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
