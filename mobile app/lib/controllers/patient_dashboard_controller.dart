import "package:flutter/foundation.dart";

import "../data/repositories/alert_repository.dart";
import "../data/repositories/medication_repository.dart";
import "../data/repositories/patient_repository.dart";
import "../data/repositories/schedule_repository.dart";
import "../models/alert_model.dart";
import "../models/medication_model.dart";
import "../models/patient.dart";
import "../models/schedule_model.dart";
import "../services/medication_service.dart";
import "notification_controller.dart";

enum MedicationSlotStatus { taken, pending, missed }

class TimeOfDayCustom {
  const TimeOfDayCustom({required this.hour, required this.minute});

  final int hour;
  final int minute;

  String format() {
    final int h12 = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final String suffix = hour >= 12 ? "PM" : "AM";
    return "$h12:${minute.toString().padLeft(2, "0")} $suffix";
  }
}

class DailyMedicationSlot {
  const DailyMedicationSlot({
    required this.medication,
    required this.time,
    required this.status,
  });

  final MedicationModel medication;
  final TimeOfDayCustom? time;
  final MedicationSlotStatus status;

  String get displayTime {
    if (time != null) return time!.format();
    final String? freq = medication.frequency?.trim();
    if (freq != null && freq.isNotEmpty) return freq;
    return "Daily";
  }
}

extension MedicationSlotStatusX on MedicationSlotStatus {
  String get label {
    switch (this) {
      case MedicationSlotStatus.taken:
        return "Taken";
      case MedicationSlotStatus.pending:
        return "Pending";
      case MedicationSlotStatus.missed:
        return "Missed";
    }
  }
}

class PatientDashboardController extends ChangeNotifier {
  PatientDashboardController({
    Patient? initialPatient,
    String? patientId,
    PatientRepository? patientRepository,
    MedicationRepository? medicationRepository,
    AlertRepository? alertRepository,
    ScheduleRepository? scheduleRepository,
    MedicationService? medicationService,
  }) : _patient = initialPatient,
       _passedPatientId = patientId?.trim(),
       _patientRepo = patientRepository ?? PatientRepository(),
       _medicationRepo = medicationRepository ?? MedicationRepository(),
       _alertRepo = alertRepository ?? AlertRepository(),
       _scheduleRepo = scheduleRepository ?? ScheduleRepository(),
       _medicationService =
           medicationService ??
           MedicationService(
             repository: medicationRepository ?? MedicationRepository(),
           ) {
    _selectedDay = _dateOnly(DateTime.now());
    _weekStart = _weekStartOf(_selectedDay);
  }

  final PatientRepository _patientRepo;
  final MedicationRepository _medicationRepo;
  final AlertRepository _alertRepo;
  final ScheduleRepository _scheduleRepo;
  final MedicationService _medicationService;
  final String? _passedPatientId;

  Patient? _patient;
  bool _patientLoading = false;
  String? _patientError;

  List<MedicationModel> _medications = const <MedicationModel>[];
  bool _medicationsLoading = false;
  String? _medicationsError;

  List<ScheduleModel> _schedules = const <ScheduleModel>[];
  bool _schedulesLoading = false;
  String? _schedulesError;

  List<AlertModel> _alerts = const <AlertModel>[];
  bool _alertsLoading = false;
  String? _alertsError;

  String _medicationsSearch = "";
  bool _isMedicationUpdating = false;
  bool _isMedicationDeleting = false;
  String? _medicationActionError;

  late DateTime _selectedDay;
  late DateTime _weekStart;

  int _tab = 0;

  Patient? get patient => _patient;
  bool get patientLoading => _patientLoading;
  String? get patientError => _patientError;

  String? get patientId {
    final String? fromPatient = _patient?.id.trim();
    if (fromPatient != null && fromPatient.isNotEmpty) return fromPatient;
    final String? fromArg = _passedPatientId?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    return null;
  }

  List<MedicationModel> get medications => _medications;
  bool get medicationsLoading => _medicationsLoading;
  String? get medicationsError => _medicationsError;

  List<ScheduleModel> get schedules => _schedules;
  bool get schedulesLoading => _schedulesLoading;
  String? get schedulesError => _schedulesError;

  List<AlertModel> get alerts => _alerts;
  bool get alertsLoading => _alertsLoading;
  String? get alertsError => _alertsError;

  String get medicationsSearch => _medicationsSearch;
  bool get isMedicationUpdating => _isMedicationUpdating;
  bool get isMedicationDeleting => _isMedicationDeleting;
  String? get medicationActionError => _medicationActionError;

  DateTime get selectedDay => _selectedDay;
  DateTime get weekStart => _weekStart;
  DateTime get today => _dateOnly(DateTime.now());

  int get currentTab => _tab;

  List<DateTime> get weekDays {
    return List<DateTime>.generate(7, (int i) {
      return _weekStart.add(Duration(days: i));
    });
  }

  List<MedicationModel> get filteredMedications {
    final String q = _medicationsSearch.trim().toLowerCase();
    if (q.isEmpty) return _medications;
    return _medications
        .where((MedicationModel m) {
          final String name = m.name.trim().toLowerCase();
          final String dosage = m.dosage.trim().toLowerCase();
          return name.contains(q) || dosage.contains(q);
        })
        .toList(growable: false);
  }

  List<DailyMedicationSlot> get todaySlots {
    return _buildDailySlots(_selectedDay, _medications, _schedules);
  }

  int get totalScheduledToday => todaySlots.length;

  int get takenToday {
    return todaySlots
        .where(
          (DailyMedicationSlot s) => s.status == MedicationSlotStatus.taken,
        )
        .length;
  }

  int get pendingToday {
    return todaySlots
        .where(
          (DailyMedicationSlot s) => s.status == MedicationSlotStatus.pending,
        )
        .length;
  }

  int get missedToday {
    return todaySlots
        .where(
          (DailyMedicationSlot s) => s.status == MedicationSlotStatus.missed,
        )
        .length;
  }

  double get progressToday {
    final int total = totalScheduledToday;
    if (total == 0) return 0.0;
    final int t = takenToday;
    if (t <= 0) return 0.0;
    if (t >= total) return 1.0;
    return t / total;
  }

  static DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _weekStartOf(DateTime day) {
    final DateTime normalized = _dateOnly(day);
    final int weekday = normalized.weekday;
    final int delta = weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta));
  }

  void setMedicationsSearch(String value) {
    if (_medicationsSearch == value) return;
    _medicationsSearch = value;
    notifyListeners();
  }

  void setSelectedDay(DateTime day) {
    final DateTime normalized = _dateOnly(day);
    if (_selectedDay == normalized) return;
    _selectedDay = normalized;
    if (!_isSameWeek(_weekStart, normalized)) {
      _weekStart = _weekStartOf(normalized);
    }
    notifyListeners();
  }

  void goToPreviousWeek() {
    _weekStart = _weekStart.subtract(const Duration(days: 7));
    if (_selectedDay.isAfter(_weekStart.add(const Duration(days: 6)))) {
      _selectedDay = _weekStart.add(const Duration(days: 6));
    } else if (_selectedDay.isBefore(_weekStart)) {
      _selectedDay = _weekStart;
    }
    notifyListeners();
  }

  void goToNextWeek() {
    _weekStart = _weekStart.add(const Duration(days: 7));
    final DateTime weekEnd = _weekStart.add(const Duration(days: 6));
    if (_selectedDay.isAfter(weekEnd)) {
      _selectedDay = weekEnd;
    } else if (_selectedDay.isBefore(_weekStart)) {
      _selectedDay = _weekStart;
    }
    notifyListeners();
  }

  void selectToday() {
    final DateTime now = _dateOnly(DateTime.now());
    _selectedDay = now;
    if (!_isSameWeek(_weekStart, now)) {
      _weekStart = _weekStartOf(now);
    }
    notifyListeners();
  }

  static bool _isSameWeek(DateTime weekStart, DateTime day) {
    final DateTime d = _dateOnly(day);
    final DateTime ws = _dateOnly(weekStart);
    final DateTime we = ws.add(const Duration(days: 6));
    return !d.isBefore(ws) && !d.isAfter(we);
  }

  void setTab(int index) {
    if (index < 0 || index == _tab) return;
    _tab = index;
    notifyListeners();
  }

  Future<String> _resolvePatientId() async {
    final String? fromArg = _passedPatientId?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    final String? fromPatient = _patient?.id.trim();
    if (fromPatient != null && fromPatient.isNotEmpty) return fromPatient;
    throw PatientDashboardControllerException("Missing patient id");
  }

  Future<void> loadAll({bool forceRefresh = false}) async {
    await loadPatient(forceRefresh: forceRefresh);
    if (_patient != null) {
      await Future.wait(<Future<void>>[
        loadMedications(),
        loadSchedules(),
        loadAlerts(),
      ]);
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
      throw PatientDashboardControllerException(
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
      await NotificationController.instance.onMedicationUpdated(updated);
      return updated;
    } on MedicationServiceException catch (e) {
      _medicationActionError = e.message;
      notifyListeners();
      throw PatientDashboardControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _medications[index] = snapshot;
        notifyListeners();
      }
      _medicationActionError = "Unable to update medication.";
      notifyListeners();
      throw PatientDashboardControllerException(_medicationActionError!);
    } finally {
      _isMedicationUpdating = false;
      notifyListeners();
    }
  }

  Future<void> deleteMedication(MedicationModel medication) async {
    if (_isMedicationDeleting) {
      throw PatientDashboardControllerException(
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
      await NotificationController.instance.onMedicationDeleted(medication.id);
      notifyListeners();
    } on MedicationServiceException catch (e) {
      _medications = snapshot;
      _medicationActionError = e.message;
      notifyListeners();
      throw PatientDashboardControllerException(e.message);
    } catch (e) {
      _medications = snapshot;
      _medicationActionError = "Unable to delete medication.";
      notifyListeners();
      throw PatientDashboardControllerException(_medicationActionError!);
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

  Future<void> loadSchedules() async {
    if (_schedulesLoading) return;
    final Patient? p = _patient;
    if (p == null || p.id.trim().isEmpty) {
      _schedules = const <ScheduleModel>[];
      _schedulesError = null;
      notifyListeners();
      return;
    }
    _schedulesLoading = true;
    _schedulesError = null;
    notifyListeners();
    try {
      final SchedulePageResult page = await _scheduleRepo.listSchedules(
        patientId: p.id.trim(),
        page: 1,
        limit: 100,
      );
      _schedules = page.items;
    } catch (e) {
      _schedulesError = _friendly(e);
    } finally {
      _schedulesLoading = false;
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
    _medications = const <MedicationModel>[];
    _schedules = const <ScheduleModel>[];
    _alerts = const <AlertModel>[];
    _medicationsError = null;
    _schedulesError = null;
    _alertsError = null;
    notifyListeners();
    await loadAll(forceRefresh: true);
  }

  static List<DailyMedicationSlot> _buildDailySlots(
    DateTime day,
    List<MedicationModel> medications,
    List<ScheduleModel> schedules,
  ) {
    final DateTime dayOnly = _dateOnly(day);
    final List<DailyMedicationSlot> slots = <DailyMedicationSlot>[];
    final DateTime now = DateTime.now();
    final bool isToday = _dateOnly(now) == dayOnly;
    final int selectedDow = dayOnly.weekday;

    final Map<String, MedicationModel> medById = <String, MedicationModel>{};
    for (final MedicationModel m in medications) {
      medById[m.id.trim()] = m;
    }
    final Set<String> medIdsWithSchedule = <String>{};

    for (final ScheduleModel s in schedules) {
      final String mid = s.medicationId.trim();
      if (mid.isEmpty) continue;
      final MedicationModel? m = medById[mid];
      if (m == null) continue;
      if (s.isActive == false) continue;
      if (s.status == ScheduleStatus.archived ||
          s.status == ScheduleStatus.completed) {
        continue;
      }
      final DateTime startOnly = _dateOnly(s.startDate);
      if (dayOnly.isBefore(startOnly)) continue;
      final DateTime? endOnly = s.endDate != null
          ? _dateOnly(s.endDate!)
          : null;
      if (endOnly != null && dayOnly.isAfter(endOnly)) continue;

      final List<int> days = s.daysOfWeek.isNotEmpty
          ? s.daysOfWeek.where((int d) => d >= 1 && d <= 7).toList()
          : const <int>[1, 2, 3, 4, 5, 6, 7];
      if (!days.contains(selectedDow)) continue;

      medIdsWithSchedule.add(mid);

      final List<TimeOfDayCustom> times = _parseScheduleTimes(s.times);
      if (times.isEmpty) {
        final MedicationSlotStatus status = isToday
            ? _inferStatus(m, const TimeOfDayCustom(hour: 12, minute: 0), now)
            : MedicationSlotStatus.pending;
        slots.add(
          DailyMedicationSlot(medication: m, time: null, status: status),
        );
        continue;
      }
      for (final TimeOfDayCustom t in times) {
        final MedicationSlotStatus status = isToday
            ? _inferStatus(m, t, now)
            : MedicationSlotStatus.pending;
        slots.add(DailyMedicationSlot(medication: m, time: t, status: status));
      }
    }

    for (final MedicationModel m in medications) {
      if (medIdsWithSchedule.contains(m.id.trim())) continue;
      final DateTime? start = m.startDate != null
          ? _dateOnly(m.startDate!)
          : null;
      final DateTime? end = m.endDate != null ? _dateOnly(m.endDate!) : null;
      if (start != null && dayOnly.isBefore(start)) continue;
      if (end != null && dayOnly.isAfter(end)) continue;

      final List<TimeOfDayCustom> times = _extractScheduledTimes(m);
      if (times.isEmpty) {
        final MedicationSlotStatus status = isToday
            ? _inferStatus(m, const TimeOfDayCustom(hour: 12, minute: 0), now)
            : MedicationSlotStatus.pending;
        slots.add(
          DailyMedicationSlot(medication: m, time: null, status: status),
        );
        continue;
      }
      for (final TimeOfDayCustom t in times) {
        final MedicationSlotStatus status = isToday
            ? _inferStatus(m, t, now)
            : MedicationSlotStatus.pending;
        slots.add(DailyMedicationSlot(medication: m, time: t, status: status));
      }
    }

    slots.sort((DailyMedicationSlot a, DailyMedicationSlot b) {
      final int ta = a.time != null
          ? a.time!.hour * 60 + a.time!.minute
          : 24 * 60;
      final int tb = b.time != null
          ? b.time!.hour * 60 + b.time!.minute
          : 24 * 60;
      final int byTime = ta.compareTo(tb);
      if (byTime != 0) return byTime;
      return a.medication.name.toLowerCase().compareTo(
        b.medication.name.toLowerCase(),
      );
    });

    return slots;
  }

  static List<TimeOfDayCustom> _parseScheduleTimes(List<String>? times) {
    final List<TimeOfDayCustom> result = <TimeOfDayCustom>[];
    if (times == null || times.isEmpty) return result;
    for (final String raw in times) {
      final String t = raw.trim();
      final List<String> parts = t.split(":");
      if (parts.length != 2) continue;
      final int? h = int.tryParse(parts[0]);
      final int? m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      if (h < 0 || h > 23 || m < 0 || m > 59) continue;
      result.add(TimeOfDayCustom(hour: h, minute: m));
    }
    return result;
  }

  static MedicationSlotStatus _inferStatus(
    MedicationModel m,
    TimeOfDayCustom t,
    DateTime now,
  ) {
    final String raw = (m.status ?? "").trim().toLowerCase();
    if (raw == "taken" || raw == "done" || raw == "completed") {
      return MedicationSlotStatus.taken;
    }
    if (raw == "missed" || raw == "skipped") {
      return MedicationSlotStatus.missed;
    }
    if (raw == "paused" || raw == "suspended") {
      return MedicationSlotStatus.pending;
    }
    final int scheduledMinutes = t.hour * 60 + t.minute;
    final int nowMinutes = now.hour * 60 + now.minute;
    const int missedWindowMinutes = 60;
    if (nowMinutes - scheduledMinutes > missedWindowMinutes) {
      return MedicationSlotStatus.missed;
    }
    return MedicationSlotStatus.pending;
  }

  static List<TimeOfDayCustom> _extractScheduledTimes(MedicationModel m) {
    final List<TimeOfDayCustom> times = <TimeOfDayCustom>[];

    final String freq = (m.frequency ?? "").trim().toLowerCase();
    if (freq.isNotEmpty) {
      if (freq.contains("once") || freq.contains("1") || freq == "daily") {
        times.add(const TimeOfDayCustom(hour: 8, minute: 0));
      } else if (freq.contains("twice") ||
          freq.contains("2") ||
          freq.contains("bid")) {
        times.add(const TimeOfDayCustom(hour: 8, minute: 0));
        times.add(const TimeOfDayCustom(hour: 20, minute: 0));
      } else if (freq.contains("thrice") ||
          freq.contains("3") ||
          freq.contains("tid")) {
        times.add(const TimeOfDayCustom(hour: 8, minute: 0));
        times.add(const TimeOfDayCustom(hour: 14, minute: 0));
        times.add(const TimeOfDayCustom(hour: 20, minute: 0));
      } else if (freq.contains("4") || freq.contains("qid")) {
        times.add(const TimeOfDayCustom(hour: 8, minute: 0));
        times.add(const TimeOfDayCustom(hour: 12, minute: 0));
        times.add(const TimeOfDayCustom(hour: 18, minute: 0));
        times.add(const TimeOfDayCustom(hour: 22, minute: 0));
      } else {
        times.add(const TimeOfDayCustom(hour: 9, minute: 0));
      }
    }

    if (times.isEmpty) {
      times.add(const TimeOfDayCustom(hour: 9, minute: 0));
    }

    return times;
  }

  static String _friendly(Object e) {
    if (e is PatientRepositoryException) return e.message;
    if (e is MedicationRepositoryException) return e.message;
    if (e is ScheduleRepositoryException) return e.message;
    if (e is AlertRepositoryException) return e.message;
    if (e is PatientDashboardControllerException) return e.message;
    final String s = e.toString();
    if (s.trim().isEmpty) return "Unable to load data.";
    return s;
  }
}

class PatientDashboardControllerException implements Exception {
  PatientDashboardControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
