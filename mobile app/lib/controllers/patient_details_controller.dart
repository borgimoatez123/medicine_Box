import "package:flutter/foundation.dart";

import "../data/repositories/alert_repository.dart";
import "../data/repositories/medication_repository.dart";
import "../data/repositories/patient_repository.dart";
import "../models/alert_model.dart";
import "../models/medication_model.dart";
import "../models/patient.dart";
import "../services/medication_service.dart";

class PatientDetailsController extends ChangeNotifier {
  PatientDetailsController({
    Patient? initialPatient,
    String? patientId,
    PatientRepository? patientRepository,
    MedicationRepository? medicationRepository,
    AlertRepository? alertRepository,
    MedicationService? medicationService,
  }) : _patient = initialPatient,
       _passedPatientId = patientId?.trim(),
       _patientRepo = patientRepository ?? PatientRepository(),
       _medicationRepo = medicationRepository ?? MedicationRepository(),
       _alertRepo = alertRepository ?? AlertRepository(),
       _medicationService =
           medicationService ??
           MedicationService(
             repository: medicationRepository ?? MedicationRepository(),
           );

  final PatientRepository _patientRepo;
  final MedicationRepository _medicationRepo;
  final AlertRepository _alertRepo;
  final MedicationService _medicationService;
  final String? _passedPatientId;

  Patient? _patient;
  bool _patientLoading = false;
  String? _patientError;

  List<MedicationModel> _medications = const <MedicationModel>[];
  bool _medicationsLoading = false;
  String? _medicationsError;

  List<AlertModel> _alerts = const <AlertModel>[];
  bool _alertsLoading = false;
  String? _alertsError;

  int _tab = 0;
  bool _isMedicationUpdating = false;
  bool _isMedicationDeleting = false;
  String? _medicationActionError;

  Patient? get patient => _patient;
  bool get patientLoading => _patientLoading;
  String? get patientError => _patientError;

  List<MedicationModel> get medications => _medications;
  bool get medicationsLoading => _medicationsLoading;
  String? get medicationsError => _medicationsError;

  List<AlertModel> get alerts => _alerts;
  bool get alertsLoading => _alertsLoading;
  String? get alertsError => _alertsError;

  int get currentTab => _tab;
  bool get isMedicationUpdating => _isMedicationUpdating;
  bool get isMedicationDeleting => _isMedicationDeleting;
  String? get medicationActionError => _medicationActionError;

  Future<String> _resolvePatientId() async {
    final String? fromArg = _passedPatientId?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    final String? fromPatient = _patient?.id.trim();
    if (fromPatient != null && fromPatient.isNotEmpty) return fromPatient;
    throw PatientDetailsControllerException("Missing patient id");
  }

  void setTab(int index) {
    if (index < 0 || index == _tab) return;
    _tab = index;
    notifyListeners();
  }

  Future<void> loadAll({bool forceRefresh = false}) async {
    await loadPatient(forceRefresh: forceRefresh);
    if (_patient != null) {
      await Future.wait(<Future<void>>[loadMedications(), loadAlerts()]);
    }
  }

  Future<void> loadPatient({bool forceRefresh = false}) async {
    if (_patientLoading) return;
    if (!forceRefresh &&
        _patient != null &&
        _patient!.id.trim().isNotEmpty &&
        _patientError == null) {
      return;
    }
    _patientLoading = true;
    _patientError = null;
    notifyListeners();
    try {
      final String patientId = await _resolvePatientId();
      final Patient fetched = await _patientRepo.getPatientById(patientId);
      _patient = fetched;
    } catch (e) {
      _patientError = _friendly(e);
    } finally {
      _patientLoading = false;
      notifyListeners();
    }
  }

  void setPatient(Patient updated) {
    final String? existingId = _patient?.id.trim();
    final String newId = updated.id.trim();
    final bool matches =
        existingId != null && existingId.isNotEmpty && newId.isNotEmpty
        ? existingId == newId
        : identical(_patient, updated) || _patient == null;
    if (matches) {
      _patient = updated;
      _patientError = null;
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
    if (_isMedicationUpdating) {
      throw PatientDetailsControllerException(
        "Another medication is being updated.",
      );
    }
    _isMedicationUpdating = true;
    _medicationActionError = null;
    notifyListeners();
    final MedicationModel snapshot = medication;
    final int index = _medications.indexWhere(
      (MedicationModel m) => m.id.trim() == snapshot.id.trim(),
    );
    try {
      final MedicationModel updated = await _medicationService.updateMedication(
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
      return updated;
    } on MedicationServiceException catch (e) {
      _medicationActionError = e.message;
      notifyListeners();
      throw PatientDetailsControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _medications[index] = snapshot;
        notifyListeners();
      }
      _medicationActionError = "Unable to update medication.";
      notifyListeners();
      throw PatientDetailsControllerException(_medicationActionError!);
    } finally {
      _isMedicationUpdating = false;
      notifyListeners();
    }
  }

  Future<void> deleteMedication(MedicationModel medication) async {
    if (_isMedicationDeleting) {
      throw PatientDetailsControllerException(
        "Another medication is being deleted.",
      );
    }
    _isMedicationDeleting = true;
    _medicationActionError = null;
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
      await _medicationService.deleteMedication(medication.id);
      notifyListeners();
    } on MedicationServiceException catch (e) {
      _medications = snapshot;
      _medicationActionError = e.message;
      notifyListeners();
      throw PatientDetailsControllerException(e.message);
    } catch (e) {
      _medications = snapshot;
      _medicationActionError = "Unable to delete medication.";
      notifyListeners();
      throw PatientDetailsControllerException(_medicationActionError!);
    } finally {
      _isMedicationDeleting = false;
      notifyListeners();
    }
  }

  Future<void> loadMedications() async {
    if (_medicationsLoading) return;
    final Patient? p = _patient;
    if (p == null || p.id.trim().isEmpty) {
      _medications = const <MedicationModel>[];
      _medicationsError = null;
      notifyListeners();
      return;
    }
    _medicationsLoading = true;
    _medicationsError = null;
    notifyListeners();
    try {
      _medications = await _medicationRepo.getMedicationsByPatient(p.id.trim());
    } catch (e) {
      _medicationsError = _friendly(e);
    } finally {
      _medicationsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAlerts() async {
    if (_alertsLoading) return;
    final Patient? p = _patient;
    if (p == null || p.id.trim().isEmpty) {
      _alerts = const <AlertModel>[];
      _alertsError = null;
      notifyListeners();
      return;
    }
    _alertsLoading = true;
    _alertsError = null;
    notifyListeners();
    try {
      _alerts = await _alertRepo.getAlertsByPatient(p.id.trim());
    } catch (e) {
      _alertsError = _friendly(e);
    } finally {
      _alertsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    // Force a fresh patient load, then cascade to medications and alerts.
    _medications = const <MedicationModel>[];
    _alerts = const <AlertModel>[];
    _medicationsError = null;
    _alertsError = null;
    notifyListeners();
    await loadAll(forceRefresh: true);
  }

  static String _friendly(Object e) {
    if (e is PatientRepositoryException) return e.message;
    if (e is MedicationRepositoryException) return e.message;
    if (e is AlertRepositoryException) return e.message;
    if (e is PatientDetailsControllerException) return e.message;
    final String s = e.toString();
    if (s.trim().isEmpty) return "Unable to load data.";
    return s;
  }
}

class PatientDetailsControllerException implements Exception {
  PatientDetailsControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
