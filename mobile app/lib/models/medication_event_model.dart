import "package:flutter/material.dart";

import "../utils/app_colors.dart";

/// Status of a medication event as reported by the backend.
///
/// We do not assume the only possible values. Unknown statuses fall back
/// to a safe representation based on the raw value.
enum MedicationEventStatus { taken, missed, pending, failed, unknown }

extension MedicationEventStatusX on String {
  MedicationEventStatus get toMedicationEventStatus {
    final String raw = trim().toUpperCase();
    switch (raw) {
      case "TAKEN":
      case "COMPLETED":
      case "ADMINISTERED":
        return MedicationEventStatus.taken;
      case "MISSED":
      case "SKIPPED":
        return MedicationEventStatus.missed;
      case "PENDING":
      case "SCHEDULED":
      case "DUE":
        return MedicationEventStatus.pending;
      case "FAILED":
      case "ERROR":
        return MedicationEventStatus.failed;
      default:
        return MedicationEventStatus.unknown;
    }
  }
}

extension MedicationEventStatusLabel on MedicationEventStatus {
  /// Human-readable label. Never returns an empty string.
  String get label {
    switch (this) {
      case MedicationEventStatus.taken:
        return "Medication recorded as taken";
      case MedicationEventStatus.missed:
        return "Missed medication";
      case MedicationEventStatus.pending:
        return "Pending";
      case MedicationEventStatus.failed:
        return "Medication administration failed";
      case MedicationEventStatus.unknown:
        return "Unknown";
    }
  }

  /// Whether this status represents an actionable alert (missed / failed).
  /// A `taken` event is history, never a warning.
  bool get isAlert =>
      this == MedicationEventStatus.missed ||
      this == MedicationEventStatus.failed;

  /// Whether this event is a historical "taken" record (positive indicator).
  bool get isHistoryTaken => this == MedicationEventStatus.taken;

  Color? get color {
    switch (this) {
      case MedicationEventStatus.taken:
        return AppColors.success;
      case MedicationEventStatus.missed:
        return AppColors.error;
      case MedicationEventStatus.pending:
        return AppColors.info;
      case MedicationEventStatus.failed:
        return AppColors.error;
      case MedicationEventStatus.unknown:
        return AppColors.hintText;
    }
  }
}

class MedicationEventPagination {
  const MedicationEventPagination({
    required this.limit,
    required this.offset,
    required this.total,
  });

  final int limit;
  final int offset;
  final int total;

  factory MedicationEventPagination.fromJson(Map<String, dynamic> json) {
    return MedicationEventPagination(
      limit: (json["limit"] as num?)?.toInt() ?? 0,
      offset: (json["offset"] as num?)?.toInt() ?? 0,
      total: (json["total"] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{"limit": limit, "offset": offset, "total": total};
  }
}

typedef MedicationEventListResult = ({
  List<MedicationEventModel> events,
  MedicationEventPagination? pagination,
});

/// A single medication event returned by `GET /devices/medication-events`.
class MedicationEventModel {
  const MedicationEventModel({
    required this.id,
    this.deviceId,
    this.patientId,
    this.scheduleId,
    this.drawerId,
    this.medicationId,
    required this.status,
    this.quantityTaken,
    this.quantityBefore,
    this.quantityAfter,
    this.scheduledAt,
    this.completedAt,
    this.createdAt,
    this.occurrenceDate,
    this.occurrenceTime,
  });

  final String id;
  final String? deviceId;
  final String? patientId;
  final String? scheduleId;
  final String? drawerId;
  final String? medicationId;
  final String status;
  final int? quantityTaken;
  final int? quantityBefore;
  final int? quantityAfter;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final String? occurrenceDate;
  final String? occurrenceTime;

  MedicationEventStatus get eventStatus => status.toMedicationEventStatus;

  bool get isTaken => eventStatus == MedicationEventStatus.taken;
  bool get isMissed => eventStatus == MedicationEventStatus.missed;
  bool get isAlert => eventStatus.isAlert;
  bool get isHistoryTaken => eventStatus.isHistoryTaken;

  /// Sort key for chronological ordering (newest first).
  DateTime get sortDateTime {
    if (completedAt != null) return completedAt!;
    if (scheduledAt != null) return scheduledAt!;
    if (createdAt != null) return createdAt!;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) {
      if (!value.isFinite) return null;
      if (value == value.truncateToDouble()) return value.toInt();
      return value.round();
    }
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  factory MedicationEventModel.fromJson(Map<String, dynamic> json) {
    return MedicationEventModel(
      id: (json["id"] ?? json["_id"])?.toString().trim() ?? "",
      deviceId: (json["deviceId"] ?? json["device_id"])?.toString().trim(),
      patientId: (json["patientId"] ?? json["patient_id"])?.toString().trim(),
      scheduleId: (json["scheduleId"] ?? json["schedule_id"])
          ?.toString()
          .trim(),
      drawerId: (json["drawerId"] ?? json["drawer_id"])?.toString().trim(),
      medicationId: (json["medicationId"] ?? json["medication_id"])
          ?.toString()
          .trim(),
      status: (json["status"] ?? json["state"] ?? "").toString().trim(),
      quantityTaken: _tryParseInt(
        json["quantityTaken"] ?? json["quantity_taken"],
      ),
      quantityBefore: _tryParseInt(
        json["quantityBefore"] ?? json["quantity_before"],
      ),
      quantityAfter: _tryParseInt(
        json["quantityAfter"] ?? json["quantity_after"],
      ),
      scheduledAt: _tryParseDate(json["scheduledAt"] ?? json["scheduled_at"]),
      completedAt: _tryParseDate(json["completedAt"] ?? json["completed_at"]),
      createdAt: _tryParseDate(json["createdAt"]),
      occurrenceDate: (json["occurrenceDate"] ?? json["occurrence_date"])
          ?.toString(),
      occurrenceTime: (json["occurrenceTime"] ?? json["occurrence_time"])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      if (deviceId != null) "deviceId": deviceId,
      if (patientId != null) "patientId": patientId,
      if (scheduleId != null) "scheduleId": scheduleId,
      if (drawerId != null) "drawerId": drawerId,
      if (medicationId != null) "medicationId": medicationId,
      "status": status,
      if (quantityTaken != null) "quantityTaken": quantityTaken,
      if (quantityBefore != null) "quantityBefore": quantityBefore,
      if (quantityAfter != null) "quantityAfter": quantityAfter,
      if (scheduledAt != null) "scheduledAt": scheduledAt!.toIso8601String(),
      if (completedAt != null) "completedAt": completedAt!.toIso8601String(),
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (occurrenceDate != null) "occurrenceDate": occurrenceDate,
      if (occurrenceTime != null) "occurrenceTime": occurrenceTime,
    };
  }
}

/// Parses the nested API response:
/// `{ status, statusCode, data: { events: [...], pagination: {...} } }`
/// Tolerates missing/wrapping keys and unexpected formats.
MedicationEventListResult parseMedicationEventListResponse(dynamic decoded) {
  List<dynamic> rawEvents = <dynamic>[];
  Map<String, dynamic>? rawPagination;

  if (decoded is Map<String, dynamic>) {
    final dynamic data = decoded["data"];
    if (data is Map<String, dynamic>) {
      final dynamic ev = data["events"] ?? data["items"];
      if (ev is List) rawEvents = ev;
      final dynamic pg = data["pagination"];
      if (pg is Map<String, dynamic>) rawPagination = pg;
    } else if (data is List) {
      rawEvents = data;
    } else {
      final dynamic ev = decoded["events"] ?? decoded["items"];
      if (ev is List) rawEvents = ev;
      final dynamic pg = decoded["pagination"];
      if (pg is Map<String, dynamic>) rawPagination = pg;
    }
  } else if (decoded is List) {
    rawEvents = decoded;
  }

  final List<MedicationEventModel> events = rawEvents
      .whereType<Map<String, dynamic>>()
      .map((Map<String, dynamic> e) => MedicationEventModel.fromJson(e))
      .where((MedicationEventModel e) => e.id.isNotEmpty)
      .toList();

  final MedicationEventPagination? pagination = rawPagination == null
      ? null
      : MedicationEventPagination.fromJson(rawPagination);

  return (events: events, pagination: pagination);
}
