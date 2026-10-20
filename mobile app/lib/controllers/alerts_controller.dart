import "package:flutter/foundation.dart";

import "../data/repositories/medication_repository.dart";
import "../models/medication_event_model.dart";
import "../models/medication_model.dart";
import "../models/patient.dart";
import "../services/medication_event_service.dart";
import "../services/patient_service.dart";

/// Controller for the Alerts screen.
///
/// Responsibilities:
/// - Fetch medication events from `GET /devices/medication-events`,
///   (backend JWT already scopes the authenticated user's patients.
/// - Resolve medication names from existing medication data (fallback "Medication").
/// - Provide loading/error/empty state.
/// - Deduplicate events by id across refreshes.
class AlertsController extends ChangeNotifier {
  AlertsController({
    MedicationEventService? eventService,
    PatientService? patientService,
    MedicationRepository? medicationRepository,
  }) : _eventService = eventService ?? MedicationEventService(),
       _patientService = patientService ?? PatientService(),
       _medicationRepo = medicationRepository ?? MedicationRepository();

  final MedicationEventService _eventService;
  final PatientService _patientService;
  final MedicationRepository _medicationRepo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _error;
  String? get error => _error;

  List<MedicationEventModel> _events = <MedicationEventModel>[];
  List<MedicationEventModel> get events =>
      List<MedicationEventModel>.unmodifiable(_events);

  MedicationEventPagination? _pagination;
  MedicationEventPagination? get pagination => _pagination;
  int? get totalCount => _pagination?.total;
  int get currentOffset => _pagination?.offset ?? 0;

  /// Cache of medication id -> name, resolved from existing medication data.
  final Map<String, String> _medicationNames = <String, String>{};
  String medicationName(String? medicationId) {
    final String id = medicationId?.trim() ?? "";
    if (id.isEmpty) return "Medication";
    return _medicationNames[id] ?? "Medication";
  }

  bool get isEmpty => _events.isEmpty && !_isLoading && _error == null;

  /// Returns the events sorted newest-first (chronological descending).
  List<MedicationEventModel> get sortedEvents {
    final List<MedicationEventModel> list = List<MedicationEventModel>.of(_events);
    list.sort((MedicationEventModel a, MedicationEventModel b) {
      return b.sortDateTime.compareTo(a.sortDateTime);
    });
    return list;
  }

  /// Loads medication events for the authenticated user's patients.
  ///
  /// When [patientId] is provided it is passed to the backend; otherwise the
  /// backend JWT scopes the result. We never substitute the user id here.
  Future<void> loadEvents({
    String? patientId,
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
    if (_isLoading && !append) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Resolve the patient(s) owned by the authenticated user so we can:
      //  - pass a patientId when the backend supports filtering, and
      //  - build a medication name map for display.
      final List<String> patientIds = await _resolvePatientIds(patientId);
      await _populateMedicationNames(patientIds);

      final MedicationEventListResult result = await _eventService
          .loadMedicationEvents(
        patientId: patientIds.length == 1 ? patientIds.first : patientId,
        limit: limit,
        offset: offset,
      );

      _mergeEvents(result.events);
      _pagination = result.pagination;
      notifyListeners();
    } on MedicationEventServiceException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = "Unable to load medication events. Please try again.";
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh entry point.
  Future<void> refresh({String? patientId}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      await loadEvents(patientId: patientId, append: false);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<List<String>> _resolvePatientIds(String? preferred) async {
    final List<String> out = <String>[];
    final String? pref = preferred?.trim();
    if (pref != null && pref.isNotEmpty) {
      out.add(pref);
      return out;
    }
    try {
      final PatientPageResult r = await _patientService.listMyPatients(limit: 500);
      for (final Patient p in r.items) {
        final String id = p.id.trim();
        if (id.isNotEmpty) out.add(id);
      }
    } catch (_) {
      // If we can't list patients, leave the list empty and rely on the backend
      // JWT to scope the events response.
    }
    return out;
  }

  Future<void> _populateMedicationNames(List<String> patientIds) async {
    final Set<String> needed = <String>{};
    for (final MedicationEventModel e in _events) {
      final String mid = e.medicationId?.trim() ?? "";
      if (mid.isNotEmpty && !_medicationNames.containsKey(mid)) {
        needed.add(mid);
      }
    }
    if (needed.isEmpty) return;

    // Try bulk resolution via per-patient medication lists (one request each).
    for (final String pid in patientIds) {
      try {
        final List<MedicationModel> meds =
            await _medicationRepo.getMedicationsByPatient(pid);
        for (final MedicationModel m in meds) {
          final String id = m.id.trim();
          final String name = m.name.trim();
          if (id.isNotEmpty && name.isNotEmpty) {
            _medicationNames[id] = name;
            needed.remove(id);
          }
        }
      } catch (_) {
        // continue with other patients
      }
      if (needed.isEmpty) break;
    }

    // Fallback: resolve any still-unknown medication ids individually.
    for (final String mid in List<String>.of(needed)) {
      try {
        final MedicationModel m = await _medicationRepo.getMedicationById(mid);
        final String name = m.name.trim();
        if (name.isNotEmpty) {
          _medicationNames[mid] = name;
        }
      } catch (_) {
        // leave unresolved; UI will show "Medication" fallback.
      }
    }
  }

  void _mergeEvents(List<MedicationEventModel> incoming) {
    final Map<String, MedicationEventModel> byId = <String, MedicationEventModel>{};
    for (final MedicationEventModel e in _events) {
      if (e.id.isNotEmpty) byId[e.id] = e;
    }
    for (final MedicationEventModel e in incoming) {
      if (e.id.isNotEmpty) byId[e.id] = e;
    }
    _events = byId.values.toList();
  }
}
