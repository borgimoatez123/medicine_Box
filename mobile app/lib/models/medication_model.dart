import "dart:math" as math;

import "package:flutter/material.dart";

import "../utils/app_colors.dart";

enum MedicationForm { tablet, capsule, liquid, injection, cream, powder, other }

extension MedicationFormX on MedicationForm {
  String get backendValue {
    switch (this) {
      case MedicationForm.tablet:
        return "TABLET";
      case MedicationForm.capsule:
        return "CAPSULE";
      case MedicationForm.liquid:
        return "LIQUID";
      case MedicationForm.injection:
        return "INJECTION";
      case MedicationForm.cream:
        return "CREAM";
      case MedicationForm.powder:
        return "POWDER";
      case MedicationForm.other:
        return "OTHER";
    }
  }

  String get displayLabel {
    switch (this) {
      case MedicationForm.tablet:
        return "Tablet";
      case MedicationForm.capsule:
        return "Capsule";
      case MedicationForm.liquid:
        return "Liquid";
      case MedicationForm.injection:
        return "Injection";
      case MedicationForm.cream:
        return "Cream";
      case MedicationForm.powder:
        return "Powder";
      case MedicationForm.other:
        return "Other";
    }
  }
}

extension MedicationFormFromString on String {
  MedicationForm? get toMedicationFormOrNull {
    final String raw = trim().toUpperCase();
    switch (raw) {
      case "TABLET":
        return MedicationForm.tablet;
      case "CAPSULE":
        return MedicationForm.capsule;
      case "LIQUID":
        return MedicationForm.liquid;
      case "INJECTION":
        return MedicationForm.injection;
      case "CREAM":
        return MedicationForm.cream;
      case "POWDER":
        return MedicationForm.powder;
      case "OTHER":
      case "INHALER":
        return MedicationForm.other;
      default:
        return null;
    }
  }
}

const List<MedicationForm> kSupportedMedicationForms = <MedicationForm>[
  MedicationForm.tablet,
  MedicationForm.capsule,
  MedicationForm.liquid,
  MedicationForm.injection,
  MedicationForm.cream,
  MedicationForm.powder,
  MedicationForm.other,
];

class MedicationPaginationMeta {
  const MedicationPaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory MedicationPaginationMeta.fromJson(Map<String, dynamic> json) {
    final int page = (json["page"] as num?)?.toInt() ?? 1;
    final int limit = (json["limit"] as num?)?.toInt() ?? 20;
    final int total = (json["total"] as num?)?.toInt() ?? 0;
    final int totalPages =
        (json["totalPages"] as num?)?.toInt() ??
        (limit <= 0 ? 0 : (total / limit).ceil());
    return MedicationPaginationMeta(
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

typedef MedicationPageResult = ({
  List<MedicationModel> items,
  MedicationPaginationMeta? meta,
});

class MedicationModel {
  const MedicationModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.form,
    required this.quantity,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final MedicationForm form;
  final int quantity;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static MedicationForm _parseForm(dynamic value, MedicationForm fallback) {
    if (value == null) return fallback;
    final MedicationForm? parsed = value.toString().toMedicationFormOrNull;
    return parsed ?? fallback;
  }

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json["id"] ?? json["_id"];
    final String id = rawId?.toString() ?? "";
    final String patientId =
        (json["patientId"] ?? json["patient_id"] ?? json["patient"] ?? "")
            .toString()
            .trim();
    final String name =
        (json["name"] ?? json["medicationName"] ?? json["title"] ?? "")
            .toString()
            .trim();
    final String dosage =
        (json["dosage"] ?? json["dose"] ?? json["amount"] ?? "")
            .toString()
            .trim();
    final MedicationForm form = _parseForm(json["form"], MedicationForm.tablet);
    final int quantity = math.max(0, (json["quantity"] as num?)?.toInt() ?? 0);
    final DateTime? expiryDate = _tryParseDate(
      json["expiryDate"] ?? json["expirationDate"] ?? json["exp_date"],
    );
    final DateTime? createdAt = _tryParseDate(json["createdAt"]);
    final DateTime? updatedAt = _tryParseDate(json["updatedAt"]);
    return MedicationModel(
      id: id,
      patientId: patientId,
      name: name,
      dosage: dosage,
      form: form,
      quantity: quantity,
      expiryDate: expiryDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "patientId": patientId,
      "name": name,
      "dosage": dosage,
      "form": form.backendValue,
      "quantity": quantity,
      if (expiryDate != null) "expiryDate": _formatDate(expiryDate!),
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
    };
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  String? get frequency => null;
  DateTime? get startDate => null;
  DateTime? get endDate => null;
  String? get status => null;
  String? get notes => null;
  String? get userId => null;

  MedicationModel copyWith({
    String? id,
    String? name,
    String? dosage,
    MedicationForm? form,
    int? quantity,
    DateTime? expiryDate,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      patientId: patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CreateMedicationRequest {
  const CreateMedicationRequest({
    required this.patientId,
    required this.name,
    required this.dosage,
    this.form = MedicationForm.tablet,
    required this.quantity,
    this.expiryDate,
  });

  final String patientId;
  final String name;
  final String dosage;
  final MedicationForm form;
  final int quantity;
  final DateTime? expiryDate;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = <String, dynamic>{
      "patientId": patientId.trim(),
      "name": name.trim(),
      "dosage": dosage.trim(),
      "form": form.backendValue,
      "quantity": quantity,
    };
    if (expiryDate != null) {
      body["expiryDate"] = _formatDate(expiryDate!);
    }
    return body;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}

class UpdateMedicationRequest {
  const UpdateMedicationRequest({
    this.name,
    this.dosage,
    this.form,
    this.quantity,
    this.clearExpiryDate = false,
    this.expiryDate,
  });

  final String? name;
  final String? dosage;
  final MedicationForm? form;
  final int? quantity;
  final DateTime? expiryDate;
  final bool clearExpiryDate;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (name != null) body["name"] = name!.trim();
    if (dosage != null) body["dosage"] = dosage!.trim();
    if (form != null) body["form"] = form!.backendValue;
    if (quantity != null) body["quantity"] = quantity!;
    if (clearExpiryDate) {
      body["expiryDate"] = null;
    } else if (expiryDate != null) {
      body["expiryDate"] = _formatDate(expiryDate!);
    }
    return body;
  }

  bool get isEmpty => body.isEmpty;
  Map<String, dynamic> get body => toJson();

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}

extension MedicationStatusColorX on String? {
  Color? get medicationStatusColor {
    final String? raw = this;
    if (raw == null) return null;
    final String s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == "taken" || s == "completed" || s == "active") {
      return AppColors.success;
    }
    if (s == "pending" || s == "scheduled") return AppColors.info;
    if (s == "missed" || s == "overdue") return AppColors.error;
    if (s == "paused" || s == "hold") return AppColors.warning;
    return null;
  }
}
