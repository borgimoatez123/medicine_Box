import "dart:math" as math;

enum ScheduleStatus { active, paused, completed, archived }

extension ScheduleStatusX on ScheduleStatus {
  String get backendValue {
    switch (this) {
      case ScheduleStatus.active:
        return "ACTIVE";
      case ScheduleStatus.paused:
        return "PAUSED";
      case ScheduleStatus.completed:
        return "COMPLETED";
      case ScheduleStatus.archived:
        return "ARCHIVED";
    }
  }

  String get displayLabel {
    switch (this) {
      case ScheduleStatus.active:
        return "Active";
      case ScheduleStatus.paused:
        return "Paused";
      case ScheduleStatus.completed:
        return "Completed";
      case ScheduleStatus.archived:
        return "Archived";
    }
  }
}

extension ScheduleStatusFromString on String {
  ScheduleStatus? get toScheduleStatusOrNull {
    final String raw = trim().toUpperCase();
    switch (raw) {
      case "ACTIVE":
        return ScheduleStatus.active;
      case "PAUSED":
        return ScheduleStatus.paused;
      case "COMPLETED":
        return ScheduleStatus.completed;
      case "ARCHIVED":
        return ScheduleStatus.archived;
      default:
        return null;
    }
  }
}

const List<ScheduleStatus> kSupportedScheduleStatuses = <ScheduleStatus>[
  ScheduleStatus.active,
  ScheduleStatus.paused,
  ScheduleStatus.completed,
  ScheduleStatus.archived,
];

class SchedulePaginationMeta {
  const SchedulePaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory SchedulePaginationMeta.fromJson(Map<String, dynamic> json) {
    final int page = (json["page"] as num?)?.toInt() ?? 1;
    final int limit = (json["limit"] as num?)?.toInt() ?? 20;
    final int total = (json["total"] as num?)?.toInt() ?? 0;
    final int totalPages =
        (json["totalPages"] as num?)?.toInt() ??
        (limit <= 0 ? 0 : (total / limit).ceil());
    return SchedulePaginationMeta(
      page: math.max(1, page),
      limit: math.max(1, limit),
      total: math.max(0, total),
      totalPages: math.max(0, totalPages),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "page": page,
      "limit": limit,
      "total": total,
      "totalPages": totalPages,
    };
  }
}

typedef SchedulePageResult = ({
  List<ScheduleModel> items,
  SchedulePaginationMeta? meta,
});

class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.medicationId,
    required this.dosage,
    required this.timesPerDay,
    required this.times,
    required this.startDate,
    required this.daysOfWeek,
    required this.status,
    required this.isActive,
    required this.refillReminder,
    this.medicationName,
    this.endDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicationId;
  final String dosage;
  final int timesPerDay;
  final List<String> times;
  final DateTime startDate;
  final DateTime? endDate;
  final List<int> daysOfWeek;
  final ScheduleStatus status;
  final bool isActive;
  final String? notes;
  final bool refillReminder;

  final String? medicationName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    final dynamic timesRaw = json["times"];
    final List<String> times = timesRaw is List
        ? timesRaw
              .map((dynamic e) => e?.toString() ?? "")
              .where((String s) => s.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final dynamic daysRaw = json["daysOfWeek"];
    final List<int> daysOfWeek = daysRaw is List
        ? daysRaw
              .map((dynamic e) {
                if (e is int) return e;
                if (e is num) return e.toInt();
                return int.tryParse(e?.toString() ?? "");
              })
              .whereType<int>()
              .where((int d) => d >= 1 && d <= 7)
              .toList(growable: false)
        : const <int>[];

    final String? startDateRaw = json["startDate"]?.toString();
    final DateTime startDate = startDateRaw != null && startDateRaw.isNotEmpty
        ? DateTime.tryParse(startDateRaw) ?? DateTime.now()
        : DateTime.now();

    final String? endDateRaw = json["endDate"]?.toString();
    final DateTime? endDate = endDateRaw != null && endDateRaw.isNotEmpty
        ? DateTime.tryParse(endDateRaw)
        : null;

    final int timesPerDay =
        (json["timesPerDay"] as num?)?.toInt() ?? math.max(1, times.length);

    final String? statusRaw = json["status"] as String?;
    final ScheduleStatus status =
        (statusRaw == null ? null : statusRaw.toScheduleStatusOrNull) ??
        ScheduleStatus.active;

    final bool isActive = json["isActive"] == true;
    final bool refillReminder = json["refillReminder"] == true;

    final String? createdAtRaw = json["createdAt"]?.toString();
    final String? updatedAtRaw = json["updatedAt"]?.toString();

    return ScheduleModel(
      id: (json["id"] as String?)?.toString() ?? "",
      medicationId: (json["medicationId"] as String?)?.toString() ?? "",
      dosage: (json["dosage"] as String?)?.toString() ?? "",
      timesPerDay: math.max(1, timesPerDay),
      times: times,
      startDate: startDate,
      endDate: endDate,
      daysOfWeek: daysOfWeek,
      status: status,
      isActive: isActive,
      notes: json["notes"] as String?,
      refillReminder: refillReminder,
      medicationName:
          (json["medicationName"] ?? json["medication_name"] ?? json["name"])
              as String?,
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      updatedAt: updatedAtRaw != null && updatedAtRaw.isNotEmpty
          ? DateTime.tryParse(updatedAtRaw)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "medicationId": medicationId,
      "dosage": dosage,
      "timesPerDay": timesPerDay,
      "times": List<String>.of(times),
      "startDate": _formatDate(startDate),
      if (endDate != null) "endDate": _formatDate(endDate!),
      "daysOfWeek": List<int>.of(daysOfWeek),
      "status": status.backendValue,
      "isActive": isActive,
      if (notes != null) "notes": notes,
      "refillReminder": refillReminder,
      if (medicationName != null) "medicationName": medicationName,
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
    };
  }

  ScheduleModel copyWith({
    String? id,
    String? medicationId,
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
    String? medicationName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      dosage: dosage ?? this.dosage,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      times: times ?? List<String>.of(this.times),
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      daysOfWeek: daysOfWeek ?? List<int>.of(this.daysOfWeek),
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      notes: clearNotes ? null : notes ?? this.notes,
      refillReminder: refillReminder ?? this.refillReminder,
      medicationName: medicationName ?? this.medicationName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}

class CreateScheduleRequest {
  const CreateScheduleRequest({
    required this.medicationId,
    required this.dosage,
    required this.startDate,
    this.timesPerDay,
    this.times,
    this.endDate,
    this.daysOfWeek,
    this.status = ScheduleStatus.active,
    this.isActive = true,
    this.notes,
    this.refillReminder,
  });

  final String medicationId;
  final String dosage;
  final DateTime startDate;
  final int? timesPerDay;
  final List<String>? times;
  final DateTime? endDate;
  final List<int>? daysOfWeek;
  final ScheduleStatus status;
  final bool isActive;
  final String? notes;
  final bool? refillReminder;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = <String, dynamic>{
      "medicationId": medicationId.trim(),
      "dosage": dosage.trim(),
      "startDate": _formatDate(startDate),
      "status": status.backendValue,
      "isActive": isActive,
    };
    if (timesPerDay != null) body["timesPerDay"] = timesPerDay!;
    if (times != null && times!.isNotEmpty) {
      body["times"] = List<String>.of(times!);
    }
    if (endDate != null) body["endDate"] = _formatDate(endDate!);
    if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
      body["daysOfWeek"] = List<int>.of(daysOfWeek!);
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      body["notes"] = notes!.trim();
    }
    if (refillReminder != null) body["refillReminder"] = refillReminder!;
    return body;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}

class UpdateScheduleRequest {
  UpdateScheduleRequest({
    this.dosage,
    this.timesPerDay,
    this.times,
    this.startDate,
    this.endDate,
    this.clearEndDate = false,
    this.daysOfWeek,
    this.status,
    this.isActive,
    this.notes,
    this.clearNotes = false,
    this.refillReminder,
  });

  final String? dosage;
  final int? timesPerDay;
  final List<String>? times;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool clearEndDate;
  final List<int>? daysOfWeek;
  final ScheduleStatus? status;
  final bool? isActive;
  final String? notes;
  final bool clearNotes;
  final bool? refillReminder;

  bool get isEmpty {
    if (dosage != null && dosage!.trim().isNotEmpty) return false;
    if (timesPerDay != null) return false;
    if (times != null && times!.isNotEmpty) return false;
    if (startDate != null) return false;
    if (endDate != null) return false;
    if (clearEndDate) return false;
    if (daysOfWeek != null) return false;
    if (status != null) return false;
    if (isActive != null) return false;
    if (notes != null) return false;
    if (clearNotes) return false;
    if (refillReminder != null) return false;
    return true;
  }

  Map<String, dynamic> get body {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (dosage != null) body["dosage"] = dosage!.trim();
    if (timesPerDay != null) body["timesPerDay"] = timesPerDay!;
    if (times != null) body["times"] = List<String>.of(times!);
    if (startDate != null) body["startDate"] = _formatDate(startDate!);
    if (clearEndDate) {
      body["endDate"] = null;
    } else if (endDate != null) {
      body["endDate"] = _formatDate(endDate!);
    }
    if (daysOfWeek != null) body["daysOfWeek"] = List<int>.of(daysOfWeek!);
    if (status != null) body["status"] = status!.backendValue;
    if (isActive != null) body["isActive"] = isActive!;
    if (clearNotes) {
      body["notes"] = null;
    } else if (notes != null) {
      body["notes"] = notes!.trim();
    }
    if (refillReminder != null) body["refillReminder"] = refillReminder!;
    return body;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}
