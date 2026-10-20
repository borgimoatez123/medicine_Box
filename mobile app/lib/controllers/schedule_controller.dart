import "package:flutter/foundation.dart";

import "../models/schedule_model.dart";
import "../services/schedule_service.dart";
import "notification_controller.dart";

class ScheduleController extends ChangeNotifier {
  ScheduleController({ScheduleService? service})
    : _service = service ?? ScheduleService();

  final ScheduleService _service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  List<ScheduleModel> _schedules = <ScheduleModel>[];
  List<ScheduleModel> get schedules =>
      List<ScheduleModel>.unmodifiable(_schedules);

  SchedulePaginationMeta? _meta;
  SchedulePaginationMeta? get meta => _meta;

  int? get totalCount => _meta?.total;
  int? get totalPages => _meta?.totalPages;
  int get currentPage => _meta?.page ?? 1;
  int? get currentLimit => _meta?.limit;

  String? _error;
  String? get error => _error;

  ScheduleModel? findById(String id) {
    final String key = id.trim();
    if (key.isEmpty) return null;
    for (final ScheduleModel s in _schedules) {
      if (s.id.trim() == key) return s;
    }
    return null;
  }

  Future<void> loadSchedules({
    String? patientId,
    String? medicationId,
    int page = 1,
    int? limit,
    bool append = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final SchedulePageResult result = await _service.listSchedules(
        patientId: patientId,
        medicationId: medicationId,
        page: page,
        limit: limit,
      );
      if (append && page > 1) {
        final Set<String> existingIds = _schedules
            .map((ScheduleModel s) => s.id)
            .where((String s) => s.isNotEmpty)
            .toSet();
        final List<ScheduleModel> unique = <ScheduleModel>[
          ..._schedules,
          ...result.items.where(
            (ScheduleModel s) => s.id.isNotEmpty && !existingIds.contains(s.id),
          ),
        ];
        _schedules = unique;
      } else {
        _schedules = List<ScheduleModel>.of(result.items);
      }
      _meta = result.meta;
      notifyListeners();
    } on ScheduleServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw ScheduleControllerException(e.message);
    } catch (e) {
      _error = "Unable to load schedules.";
      notifyListeners();
      throw ScheduleControllerException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage({
    String? patientId,
    String? medicationId,
    int? limit,
  }) async {
    final int next = currentPage + 1;
    final int? tp = totalPages;
    if (tp != null && next > tp) return;
    return loadSchedules(
      patientId: patientId,
      medicationId: medicationId,
      page: next,
      limit: limit,
      append: true,
    );
  }

  Future<void> refresh({
    String? patientId,
    String? medicationId,
    int limit = 50,
  }) {
    return loadSchedules(
      patientId: patientId,
      medicationId: medicationId,
      page: 1,
      limit: limit,
    );
  }

  Future<ScheduleModel> getSchedule(String scheduleId) async {
    try {
      final ScheduleModel fresh = await _service.getScheduleById(scheduleId);
      final int index = _schedules.indexWhere(
        (ScheduleModel s) => s.id.trim() == fresh.id.trim(),
      );
      if (index >= 0) {
        _schedules[index] = fresh;
        notifyListeners();
      }
      return fresh;
    } on ScheduleServiceException catch (e) {
      throw ScheduleControllerException(e.message);
    } catch (e) {
      throw ScheduleControllerException(e.toString());
    }
  }

  Future<ScheduleModel> createSchedule({
    required String medicationId,
    required String dosage,
    required DateTime startDate,
    int timesPerDay = 1,
    List<String>? times,
    DateTime? endDate,
    List<int>? daysOfWeek,
    ScheduleStatus status = ScheduleStatus.active,
    bool isActive = true,
    String? notes,
    bool refillReminder = false,
  }) async {
    if (_isCreating) {
      throw ScheduleControllerException("Another schedule is being created.");
    }
    _isCreating = true;
    _error = null;
    notifyListeners();
    try {
      final ScheduleModel created = await _service.createSchedule(
        medicationId: medicationId,
        dosage: dosage,
        startDate: startDate,
        timesPerDay: timesPerDay,
        times: times,
        endDate: endDate,
        daysOfWeek: daysOfWeek,
        status: status,
        isActive: isActive,
        notes: notes,
        refillReminder: refillReminder,
      );
      final Set<String> ids = _schedules
          .map((ScheduleModel s) => s.id)
          .where((String s) => s.isNotEmpty)
          .toSet();
      if (created.id.isNotEmpty && !ids.contains(created.id)) {
        _schedules = <ScheduleModel>[created, ..._schedules];
      }
      notifyListeners();
      await NotificationController.instance.onScheduleCreated(created);
      return created;
    } on ScheduleServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw ScheduleControllerException(e.message);
    } catch (e) {
      _error = "Unable to create schedule.";
      notifyListeners();
      throw ScheduleControllerException(_error!);
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<ScheduleModel> updateSchedule(
    ScheduleModel schedule, {
    String? dosage,
    int? timesPerDay,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    List<int>? daysOfWeek,
    ScheduleStatus? status,
    bool? isActive,
    String? notes,
    bool clearNotes = false,
    bool? refillReminder,
  }) async {
    if (_isUpdating) {
      throw ScheduleControllerException("Another schedule is being updated.");
    }
    _isUpdating = true;
    _error = null;
    notifyListeners();
    final ScheduleModel snapshot = schedule;
    final int index = _schedules.indexWhere(
      (ScheduleModel s) => s.id.trim() == snapshot.id.trim(),
    );
    try {
      final ScheduleModel updated = await _service.updateSchedule(
        snapshot.id,
        dosage: dosage,
        timesPerDay: timesPerDay,
        times: times,
        startDate: startDate,
        endDate: endDate,
        clearEndDate: clearEndDate,
        daysOfWeek: daysOfWeek,
        status: status,
        isActive: isActive,
        notes: notes,
        clearNotes: clearNotes,
        refillReminder: refillReminder,
      );
      if (index >= 0) {
        _schedules[index] = updated;
      }
      notifyListeners();
      await NotificationController.instance.onScheduleUpdated(updated);
      return updated;
    } on ScheduleServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw ScheduleControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _schedules[index] = snapshot;
        notifyListeners();
      }
      _error = "Unable to update schedule.";
      notifyListeners();
      throw ScheduleControllerException(_error!);
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(ScheduleModel schedule) async {
    if (_isDeleting) {
      throw ScheduleControllerException("Another schedule is being deleted.");
    }
    _isDeleting = true;
    _error = null;
    notifyListeners();
    final List<ScheduleModel> snapshot = List<ScheduleModel>.of(_schedules);
    final String targetId = schedule.id.trim();
    _schedules = _schedules
        .where((ScheduleModel s) => s.id.trim() != targetId)
        .toList(growable: false);
    notifyListeners();
    try {
      await _service.deleteSchedule(schedule.id);
      await NotificationController.instance.onScheduleDeleted(schedule.id);
      notifyListeners();
    } on ScheduleServiceException catch (e) {
      _schedules = snapshot;
      _error = e.message;
      notifyListeners();
      throw ScheduleControllerException(e.message);
    } catch (e) {
      _schedules = snapshot;
      _error = "Unable to delete schedule.";
      notifyListeners();
      throw ScheduleControllerException(_error!);
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }
}

class ScheduleControllerException implements Exception {
  ScheduleControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
