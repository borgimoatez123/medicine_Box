import "../data/repositories/schedule_repository.dart";
import "../models/schedule_model.dart";

class ScheduleService {
  ScheduleService({ScheduleRepository? repository})
    : _repository = repository ?? ScheduleRepository();

  final ScheduleRepository _repository;

  static bool _isValidUuidish(String value) {
    final String v = value.trim();
    if (v.isEmpty) return false;
    if (v.length < 6) return false;
    return true;
  }

  static bool _isValidHhmm(String value) {
    final String v = value.trim();
    if (!RegExp(r"^\d{2}:\d{2}$").hasMatch(v)) return false;
    final List<String> parts = v.split(":");
    final int h = int.tryParse(parts.first) ?? -1;
    final int m = int.tryParse(parts.last) ?? -1;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  static bool _isValidDay(int day) => day >= 1 && day <= 7;

  Future<SchedulePageResult> listSchedules({
    String? patientId,
    String? medicationId,
    int? page,
    int? limit,
  }) {
    return _repository.listSchedules(
      patientId: patientId,
      medicationId: medicationId,
      page: page,
      limit: limit,
    );
  }

  Future<List<ScheduleModel>> getSchedulesByPatient(String patientId) {
    final String pid = patientId.trim();
    if (pid.isEmpty) {
      throw ScheduleServiceException("Missing patient id");
    }
    return _repository.getSchedulesByPatient(pid);
  }

  Future<List<ScheduleModel>> getSchedulesByMedication(String medicationId) {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw ScheduleServiceException("Missing medication id");
    }
    return _repository.getSchedulesByMedication(mid);
  }

  Future<ScheduleModel> getScheduleById(String scheduleId) {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleServiceException("Missing schedule id");
    }
    return _repository.getScheduleById(sid);
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
    final String mid = medicationId.trim();
    final String d = dosage.trim();
    if (mid.isEmpty || !_isValidUuidish(mid)) {
      throw ScheduleServiceException("Invalid medication ID format");
    }
    if (d.isEmpty) {
      throw ScheduleServiceException("Dosage is required");
    }
    if (timesPerDay < 1) {
      throw ScheduleServiceException("Times per day must be at least 1");
    }
    if (endDate != null &&
        endDate.isBefore(
          DateTime(startDate.year, startDate.month, startDate.day),
        )) {
      throw ScheduleServiceException("End date must be on or after start date");
    }
    final List<String> cleanTimes = <String>[];
    final Set<int> daysSet = <int>{};
    if (times != null) {
      for (final String t in times) {
        final String clean = t.trim();
        if (clean.isEmpty) continue;
        if (!_isValidHhmm(clean)) {
          throw ScheduleServiceException(
            "Invalid time format (expected HH:mm — use '08:00' not '8:00')",
          );
        }
        cleanTimes.add(clean);
      }
    }
    if (daysOfWeek != null) {
      for (final int raw in daysOfWeek) {
        if (!_isValidDay(raw)) {
          throw ScheduleServiceException("Each day must be between 1 and 7");
        }
        if (!daysSet.add(raw)) {
          throw ScheduleServiceException(
            "Duplicate day-of-week values are not allowed",
          );
        }
      }
    }
    final List<int> sortedDays = daysSet.toList()..sort();
    final CreateScheduleRequest request = CreateScheduleRequest(
      medicationId: mid,
      dosage: d,
      timesPerDay: timesPerDay,
      times: cleanTimes.isEmpty ? null : cleanTimes,
      startDate: startDate,
      endDate: endDate,
      daysOfWeek: sortedDays.isEmpty ? null : sortedDays,
      status: status,
      isActive: isActive,
      notes: notes,
      refillReminder: refillReminder,
    );
    return _repository.createSchedule(request);
  }

  Future<ScheduleModel> updateSchedule(
    String scheduleId, {
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
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleServiceException("Missing schedule id");
    }
    final String? d = dosage?.trim();
    if (d != null && d.isEmpty) {
      throw ScheduleServiceException("Dosage cannot be empty");
    }
    if (timesPerDay != null && timesPerDay < 1) {
      throw ScheduleServiceException("Times per day must be at least 1");
    }
    if (startDate != null &&
        endDate != null &&
        endDate.isBefore(
          DateTime(startDate.year, startDate.month, startDate.day),
        )) {
      throw ScheduleServiceException("End date must be on or after start date");
    }
    List<String>? cleanTimes;
    if (times != null) {
      cleanTimes = <String>[];
      for (final String t in times) {
        final String clean = t.trim();
        if (clean.isEmpty) continue;
        if (!_isValidHhmm(clean)) {
          throw ScheduleServiceException(
            "Invalid time format (expected HH:mm — use '08:00' not '8:00')",
          );
        }
        cleanTimes.add(clean);
      }
    }
    List<int>? sortedDays;
    if (daysOfWeek != null) {
      final Set<int> seen = <int>{};
      sortedDays = <int>[];
      for (final int raw in daysOfWeek) {
        if (!_isValidDay(raw)) {
          throw ScheduleServiceException("Each day must be between 1 and 7");
        }
        if (!seen.add(raw)) {
          throw ScheduleServiceException(
            "Duplicate day-of-week values are not allowed",
          );
        }
        sortedDays.add(raw);
      }
      sortedDays.sort();
    }
    final UpdateScheduleRequest request = UpdateScheduleRequest(
      dosage: d,
      timesPerDay: timesPerDay,
      times: cleanTimes,
      startDate: startDate,
      endDate: endDate,
      clearEndDate: clearEndDate,
      daysOfWeek: sortedDays,
      status: status,
      isActive: isActive,
      notes: notes,
      clearNotes: clearNotes,
      refillReminder: refillReminder,
    );
    if (request.isEmpty) {
      return _repository.getScheduleById(sid);
    }
    return _repository.updateSchedule(sid, request);
  }

  Future<void> deleteSchedule(String scheduleId) {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleServiceException("Missing schedule id");
    }
    return _repository.deleteSchedule(sid);
  }
}

class ScheduleServiceException implements Exception {
  ScheduleServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
