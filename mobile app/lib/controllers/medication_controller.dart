import "package:flutter/foundation.dart";

import "../models/medication_model.dart";
import "../services/medication_service.dart";
import "notification_controller.dart";

class MedicationController extends ChangeNotifier {
  MedicationController({MedicationService? service})
    : _service = service ?? MedicationService();

  final MedicationService _service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  List<MedicationModel> _medications = <MedicationModel>[];
  List<MedicationModel> get medications =>
      List<MedicationModel>.unmodifiable(_medications);

  MedicationPaginationMeta? _meta;
  MedicationPaginationMeta? get meta => _meta;

  int? get totalCount => _meta?.total;
  int? get totalPages => _meta?.totalPages;
  int get currentPage => _meta?.page ?? 1;
  int? get currentLimit => _meta?.limit;

  String? _error;
  String? get error => _error;

  MedicationModel? findById(String id) {
    final String key = id.trim();
    if (key.isEmpty) return null;
    for (final MedicationModel m in _medications) {
      if (m.id.trim() == key) return m;
    }
    return null;
  }

  Future<void> loadMedications({
    String? patientId,
    int page = 1,
    int? limit,
    bool append = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final MedicationPageResult result = await _service.listMyMedications(
        patientId: patientId,
        page: page,
        limit: limit,
      );
      if (append && page > 1) {
        final Set<String> existingIds = _medications
            .map((MedicationModel m) => m.id)
            .where((String s) => s.isNotEmpty)
            .toSet();
        final List<MedicationModel> unique = <MedicationModel>[
          ..._medications,
          ...result.items.where(
            (MedicationModel m) =>
                m.id.isNotEmpty && !existingIds.contains(m.id),
          ),
        ];
        _medications = unique;
      } else {
        _medications = List<MedicationModel>.of(result.items);
      }
      _meta = result.meta;
      notifyListeners();
    } on MedicationServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw MedicationControllerException(e.message);
    } catch (e) {
      _error = "Unable to load medications.";
      notifyListeners();
      throw MedicationControllerException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage({String? patientId, int? limit}) async {
    final int next = currentPage + 1;
    final int? tp = totalPages;
    if (tp != null && next > tp) return;
    return loadMedications(
      patientId: patientId,
      page: next,
      limit: limit,
      append: true,
    );
  }

  Future<void> refresh({String? patientId, int limit = 20}) {
    return loadMedications(patientId: patientId, page: 1, limit: limit);
  }

  Future<MedicationModel> getMedication(String medicationId) async {
    try {
      final MedicationModel fresh = await _service.getMedicationById(
        medicationId,
      );
      final int index = _medications.indexWhere(
        (MedicationModel m) => m.id.trim() == fresh.id.trim(),
      );
      if (index >= 0) {
        _medications[index] = fresh;
        notifyListeners();
      }
      return fresh;
    } on MedicationServiceException catch (e) {
      throw MedicationControllerException(e.message);
    } catch (e) {
      throw MedicationControllerException(e.toString());
    }
  }

  Future<MedicationModel> createMedication({
    required String patientId,
    required String name,
    required String dosage,
    MedicationForm form = MedicationForm.tablet,
    required int quantity,
    DateTime? expiryDate,
  }) async {
    if (_isCreating) {
      throw MedicationControllerException(
        "Another medication is being created.",
      );
    }
    _isCreating = true;
    _error = null;
    notifyListeners();
    try {
      final MedicationModel created = await _service.createMedication(
        patientId: patientId,
        name: name,
        dosage: dosage,
        form: form,
        quantity: quantity,
        expiryDate: expiryDate,
      );
      final Set<String> ids = _medications
          .map((MedicationModel m) => m.id)
          .where((String s) => s.isNotEmpty)
          .toSet();
      if (created.id.isNotEmpty && !ids.contains(created.id)) {
        _medications = <MedicationModel>[created, ..._medications];
      }
      notifyListeners();
      await NotificationController.instance.onMedicationCreated(created);
      return created;
    } on MedicationServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw MedicationControllerException(e.message);
    } catch (e) {
      _error = "Unable to create medication.";
      notifyListeners();
      throw MedicationControllerException(_error!);
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<MedicationModel> updateMedication(
    MedicationModel medication, {
    String? name,
    String? dosage,
    MedicationForm? form,
    int? quantity,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) async {
    if (_isUpdating) {
      throw MedicationControllerException(
        "Another medication is being updated.",
      );
    }
    _isUpdating = true;
    _error = null;
    notifyListeners();
    final MedicationModel snapshot = medication;
    final int index = _medications.indexWhere(
      (MedicationModel m) => m.id.trim() == snapshot.id.trim(),
    );
    try {
      final MedicationModel updated = await _service.updateMedication(
        snapshot.id,
        name: name,
        dosage: dosage,
        form: form,
        quantity: quantity,
        expiryDate: expiryDate,
        clearExpiryDate: clearExpiryDate,
      );
      if (index >= 0) {
        _medications[index] = updated;
      }
      notifyListeners();
      await NotificationController.instance.onMedicationUpdated(updated);
      return updated;
    } on MedicationServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw MedicationControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _medications[index] = snapshot;
        notifyListeners();
      }
      _error = "Unable to update medication.";
      notifyListeners();
      throw MedicationControllerException(_error!);
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> deleteMedication(MedicationModel medication) async {
    if (_isDeleting) {
      throw MedicationControllerException(
        "Another medication is being deleted.",
      );
    }
    _isDeleting = true;
    _error = null;
    notifyListeners();
    final List<MedicationModel> snapshot = List<MedicationModel>.of(
      _medications,
    );
    final String targetId = medication.id.trim();
    _medications = _medications
        .where((MedicationModel m) => m.id.trim() != targetId)
        .toList(growable: false);
    notifyListeners();
    try {
      await _service.deleteMedication(medication.id);
      await NotificationController.instance.onMedicationDeleted(medication.id);
      notifyListeners();
    } on MedicationServiceException catch (e) {
      _medications = snapshot;
      _error = e.message;
      notifyListeners();
      throw MedicationControllerException(e.message);
    } catch (e) {
      _medications = snapshot;
      _error = "Unable to delete medication.";
      notifyListeners();
      throw MedicationControllerException(_error!);
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }
}

class MedicationControllerException implements Exception {
  MedicationControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
