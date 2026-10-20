import "dart:async";

import "package:flutter/material.dart";

import "../data/repositories/medication_repository.dart";
import "../data/repositories/patient_repository.dart";
import "../data/repositories/schedule_repository.dart";
import "../models/medication_model.dart";
import "../models/patient.dart";
import "../models/schedule_model.dart";
import "../services/notification_service.dart";

class NotificationRouteArgs {
  const NotificationRouteArgs({
    this.medicationId,
    this.scheduleId,
    this.patientId,
  });

  final String? medicationId;
  final String? scheduleId;
  final String? patientId;
}

class NotificationController extends ChangeNotifier {
  NotificationController._internal();
  static final NotificationController instance =
      NotificationController._internal();

  static const String kRouteMedicationSchedule =
      "/notification/medication-schedule";
  static const int kSyncPageSize = 200;

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _inited = false;
  bool _lastEnabledState = true;

  bool _permissionsLoading = false;
  bool get permissionsLoading => _permissionsLoading;

  bool? _enabledSnapshot;
  bool? get enabledSnapshot => _enabledSnapshot;

  final NotificationService _svc = NotificationService.instance;
  final ScheduleRepository _scheduleRepo = ScheduleRepository();
  final MedicationRepository _medicationRepo = MedicationRepository();
  final PatientRepository _patientRepo = PatientRepository();

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (_inited) return;
    _navigatorKey = navigatorKey;
    try {
      await _svc.initialize(onTap: _onTap);
      await _refreshEnabledState();
    } catch (e, st) {
      debugPrint("[NotificationController] init failed: $e\n$st");
    }
    _inited = true;
    unawaited(_processLaunchPayload());
  }

  Future<void> requestPermissions({bool ifNotPromptedOnly = true}) async {
    try {
      if (ifNotPromptedOnly && !(await _svc.shouldPromptForPermission())) {
        return;
      }
      _permissionsLoading = true;
      notifyListeners();
      await _svc.ensurePermissions();
      await _svc.markPermissionPromptShown();
      await _refreshEnabledState();
    } finally {
      _permissionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    try {
      await _refreshEnabledState();
    } finally {
      notifyListeners();
    }
  }

  Future<void> cancelAll() => _svc.cancelAll();

  Future<void> cancelMedication(String medicationId) =>
      _svc.cancelMedication(medicationId);

  Future<void> cancelSchedule(String scheduleId) =>
      _svc.cancelSchedule(scheduleId);

  Future<void> scheduleMedicationFromIds({required String medicationId}) async {
    final List<ScheduleModel> schedules = await _safeSchedules(
      () => _scheduleRepo.getSchedulesByMedication(medicationId),
      <ScheduleModel>[],
    );
    final MedicationModel? med = await _safeMedication(medicationId);
    final Patient? patient = med == null
        ? null
        : await _safePatient(med.patientId);
    final List<ScheduleMedicationContext> contexts = schedules
        .map(
          (ScheduleModel s) => ScheduleMedicationContext(
            schedule: s,
            medication: med,
            patientFirstName: patient?.firstname,
            patientLastName: patient?.lastname,
          ),
        )
        .toList(growable: false);
    await _svc.scheduleAll(contexts, cancelStaleIdsNotInList: false);
  }

  Future<void> scheduleFromScheduleId({
    required String scheduleId,
    MedicationModel? medicationOverride,
  }) async {
    final ScheduleModel? s = await _safeSchedule(scheduleId);
    if (s == null) return;
    final MedicationModel? med =
        medicationOverride ?? await _safeMedication(s.medicationId);
    final Patient? patient = med == null
        ? null
        : await _safePatient(med.patientId);
    await _svc.scheduleForContext(
      ScheduleMedicationContext(
        schedule: s,
        medication: med,
        patientFirstName: patient?.firstname,
        patientLastName: patient?.lastname,
      ),
    );
  }

  Future<void> rescheduleAllActive() async {
    final List<ScheduleMedicationContext> contexts =
        await _collectAllActiveContexts();
    await _svc.scheduleAll(contexts, cancelStaleIdsNotInList: true);
  }

  // ---- Controller integration hooks called from CRUD controllers ----

  Future<void> onScheduleCreated(ScheduleModel s) =>
      scheduleFromScheduleId(scheduleId: s.id);

  Future<void> onScheduleUpdated(ScheduleModel s) =>
      scheduleFromScheduleId(scheduleId: s.id);

  Future<void> onScheduleDeleted(String scheduleId) =>
      cancelSchedule(scheduleId);

  Future<void> onMedicationCreated(MedicationModel m) =>
      scheduleMedicationFromIds(medicationId: m.id);

  Future<void> onMedicationUpdated(MedicationModel m) =>
      scheduleMedicationFromIds(medicationId: m.id);

  Future<void> onMedicationDeleted(String medicationId) =>
      cancelMedication(medicationId);

  Future<void> onMedicationActiveStateChanged({
    required String medicationId,
    required bool isActive,
  }) async {
    if (isActive) {
      return scheduleMedicationFromIds(medicationId: medicationId);
    }
    return cancelMedication(medicationId);
  }

  // ---- Private ----

  Future<void> _refreshEnabledState() async {
    final bool enabled = await _svc.areNotificationsEnabled();
    _enabledSnapshot = enabled;
    if (enabled != _lastEnabledState) {
      _lastEnabledState = enabled;
      notifyListeners();
    }
  }

  Future<void> _processLaunchPayload() async {
    try {
      final Map<String, dynamic>? payload = await _svc.getAppLaunchPayload();
      if (payload == null) return;
      _navigateFromPayload(payload);
    } catch (_) {}
  }

  void _onTap({
    required String type,
    String? medicationId,
    String? scheduleId,
    String? patientId,
  }) {
    _navigateFromPayload(<String, dynamic>{
      "type": type,
      "medicationId": medicationId,
      "scheduleId": scheduleId,
      "patientId": patientId,
    });
  }

  void _navigateFromPayload(Map<String, dynamic> payload) {
    if (payload["type"] != "medication_reminder") return;
    final String? medicationId = payload["medicationId"]?.toString();
    final String? scheduleId = payload["scheduleId"]?.toString();
    final String? patientId = payload["patientId"]?.toString();
    final GlobalKey<NavigatorState>? nav = _navigatorKey;
    if (nav == null) return;
    final NavigatorState? navigator = nav.currentState;
    if (navigator == null) return;
    navigator.pushNamed(
      kRouteMedicationSchedule,
      arguments: NotificationRouteArgs(
        medicationId: medicationId,
        scheduleId: scheduleId,
        patientId: patientId,
      ),
    );
  }

  Future<List<ScheduleMedicationContext>> _collectAllActiveContexts() async {
    final List<ScheduleMedicationContext> out = <ScheduleMedicationContext>[];
    final List<Patient> patients = await _safePatients();
    final Map<String, Patient> patientById = <String, Patient>{
      for (final Patient p in patients)
        if (p.id.trim().isNotEmpty) p.id.trim(): p,
    };
    final Map<String, MedicationModel> medById = <String, MedicationModel>{};
    for (final Patient p in patients) {
      final List<MedicationModel> meds = await _safeMedicationsByPatient(p.id);
      for (final MedicationModel m in meds) {
        if (m.id.trim().isNotEmpty) medById[m.id.trim()] = m;
      }
    }
    int page = 1;
    while (true) {
      final SchedulePageResult pageResult = await _safePage(() {
        return _scheduleRepo.listSchedules(page: page, limit: kSyncPageSize);
      });
      final List<ScheduleModel> items = pageResult.items;
      if (items.isEmpty) break;
      for (final ScheduleModel s in items) {
        final MedicationModel? med = medById[s.medicationId.trim()];
        final Patient? patient = med == null
            ? null
            : patientById[med.patientId.trim()];
        out.add(
          ScheduleMedicationContext(
            schedule: s,
            medication: med,
            patientFirstName: patient?.firstname,
            patientLastName: patient?.lastname,
          ),
        );
      }
      final SchedulePaginationMeta? meta = pageResult.meta;
      if (meta == null) break;
      if (page >= meta.totalPages) break;
      page += 1;
    }
    return out;
  }

  static Future<List<Patient>> _safePatients() async {
    try {
      final PatientPageResult r = await PatientRepository().listMyPatients(
        limit: 500,
      );
      return r.items;
    } catch (_) {
      return <Patient>[];
    }
  }

  static Future<List<MedicationModel>> _safeMedicationsByPatient(
    String patientId,
  ) async {
    try {
      return await MedicationRepository().getMedicationsByPatient(
        patientId.trim(),
      );
    } catch (_) {
      return <MedicationModel>[];
    }
  }

  static Future<SchedulePageResult> _safePage(
    Future<SchedulePageResult> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (_) {
      return (
        items: const <ScheduleModel>[],
        meta: const SchedulePaginationMeta(
          page: 1,
          limit: kSyncPageSize,
          total: 0,
          totalPages: 0,
        ),
      );
    }
  }

  static Future<List<ScheduleModel>> _safeSchedules(
    Future<List<ScheduleModel>> Function() fn,
    List<ScheduleModel> fallback,
  ) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }

  Future<MedicationModel?> _safeMedication(String medicationId) async {
    try {
      return await _medicationRepo.getMedicationById(medicationId.trim());
    } catch (_) {
      return null;
    }
  }

  Future<ScheduleModel?> _safeSchedule(String scheduleId) async {
    try {
      return await _scheduleRepo.getScheduleById(scheduleId.trim());
    } catch (_) {
      return null;
    }
  }

  Future<Patient?> _safePatient(String patientId) async {
    try {
      return await _patientRepo.getPatientById(patientId.trim());
    } catch (_) {
      return null;
    }
  }
}
