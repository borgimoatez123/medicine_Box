import "dart:io";

import "package:flutter/foundation.dart";

import "../data/repositories/patient_repository.dart";
import "../models/patient.dart";
import "../services/patient_service.dart";

class PatientController extends ChangeNotifier {
  PatientController({PatientService? patientService})
    : _patientService = patientService ?? PatientService();

  final PatientService _patientService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  bool _isUploadingAvatar = false;
  bool get isUploadingAvatar => _isUploadingAvatar;

  bool _isDeletingAvatar = false;
  bool get isDeletingAvatar => _isDeletingAvatar;

  final Set<String> _uploadingAvatarIds = <String>{};
  bool isUploadingAvatarFor(String patientId) =>
      _uploadingAvatarIds.contains(patientId.trim());

  final Set<String> _deletingAvatarIds = <String>{};
  bool isDeletingAvatarFor(String patientId) =>
      _deletingAvatarIds.contains(patientId.trim());

  List<Patient> _patients = <Patient>[];
  List<Patient> get patients => List<Patient>.unmodifiable(_patients);

  PatientPaginationMeta? _meta;
  PatientPaginationMeta? get meta => _meta;

  int? get totalCount => _meta?.total;
  int? get totalPages => _meta?.totalPages;
  int get currentPage => _meta?.page ?? 1;
  int? get currentLimit => _meta?.limit;

  String? _error;
  String? get error => _error;

  Future<void> loadPatients({
    int page = 1,
    int? limit,
    bool append = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final PatientPageResult result = await _patientService.listMyPatients(
        page: page,
        limit: limit,
      );
      if (append && page > 1) {
        final Set<String> existingIds = _patients
            .map((Patient p) => p.id)
            .where((String s) => s.isNotEmpty)
            .toSet();
        final List<Patient> unique = <Patient>[
          ..._patients,
          ...result.items.where(
            (Patient p) => p.id.isNotEmpty && !existingIds.contains(p.id),
          ),
        ];
        _patients = unique;
      } else {
        _patients = List<Patient>.of(result.items);
      }
      _meta = result.meta;
      notifyListeners();
    } on PatientServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      _error = "Unable to load patients.";
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage({int? limit}) async {
    final int next = currentPage + 1;
    final int? tp = totalPages;
    if (tp != null && next > tp) return;
    return loadPatients(page: next, limit: limit, append: true);
  }

  Patient? findById(String patientId) {
    final String id = patientId.trim();
    if (id.isEmpty) return null;
    for (final Patient p in _patients) {
      if (p.id.trim() == id) return p;
    }
    return null;
  }

  void upsertPatientIfAbsent(Patient patient) {
    final String id = patient.id.trim();
    if (id.isEmpty) return;
    final int existing = _patients.indexWhere((Patient p) => p.id.trim() == id);
    if (existing >= 0) return;
    _patients.insert(0, patient);
    notifyListeners();
  }

  void upsertPatient(Patient patient) {
    final String id = patient.id.trim();
    if (id.isEmpty) return;
    final int existing = _patients.indexWhere((Patient p) => p.id.trim() == id);
    if (existing >= 0) {
      _patients[existing] = patient;
    } else {
      _patients.insert(0, patient);
    }
    notifyListeners();
  }

  Future<void> refresh({int? limit}) =>
      loadPatients(page: 1, limit: limit, append: false);

  Future<Patient> createPatient({
    required String firstName,
    required String lastName,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    int? heightCm,
    String? bloodType,
    String? allergies,
    String? notes,
    String? avatarUrl,
  }) async {
    if (_isCreating) {
      throw PatientControllerException("Already creating patient");
    }
    final String name = (fullName?.trim().isNotEmpty == true)
        ? fullName!.trim()
        : <String>[
            firstName.trim(),
            lastName.trim(),
          ].where((String s) => s.isNotEmpty).join(" ").trim();
    if (name.isEmpty) {
      throw PatientControllerException("Patient name is required");
    }
    _isCreating = true;
    _error = null;
    notifyListeners();
    try {
      final Patient created = await _patientService.createPatient(
        fullName: name,
        dateOfBirth: dateOfBirth,
        gender: gender,
        weightKg: weightKg,
        heightCm: heightCm,
        bloodType: bloodType,
        allergies: allergies,
        notes: notes,
        avatarUrl: avatarUrl,
      );
      final Set<String> ids = _patients
          .map((Patient p) => p.id)
          .where((String s) => s.isNotEmpty)
          .toSet();
      if (created.id.isNotEmpty && !ids.contains(created.id)) {
        _patients.insert(0, created);
      }
      notifyListeners();
      return created;
    } on PatientServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<Patient?> getById(String patientId) async {
    final String id = patientId.trim();
    if (id.isEmpty) return null;
    final int existing = _patients.indexWhere((Patient p) => p.id.trim() == id);
    try {
      final Patient fresh = await _patientService.getPatientById(id);
      if (existing >= 0) {
        _patients[existing] = fresh;
      } else {
        _patients.insert(0, fresh);
      }
      notifyListeners();
      return fresh;
    } on PatientServiceException catch (e) {
      throw PatientControllerException(e.message);
    } catch (e) {
      throw PatientControllerException(e.toString());
    }
  }

  Future<void> deletePatient(Patient patient) async {
    if (_isDeleting) return;
    final String pId = patient.id.trim();
    if (pId.isEmpty) {
      throw PatientControllerException("Missing patient id");
    }
    final int originalIndex = _patients.indexWhere(
      (Patient p) => p.id.trim() == pId,
    );
    final Patient? originalPatient = originalIndex >= 0
        ? _patients[originalIndex]
        : null;

    _isDeleting = true;
    _error = null;
    if (originalPatient != null) {
      _patients.removeAt(originalIndex);
    }
    notifyListeners();

    try {
      await _patientService.deletePatient(pId);
    } on PatientServiceException catch (e) {
      if (originalPatient != null) {
        _patients.insert(originalIndex, originalPatient);
      }
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      if (originalPatient != null) {
        _patients.insert(originalIndex, originalPatient);
      }
      _error = e.toString();
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  Future<Patient> updatePatient({
    required Patient original,
    String? firstName,
    String? lastName,
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
    if (_isUpdating) {
      throw PatientControllerException("Already updating patient");
    }
    final String pId = original.id.trim();
    if (pId.isEmpty) {
      throw PatientControllerException("Missing patient id");
    }
    String? resolvedFullName;
    if (fullName != null) {
      resolvedFullName = fullName.trim().isEmpty ? null : fullName.trim();
    } else if (firstName != null || lastName != null) {
      final String fn =
          (firstName != null ? firstName.trim() : original.firstname).trim();
      final String ln = (lastName != null ? lastName.trim() : original.lastname)
          .trim();
      final String combined = <String>[
        fn,
        ln,
      ].where((String s) => s.isNotEmpty).join(" ").trim();
      resolvedFullName = combined.isEmpty ? null : combined;
    }

    _isUpdating = true;
    _error = null;
    notifyListeners();

    final int originalIndex = _patients.indexWhere(
      (Patient p) => p.id.trim() == pId,
    );
    final Patient? snapshot = originalIndex >= 0
        ? _patients[originalIndex]
        : null;

    try {
      final Patient updated = await _patientService.updatePatient(
        pId,
        fullName: resolvedFullName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        weightKg: weightKg,
        heightCm: heightCm,
        bloodType: bloodType,
        allergies: allergies,
        notes: notes,
        avatarUrl: avatarUrl,
        clearAvatarUrl: clearAvatarUrl,
      );
      if (originalIndex >= 0) {
        _patients[originalIndex] = updated;
      } else {
        _patients.insert(0, updated);
      }
      notifyListeners();
      return updated;
    } on PatientServiceException catch (e) {
      if (snapshot != null && originalIndex >= 0) {
        _patients[originalIndex] = snapshot;
      }
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      if (snapshot != null && originalIndex >= 0) {
        _patients[originalIndex] = snapshot;
      }
      _error = e.toString();
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<PatientAvatarResult> uploadPatientAvatar(
    String patientId,
    File imageFile,
  ) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientControllerException("Missing patient id");
    }
    if (_uploadingAvatarIds.contains(id)) {
      throw PatientControllerException("Avatar upload already in progress");
    }
    final int existingIndex = _patients.indexWhere(
      (Patient p) => p.id.trim() == id,
    );
    final Patient? snapshot = existingIndex >= 0
        ? _patients[existingIndex]
        : null;
    _uploadingAvatarIds.add(id);
    _isUploadingAvatar = true;
    _error = null;
    notifyListeners();
    try {
      final PatientAvatarResult result = await _patientService
          .uploadPatientAvatar(id, imageFile);
      final String? url = result.avatarUrl;
      if (url == null || url.trim().isEmpty) {
        throw PatientControllerException(
          "Unable to read avatar URL from server response",
        );
      }
      final Patient merged =
          result.patient ??
          (snapshot ?? Patient(id: id, fullName: "", avatarUrl: url.trim()));
      final Patient withAvatar = merged.copyWith(avatarUrl: url.trim());
      if (existingIndex >= 0) {
        _patients[existingIndex] = withAvatar;
      } else {
        _patients.insert(0, withAvatar);
      }
      notifyListeners();
      return PatientAvatarResult(avatarUrl: url.trim(), patient: withAvatar);
    } on PatientServiceException catch (e) {
      if (snapshot != null && existingIndex >= 0) {
        _patients[existingIndex] = snapshot;
      }
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      if (snapshot != null && existingIndex >= 0) {
        _patients[existingIndex] = snapshot;
      }
      _error = e.toString();
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _uploadingAvatarIds.remove(id);
      _isUploadingAvatar = _uploadingAvatarIds.isNotEmpty;
      notifyListeners();
    }
  }

  Future<void> deletePatientAvatar(String patientId) async {
    final String id = patientId.trim();
    if (id.isEmpty) {
      throw PatientControllerException("Missing patient id");
    }
    if (_deletingAvatarIds.contains(id)) {
      throw PatientControllerException("Avatar delete already in progress");
    }
    final int existingIndex = _patients.indexWhere(
      (Patient p) => p.id.trim() == id,
    );
    final Patient? snapshot = existingIndex >= 0
        ? _patients[existingIndex]
        : null;
    final String? previousUrl = snapshot?.avatarUrl;
    _deletingAvatarIds.add(id);
    _isDeletingAvatar = true;
    _error = null;
    if (snapshot != null && existingIndex >= 0) {
      _patients[existingIndex] = snapshot.copyWith(avatarUrl: null);
    }
    notifyListeners();
    try {
      await _patientService.deletePatientAvatar(id);
    } on PatientServiceException catch (e) {
      if (snapshot != null && existingIndex >= 0) {
        _patients[existingIndex] = snapshot.copyWith(avatarUrl: previousUrl);
      }
      _error = e.message;
      notifyListeners();
      throw PatientControllerException(e.message);
    } catch (e) {
      if (snapshot != null && existingIndex >= 0) {
        _patients[existingIndex] = snapshot.copyWith(avatarUrl: previousUrl);
      }
      _error = e.toString();
      notifyListeners();
      throw PatientControllerException(_error!);
    } finally {
      _deletingAvatarIds.remove(id);
      _isDeletingAvatar = _deletingAvatarIds.isNotEmpty;
      notifyListeners();
    }
  }
}

class PatientControllerException implements Exception {
  PatientControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
