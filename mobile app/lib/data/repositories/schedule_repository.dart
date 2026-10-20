import "../../models/schedule_model.dart";
import "../../utils/constants/api_constants.dart";
import "../api_client.dart";

class ScheduleRepository {
  ScheduleRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Set<String> _allowedCreateKeys = <String>{
    "medicationId",
    "dosage",
    "timesPerDay",
    "times",
    "startDate",
    "endDate",
    "daysOfWeek",
    "status",
    "isActive",
    "notes",
    "refillReminder",
  };

  static const Set<String> _allowedUpdateKeys = <String>{
    "dosage",
    "timesPerDay",
    "times",
    "startDate",
    "endDate",
    "daysOfWeek",
    "status",
    "isActive",
    "notes",
    "refillReminder",
  };

  static const Map<String, String> _canonicalAliases = <String, String>{
    "medication_id": "medicationId",
    "dose": "dosage",
    "amount": "dosage",
    "times_per_day": "timesPerDay",
    "frequency": "timesPerDay",
    "timeOfDay": "times",
    "timeList": "times",
    "start_date": "startDate",
    "start": "startDate",
    "end_date": "endDate",
    "end": "endDate",
    "days": "daysOfWeek",
    "days_of_week": "daysOfWeek",
    "repeatDays": "daysOfWeek",
    "is_active": "isActive",
    "active": "isActive",
    "note": "notes",
    "refill_reminder": "refillReminder",
    "refill": "refillReminder",
  };

  static String? _canonicalKey(String key, {bool isCreate = false}) {
    final Set<String> allowed = isCreate
        ? _allowedCreateKeys
        : _allowedUpdateKeys;
    final String k = key.trim();
    if (allowed.contains(k)) return k;
    final String? aliased = _canonicalAliases[k];
    if (aliased != null && allowed.contains(aliased)) return aliased;
    return null;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  static String? _normalizeTime(dynamic value) {
    if (value == null) return null;
    String s = value.toString().trim();
    if (s.isEmpty) return null;
    if (s.length <= 2 && int.tryParse(s) != null) {
      return "${int.parse(s).toString().padLeft(2, "0")}:00";
    }
    if (RegExp(r"^\d{1,2}:\d{2}$").hasMatch(s)) {
      final List<String> parts = s.split(":");
      final int h = int.tryParse(parts.first) ?? 0;
      final int m = int.tryParse(parts.last) ?? 0;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}";
    }
    final RegExpMatch? hhmm12 = RegExp(
      r"^(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)$",
    ).firstMatch(s);
    if (hhmm12 != null) {
      int h = int.tryParse(hhmm12.group(1) ?? "0") ?? 0;
      final int m = int.tryParse(hhmm12.group(2) ?? "0") ?? 0;
      final String period = (hhmm12.group(3) ?? "").toUpperCase();
      if (period == "PM" && h != 12) h += 12;
      if (period == "AM" && h == 12) h = 0;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}";
    }
    return s;
  }

  static dynamic _coerceValue(String canonical, dynamic value) {
    if (canonical == "medicationId" ||
        canonical == "dosage" ||
        canonical == "notes") {
      if (value == null) return null;
      final String s = value.toString().trim();
      return s.isEmpty ? null : s;
    }
    if (canonical == "timesPerDay") {
      if (value is int) return value < 1 ? null : value;
      if (value is num) {
        final int v = value.toInt();
        return v < 1 ? null : v;
      }
      if (value is String) {
        final int? i = int.tryParse(value.trim());
        return (i != null && i >= 1) ? i : null;
      }
      return null;
    }
    if (canonical == "times") {
      if (value is List) {
        return value
            .map((dynamic e) => _normalizeTime(e))
            .whereType<String>()
            .toList(growable: false);
      }
      final String? one = _normalizeTime(value);
      if (one != null) return <String>[one];
      return null;
    }
    if (canonical == "startDate" || canonical == "endDate") {
      if (value is String) {
        final String s = value.trim();
        if (s.isEmpty) return null;
        final DateTime? d = DateTime.tryParse(s);
        if (d != null) return _formatDate(d);
        return s;
      }
      if (value is DateTime) return _formatDate(value);
      return null;
    }
    if (canonical == "daysOfWeek") {
      final List<int> out = <int>[];
      final Set<int> seen = <int>{};
      if (value is List) {
        for (final dynamic e in value) {
          int? d;
          if (e is int) d = e;
          if (e is num) d = e.toInt();
          if (e is String) d = int.tryParse(e.trim());
          if (d != null && d >= 1 && d <= 7 && seen.add(d)) {
            out.add(d);
          }
        }
      } else {
        int? d;
        if (value is int) d = value;
        if (value is num) d = value.toInt();
        if (value is String) d = int.tryParse(value.toString().trim());
        if (d != null && d >= 1 && d <= 7) out.add(d);
      }
      out.sort();
      return out.isEmpty ? null : out;
    }
    if (canonical == "status") {
      if (value is ScheduleStatus) return value.backendValue;
      if (value is String) {
        final ScheduleStatus? s = value.toScheduleStatusOrNull;
        return s?.backendValue;
      }
      return null;
    }
    if (canonical == "isActive" || canonical == "refillReminder") {
      if (value is bool) return value;
      if (value is String) {
        final String s = value.trim().toLowerCase();
        if (s == "true" || s == "1" || s == "yes") return true;
        if (s == "false" || s == "0" || s == "no") return false;
      }
      return null;
    }
    return value;
  }

  static Map<String, dynamic> _sanitizeCreateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key, isCreate: true);
      if (canonical == null) continue;
      if (!_allowedCreateKeys.contains(canonical)) continue;
      final dynamic coerced = _coerceValue(canonical, entry.value);
      if (canonical == "endDate" || canonical == "notes") {
        if (input.containsKey(entry.key)) {
          body[canonical] = coerced;
        }
      } else if (coerced != null) {
        body[canonical] = coerced;
      }
    }
    final String? mid = body["medicationId"]?.toString();
    if (mid == null || mid.trim().isEmpty) {
      throw ScheduleRepositoryException("Missing medication id");
    }
    final String? dosage = body["dosage"]?.toString();
    if (dosage == null || dosage.trim().isEmpty) {
      throw ScheduleRepositoryException("Dosage is required");
    }
    final String? startDate = body["startDate"]?.toString();
    if (startDate == null || startDate.trim().isEmpty) {
      throw ScheduleRepositoryException("Start date is required");
    }
    body["medicationId"] = mid.trim();
    body["dosage"] = dosage.trim();
    body["startDate"] = startDate.trim();
    body["status"] ??= ScheduleStatus.active.backendValue;
    body["isActive"] ??= true;
    return body;
  }

  static Map<String, dynamic> _sanitizeUpdateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key, isCreate: false);
      if (canonical == null) continue;
      if (!_allowedUpdateKeys.contains(canonical)) continue;
      if (canonical == "medicationId") continue;
      final dynamic value = entry.value;
      if (canonical == "endDate") {
        if (value == null) {
          body["endDate"] = null;
          continue;
        }
        final dynamic coerced = _coerceValue(canonical, value);
        if (coerced != null) body["endDate"] = coerced;
        continue;
      }
      if (canonical == "notes") {
        if (value == null) {
          body["notes"] = null;
          continue;
        }
        final dynamic coerced = _coerceValue(canonical, value);
        body["notes"] = coerced;
        continue;
      }
      final dynamic coerced = _coerceValue(canonical, value);
      if (coerced != null) body[canonical] = coerced;
    }
    return body;
  }

  int? _httpStatus(dynamic exception) {
    if (exception is ApiHttpException) return exception.statusCode;
    return null;
  }

  String _friendly(dynamic e) {
    final int? status = _httpStatus(e);
    if (status == 404) return "Schedule not found";
    if (e is ApiClientException) return e.message;
    if (e is ScheduleRepositoryException) return e.message;
    return e.toString();
  }

  SchedulePageResult _extractPage(dynamic decoded) {
    List<ScheduleModel> items = <ScheduleModel>[];
    SchedulePaginationMeta? meta;
    if (decoded == null) {
      return (items: items, meta: meta);
    }
    if (decoded is List) {
      items = decoded
          .whereType<Map<String, dynamic>>()
          .map(ScheduleModel.fromJson)
          .toList(growable: false);
      return (items: items, meta: meta);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        items = data
            .whereType<Map<String, dynamic>>()
            .map(ScheduleModel.fromJson)
            .toList(growable: false);
      } else if (data is Map<String, dynamic>) {
        final dynamic inner =
            data["schedules"] ?? data["items"] ?? data["schedule"];
        if (inner is List) {
          items = inner
              .whereType<Map<String, dynamic>>()
              .map(ScheduleModel.fromJson)
              .toList(growable: false);
        }
      }
      final dynamic metaRaw = decoded["meta"];
      if (metaRaw is Map<String, dynamic>) {
        meta = SchedulePaginationMeta.fromJson(metaRaw);
      }
    }
    return (items: items, meta: meta);
  }

  Future<SchedulePageResult> listSchedules({
    String? patientId,
    String? medicationId,
    int? page,
    int? limit,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    final String? pid = patientId?.trim();
    if (pid != null && pid.isNotEmpty) query["patientId"] = pid;
    final String? mid = medicationId?.trim();
    if (mid != null && mid.isNotEmpty) query["medicationId"] = mid;
    if (page != null && page > 0) query["page"] = page.toString();
    if (limit != null && limit > 0) query["limit"] = limit.toString();
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.schedules,
        queryParameters: query.isEmpty ? null : query,
      );
      return _extractPage(decoded);
    } catch (e) {
      throw ScheduleRepositoryException(_friendly(e));
    }
  }

  Future<List<ScheduleModel>> getSchedulesByPatient(String patientId) async {
    final String pid = patientId.trim();
    if (pid.isEmpty) {
      throw ScheduleRepositoryException("Missing patient id");
    }
    final SchedulePageResult result = await listSchedules(patientId: pid);
    return List<ScheduleModel>.of(result.items);
  }

  Future<List<ScheduleModel>> getSchedulesByMedication(
    String medicationId,
  ) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw ScheduleRepositoryException("Missing medication id");
    }
    final SchedulePageResult result = await listSchedules(medicationId: mid);
    return List<ScheduleModel>.of(result.items);
  }

  Future<ScheduleModel> getScheduleById(String scheduleId) async {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleRepositoryException("Missing schedule id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.schedules}/$sid",
      );
      if (decoded == null) {
        throw ScheduleRepositoryException("Schedule not found");
      }
      Map<String, dynamic>? json;
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded["data"];
        if (data is Map<String, dynamic>) {
          json = data;
        } else {
          json = decoded;
        }
      }
      if (json == null) {
        throw ScheduleRepositoryException("Schedule not found");
      }
      return ScheduleModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw ScheduleRepositoryException("Schedule not found");
      }
      if (e is ScheduleRepositoryException) rethrow;
      throw ScheduleRepositoryException(_friendly(e));
    }
  }

  Future<ScheduleModel> createSchedule(CreateScheduleRequest request) async {
    final Map<String, dynamic> body = _sanitizeCreateBody(request.toJson());
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.schedules,
        body: body,
      );
      if (decoded == null) {
        throw ScheduleRepositoryException("Failed to create schedule");
      }
      Map<String, dynamic>? json;
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded["data"];
        if (data is Map<String, dynamic>) {
          json = data;
        } else {
          json = decoded;
        }
      }
      if (json == null) {
        throw ScheduleRepositoryException("Failed to create schedule");
      }
      return ScheduleModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404 && e is ApiClientException) {
        if (e.message.toLowerCase().contains("medication")) {
          throw ScheduleRepositoryException("Medication not found");
        }
      }
      if (e is ScheduleRepositoryException) rethrow;
      throw ScheduleRepositoryException(_friendly(e));
    }
  }

  Future<ScheduleModel> updateSchedule(
    String scheduleId,
    UpdateScheduleRequest request,
  ) async {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleRepositoryException("Missing schedule id");
    }
    final Map<String, dynamic> body = _sanitizeUpdateBody(request.body);
    if (body.isEmpty) {
      return getScheduleById(sid);
    }
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.schedules}/$sid",
        body: body,
      );
      if (decoded == null) {
        return getScheduleById(sid);
      }
      Map<String, dynamic>? json;
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded["data"];
        if (data is Map<String, dynamic>) {
          json = data;
        } else {
          json = decoded;
        }
      }
      if (json == null) {
        return getScheduleById(sid);
      }
      return ScheduleModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw ScheduleRepositoryException("Schedule not found");
      }
      if (e is ScheduleRepositoryException) rethrow;
      throw ScheduleRepositoryException(_friendly(e));
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) {
      throw ScheduleRepositoryException("Missing schedule id");
    }
    try {
      await _apiClient.delete("${ApiConstants.schedules}/$sid");
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw ScheduleRepositoryException("Schedule not found");
      }
      if (e is ScheduleRepositoryException) rethrow;
      throw ScheduleRepositoryException(_friendly(e));
    }
  }
}

class ScheduleRepositoryException implements Exception {
  ScheduleRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
