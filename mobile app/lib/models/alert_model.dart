import "package:flutter/material.dart";

class AlertModel {
  const AlertModel({
    required this.id,
    this.patientId,
    this.userId,
    required this.title,
    this.description,
    this.date,
    this.time,
    this.status,
    this.priority,
    this.payload,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? patientId;
  final String? userId;
  final String title;
  final String? description;
  final DateTime? date;
  final String? time;
  final String? status;
  final String? priority;
  final Map<String, dynamic>? payload;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json["id"] ?? json["_id"];
    return AlertModel(
      id: rawId?.toString() ?? "",
      patientId: (json["patientId"] ?? json["patient_id"] ?? json["patient"])
          ?.toString(),
      userId: (json["userId"] ?? json["user_id"] ?? json["user"])?.toString(),
      title:
          (json["title"] ?? json["label"] ?? json["name"] ?? "").toString(),
      description:
          (json["description"] ?? json["message"] ?? json["body"] ?? json["note"])
              ?.toString(),
      date: _tryParseDate(
        json["date"] ?? json["scheduledAt"] ?? json["dueAt"] ?? json["createdAt"],
      ),
      time: (json["time"] ?? json["scheduledTime"])?.toString(),
      status: (json["status"] ?? json["state"])?.toString(),
      priority: (json["priority"] ?? json["level"])?.toString(),
      payload: json["payload"] is Map<String, dynamic>
          ? json["payload"] as Map<String, dynamic>
          : null,
      createdAt: _tryParseDate(json["createdAt"]),
      updatedAt: _tryParseDate(json["updatedAt"]),
    );
  }

  AlertModel copyWith({
    String? id,
    String? patientId,
    String? userId,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? status,
    String? priority,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      if (patientId != null) "patientId": patientId,
      if (userId != null) "userId": userId,
      "title": title,
      if (description != null) "description": description,
      if (date != null) "date": date!.toIso8601String(),
      if (time != null) "time": time,
      if (status != null) "status": status,
      if (priority != null) "priority": priority,
      if (payload != null) "payload": payload,
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
    };
  }
}

enum AlertStatus { read, unread, pending, completed, unknown }

enum AlertPriority { high, medium, low, unknown }

extension AlertModelHelpers on AlertModel {
  AlertStatus get alertStatus {
    final String? raw = status?.trim().toLowerCase();
    switch (raw) {
      case "read":
      case "seen":
        return AlertStatus.read;
      case "unread":
      case "new":
        return AlertStatus.unread;
      case "pending":
      case "scheduled":
        return AlertStatus.pending;
      case "completed":
      case "done":
      case "finished":
        return AlertStatus.completed;
      default:
        return AlertStatus.unknown;
    }
  }

  AlertPriority get alertPriority {
    final String? raw = priority?.trim().toLowerCase();
    switch (raw) {
      case "high":
      case "critical":
      case "urgent":
        return AlertPriority.high;
      case "medium":
      case "normal":
      case "moderate":
        return AlertPriority.medium;
      case "low":
      case "minor":
        return AlertPriority.low;
      default:
        return AlertPriority.unknown;
    }
  }

  Color? get priorityColor {
    switch (alertPriority) {
      case AlertPriority.high:
        return const Color(0xFFEF4444);
      case AlertPriority.medium:
        return const Color(0xFFF59E0B);
      case AlertPriority.low:
        return const Color(0xFF22C55E);
      case AlertPriority.unknown:
        return null;
    }
  }
}
