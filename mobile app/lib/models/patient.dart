import "dart:math";

typedef PatientPageResult = ({
  List<Patient> items,
  PatientPaginationMeta? meta,
});

final class PatientPaginationMeta {
  const PatientPaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PatientPaginationMeta.fromJson(Map<String, dynamic> json) {
    final int p = _asInt(json["page"]) ?? 1;
    final int l = _asInt(json["limit"]) ?? 20;
    final int t = _asInt(json["total"]) ?? 0;
    final int tp = _asInt(json["totalPages"]) ?? (l <= 0 ? 1 : (t / l).ceil());
    return PatientPaginationMeta(page: p, limit: l, total: t, totalPages: tp);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "page": page,
      "limit": limit,
      "total": total,
      "totalPages": totalPages,
    };
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class Patient {
  const Patient({
    required this.id,
    this.userId,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.bloodType,
    this.allergies,
    this.notes,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.medicationsCount,
  });

  final String id;
  final String? userId;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? weightKg;
  final int? heightCm;
  final String? bloodType;
  final String? allergies;
  final String? notes;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? medicationsCount;

  String get firstname {
    final List<String> parts = fullName.trim().split(RegExp(r"\s+"));
    if (parts.isEmpty || parts.first.isEmpty) return "";
    return parts.first;
  }

  String get lastname {
    final List<String> parts = fullName.trim().split(RegExp(r"\s+"));
    if (parts.length <= 1) return "";
    return parts.sublist(1).join(" ").trim();
  }

  String get profileImage => avatarUrl ?? "";

  String? get phone => null;

  double? get weight => weightKg;
  double? get height => heightCm?.toDouble();
  String? get bloodGroup => bloodType;
  String? get medicalNotes => notes;
  DateTime? get birthDate => dateOfBirth;

  String get fullNameDisplay =>
      fullName.trim().isEmpty ? "(Unknown)" : fullName.trim();

  String get initialsDisplay {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r"\s+"))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return "?";
    String firstChar(String s) {
      final String trimmed = s.trim();
      if (trimmed.isEmpty) return "";
      final int cu = trimmed.runes.first;
      return String.fromCharCode(cu).toUpperCase();
    }

    if (parts.length == 1) {
      final String only = parts.first.trim();
      if (only.isEmpty) return "?";
      final Runes runes = only.runes;
      if (runes.length >= 2) {
        return (String.fromCharCode(runes.elementAt(0)) +
                String.fromCharCode(runes.elementAt(1)))
            .toUpperCase();
      }
      return firstChar(only);
    }
    final String first = firstChar(parts.first);
    final String last = firstChar(parts.last);
    if (first.isEmpty && last.isEmpty) return "?";
    return "$first$last";
  }

  int? get age {
    final DateTime? bd = dateOfBirth;
    if (bd == null) return null;
    final DateTime now = DateTime.now();
    int years = now.year - bd.year;
    final DateTime thisYearBirthday = DateTime(now.year, bd.month, bd.day);
    if (thisYearBirthday.isAfter(now)) years -= 1;
    return max(years, 0);
  }

  Patient copyWith({
    String? id,
    String? userId,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    int? heightCm,
    String? bloodType,
    String? allergies,
    String? notes,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? medicationsCount,
  }) {
    return Patient(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medicationsCount: medicationsCount ?? this.medicationsCount,
    );
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json["id"] ?? json["_id"];
    final String id = rawId?.toString() ?? "";

    final dynamic rawUserId = json["userId"] ?? json["user_id"] ?? json["user"];
    final String? userId = rawUserId?.toString();

    final String fullName = _pickFullName(json);

    final DateTime? dateOfBirth = _tryParseDate(
      json["dateOfBirth"] ??
          json["birthDate"] ??
          json["dob"] ??
          json["date_of_birth"],
    );
    final String? gender = (json["gender"] ?? json["sex"])?.toString().trim();
    final double? weightKg = _tryParseDouble(
      json["weightKg"] ?? json["weight"],
    );
    final int? heightCm = _tryParseInt(json["heightCm"] ?? json["height"]);
    final String? bloodType =
        (json["bloodType"] ?? json["bloodGroup"] ?? json["blood_group"])
            ?.toString()
            .trim();
    final String? allergies = (json["allergies"] ?? json["allergy"])
        ?.toString();
    final String? notes =
        (json["notes"] ??
                json["medicalNotes"] ??
                json["medical_notes"] ??
                json["note"])
            ?.toString();
    final String? avatarUrl =
        (json["avatarUrl"] ??
                json["avatar"] ??
                json["profileImage"] ??
                json["photo"])
            ?.toString();
    final DateTime? createdAt = _tryParseDate(json["createdAt"]);
    final DateTime? updatedAt = _tryParseDate(json["updatedAt"]);
    final int? medicationsCount = _tryParseMedicationsCount(json);

    return Patient(
      id: id,
      userId: userId,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      gender: gender == null || gender.isEmpty ? null : gender,
      weightKg: weightKg,
      heightCm: heightCm,
      bloodType: bloodType == null || bloodType.isEmpty ? null : bloodType,
      allergies: allergies == null || allergies.trim().isEmpty
          ? null
          : allergies.trim(),
      notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
      avatarUrl: avatarUrl == null || avatarUrl.trim().isEmpty
          ? null
          : avatarUrl.trim(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      medicationsCount: medicationsCount,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      "id": id,
      if (userId != null) "userId": userId,
      "fullName": fullName,
      if (dateOfBirth != null) "dateOfBirth": _formatDate(dateOfBirth!),
      if (gender != null && gender!.trim().isNotEmpty) "gender": gender!.trim(),
      if (weightKg != null) "weightKg": weightKg,
      if (heightCm != null) "heightCm": heightCm,
      if (bloodType != null && bloodType!.trim().isNotEmpty)
        "bloodType": bloodType!.trim(),
      if (allergies != null && allergies!.trim().isNotEmpty)
        "allergies": allergies!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) "notes": notes!.trim(),
      "avatarUrl": avatarUrl,
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
      if (medicationsCount != null) "medicationsCount": medicationsCount,
    };
    return out;
  }

  static String _pickFullName(Map<String, dynamic> json) {
    final dynamic direct = json["fullName"] ?? json["full_name"];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final String fn =
        (json["firstName"] ?? json["firstname"] ?? json["first_name"] ?? "")
            .toString()
            .trim();
    final String ln =
        (json["lastName"] ?? json["lastname"] ?? json["last_name"] ?? "")
            .toString()
            .trim();
    final String combined = <String>[
      fn,
      ln,
    ].where((String s) => s.isNotEmpty).join(" ").trim();
    if (combined.isNotEmpty) return combined;
    final dynamic name = json["name"];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }
    return "";
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String s = value.toString().trim();
    if (s.isEmpty) return null;
    final DateTime? d = DateTime.tryParse(s);
    if (d != null) return d;
    try {
      final List<String> parts = s.split("-");
      if (parts.length == 3) {
        final int? y = int.tryParse(parts[0]);
        final int? m = int.tryParse(parts[1]);
        final int? d2 = int.tryParse(parts[2]);
        if (y != null && m != null && d2 != null) {
          return DateTime(y, m, d2);
        }
      }
    } catch (_) {}
    return null;
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static int? _tryParseMedicationsCount(Map<String, dynamic> json) {
    final dynamic direct =
        json["medicationsCount"] ??
        json["medications_count"] ??
        json["medicationCount"];
    final int? d = _tryParseInt(direct);
    if (d != null) return d;
    final dynamic meds =
        json["medications"] ?? json["meds"] ?? json["patientMedications"];
    if (meds is List) return meds.length;
    return null;
  }
}
