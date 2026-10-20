import "dart:io";

import "package:http/http.dart" as http;

import "../api_client.dart";
import "../../models/patient.dart";
import "../../utils/constants/api_constants.dart";

class PatientAvatarResult {
  const PatientAvatarResult({required this.avatarUrl, this.patient});

  final String? avatarUrl;
  final Patient? patient;
}

class PatientRepository {
  PatientRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Set<String> _allowedCreateKeys = <String>{
    "fullName",
    "dateOfBirth",
    "gender",
    "weightKg",
    "heightCm",
    "bloodType",
    "allergies",
    "notes",
    "avatarUrl",
  };

  static const Set<String> _allowedUpdateKeys = <String>{
    "fullName",
    "dateOfBirth",
    "gender",
    "weightKg",
    "heightCm",
    "bloodType",
    "allergies",
    "notes",
    "avatarUrl",
  };

  static String? _canonicalKey(String key) {
    final String k = key.trim();
    switch (k) {
      case "full_name":
      case "fullname":
        return "fullName";
      case "date_of_birth":
      case "birthDate":
      case "dob":
        return "dateOfBirth";
      case "sex":
        return "gender";
      case "weight":
      case "weight_kg":
        return "weightKg";
      case "height":
      case "height_cm":
        return "heightCm";
      case "blood_group":
      case "bloodGroup":
        return "bloodType";
      case "allergy":
        return "allergies";
      case "medical_notes":
      case "medicalNotes":
      case "note":
        return "notes";
      case "avatar":
      case "profileImage":
      case "photo":
        return "avatarUrl";
    }
    return k;
  }

  Map<String, dynamic> _sanitizeCreateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> out = <String, dynamic>{};
    input.forEach((String rawKey, dynamic value) {
      final String? canonical = _canonicalKey(rawKey);
      if (canonical == null) return;
      if (!_allowedCreateKeys.contains(canonical)) return;
      final dynamic cleaned = _cleanValue(canonical, value);
      if (_shouldOmitForCreate(canonical, cleaned)) return;
      out[canonical] = cleaned;
    });
    if (!out.containsKey("fullName") ||
        out["fullName"].toString().trim().isEmpty) {
      throw PatientRepositoryException("fullName is required");
    }
    return out;
  }

  Map<String, dynamic> _sanitizeUpdateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> out = <String, dynamic>{};
    input.forEach((String rawKey, dynamic value) {
      final String? canonical = _canonicalKey(rawKey);
      if (canonical == null) return;
      if (!_allowedUpdateKeys.contains(canonical)) return;
      final dynamic cleaned = _cleanValue(canonical, value);
      if (canonical == "avatarUrl") {
        out[canonical] = cleaned;
        return;
      }
      if (_shouldOmitForUpdate(canonical, cleaned)) return;
      out[canonical] = cleaned;
    });
    return out;
  }

  static bool _shouldOmitForCreate(String key, dynamic value) {
    if (key == "avatarUrl") return false;
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  static bool _shouldOmitForUpdate(String key, dynamic value) {
    if (key == "avatarUrl") return false;
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  static dynamic _cleanValue(String canonical, dynamic value) {
    if (value == null) {
      return null;
    }
    if (canonical == "fullName" ||
        canonical == "gender" ||
        canonical == "bloodType" ||
        canonical == "allergies" ||
        canonical == "notes") {
      if (value is String) return value.trim();
      final String s = value.toString().trim();
      return s.isEmpty ? "" : s;
    }
    if (canonical == "avatarUrl") {
      if (value is String) {
        final String s = value.trim();
        return s.isEmpty ? null : s;
      }
      return null;
    }
    if (canonical == "dateOfBirth") {
      if (value is DateTime) return _formatDate(value);
      if (value is String) {
        final String s = value.trim();
        if (s.isEmpty) return null;
        final DateTime? d = DateTime.tryParse(s);
        if (d != null) return _formatDate(d);
        return s;
      }
      return null;
    }
    if (canonical == "weightKg") {
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    }
    if (canonical == "heightCm") {
      if (value is int) return value;
      if (value is double) {
        if (value.isFinite && value == value.truncateToDouble()) {
          return value.toInt();
        }
        return value.round();
      }
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }
    return value;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  int? _httpStatus(dynamic exception) {
    if (exception is ApiHttpException) return exception.statusCode;
    return null;
  }

  Future<Patient> createPatient(Map<String, dynamic> input) async {
    final Map<String, dynamic> body = _sanitizeCreateBody(input);
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.patients,
        body: body,
      );
      final Patient? created = _extractSinglePatient(decoded);
      if (created == null || created.id.isEmpty) {
        throw PatientRepositoryException(
          "Unable to parse created patient response",
        );
      }
      return created;
    } on PatientRepositoryException {
      rethrow;
    } catch (e) {
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<PatientPageResult> listMyPatients({int page = 1, int? limit}) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    final int p = page < 1 ? 1 : page;
    query["page"] = p.toString();
    if (limit != null) {
      final int l = limit < 1 ? 1 : limit;
      query["limit"] = l.toString();
    }
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.patients,
        queryParameters: query,
      );
      final PatientPageResult result = _extractPage(decoded);
      final List<Patient> sorted = List<Patient>.of(result.items)
        ..sort((Patient a, Patient b) {
          final DateTime? da = a.createdAt;
          final DateTime? db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
      return (items: sorted, meta: result.meta);
    } catch (e) {
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<Patient> getPatientById(String patientId) async {
    final String pId = patientId.trim();
    if (pId.isEmpty) {
      throw PatientRepositoryException("Missing patient id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.patients}/$pId",
      );
      final Patient? patient = _extractSinglePatient(decoded);
      if (patient == null || patient.id.isEmpty) {
        throw PatientRepositoryException("Patient not found");
      }
      return patient;
    } on PatientRepositoryException {
      rethrow;
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 404) {
        throw PatientRepositoryException("Patient not found");
      }
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<Patient> updatePatient(
    String patientId,
    Map<String, dynamic> patch,
  ) async {
    final String pId = patientId.trim();
    if (pId.isEmpty) {
      throw PatientRepositoryException("Missing patient id");
    }
    final Map<String, dynamic> body = _sanitizeUpdateBody(patch);
    if (body.isEmpty) {
      throw PatientRepositoryException("No fields provided for update");
    }
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.patients}/$pId",
        body: body,
      );
      final Patient? updated = _extractSinglePatient(decoded);
      if (updated == null || updated.id.isEmpty) {
        throw PatientRepositoryException(
          "Unable to parse updated patient response",
        );
      }
      return updated;
    } on PatientRepositoryException {
      rethrow;
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 404) {
        throw PatientRepositoryException("Patient not found");
      }
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<void> deletePatient(String patientId) async {
    final String pId = patientId.trim();
    if (pId.isEmpty) {
      throw PatientRepositoryException("Missing patient id");
    }
    try {
      await _apiClient.delete("${ApiConstants.patients}/$pId");
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 404) {
        throw PatientRepositoryException("Patient not found");
      }
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<PatientAvatarResult> uploadPatientAvatar(
    String patientId,
    File imageFile,
  ) async {
    final String pId = patientId.trim();
    if (pId.isEmpty) {
      throw PatientRepositoryException("Missing patient id");
    }
    if (!imageFile.existsSync()) {
      throw PatientRepositoryException("Selected image file does not exist");
    }
    try {
      final int length = await imageFile.length();
      final String? filename = _extractFilename(imageFile);
      final http.MultipartFile multipartFile =
          await http.MultipartFile.fromPath(
            "image",
            imageFile.path,
            filename: filename,
            contentType: _suggestMime(filename),
          );
      if (length != multipartFile.length) {
        // Trust the MultipartFile length when different.
      }
      final dynamic decoded = await _apiClient.postMultipart(
        "${ApiConstants.patients}/$pId/avatar",
        files: <http.MultipartFile>[multipartFile],
      );
      final Patient? patient = _extractSinglePatient(decoded);
      final String? avatarUrl =
          _extractAvatarUrl(decoded) ?? patient?.avatarUrl;
      if (avatarUrl == null || avatarUrl.trim().isEmpty) {
        throw PatientRepositoryException(
          "Unable to read avatar URL from upload response",
        );
      }
      return PatientAvatarResult(avatarUrl: avatarUrl.trim(), patient: patient);
    } on PatientRepositoryException {
      rethrow;
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 404) {
        throw PatientRepositoryException("Patient not found");
      }
      if (status == 400) {
        final String msg = e.toString().toLowerCase();
        if (msg.contains("large") || msg.contains("size")) {
          throw PatientRepositoryException("File too large. Maximum is 5 MB.");
        }
        if (msg.contains("format") ||
            msg.contains("unsupported") ||
            msg.contains("type")) {
          throw PatientRepositoryException("Unsupported image format.");
        }
      }
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  Future<void> deletePatientAvatar(String patientId) async {
    final String pId = patientId.trim();
    if (pId.isEmpty) {
      throw PatientRepositoryException("Missing patient id");
    }
    try {
      await _apiClient.delete("${ApiConstants.patients}/$pId/avatar");
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 404) {
        throw PatientRepositoryException("Patient not found");
      }
      throw PatientRepositoryException(_prettify(e.toString()));
    }
  }

  PatientPageResult _extractPage(dynamic decoded) {
    List<Patient> items = <Patient>[];
    PatientPaginationMeta? meta;

    if (decoded is List) {
      items = decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => Patient.fromJson(e))
          .toList();
      return (items: items, meta: null);
    }

    if (decoded is Map<String, dynamic>) {
      final dynamic rawData = decoded["data"];
      if (rawData is List) {
        items = rawData
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> e) => Patient.fromJson(e))
            .toList();
      } else if (rawData is Map<String, dynamic>) {
        final dynamic innerList =
            rawData["patients"] ?? rawData["items"] ?? rawData["data"];
        if (innerList is List) {
          items = innerList
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => Patient.fromJson(e))
              .toList();
        }
      }

      final dynamic rawMeta = decoded["meta"];
      if (rawMeta is Map<String, dynamic>) {
        meta = PatientPaginationMeta.fromJson(rawMeta);
      }
    }

    return (items: items, meta: meta);
  }

  Patient? _extractSinglePatient(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is Map<String, dynamic>) {
        final dynamic inner = data["patient"] ?? data["item"] ?? data["record"];
        if (inner is Map<String, dynamic>) return Patient.fromJson(inner);
        if (data.containsKey("id") || data.containsKey("_id")) {
          return Patient.fromJson(data);
        }
      }
      final dynamic direct =
          decoded["patient"] ?? decoded["item"] ?? decoded["record"];
      if (direct is Map<String, dynamic>) return Patient.fromJson(direct);
      if (decoded.containsKey("id") || decoded.containsKey("_id")) {
        return Patient.fromJson(decoded);
      }
    }
    return null;
  }

  String? _extractFilename(File file) {
    final String path = file.path.trim();
    if (path.isEmpty) return null;
    final String base = path.split(RegExp(r"[\\/]")).last;
    return base.trim().isEmpty ? null : base.trim();
  }

  String? _extractAvatarUrl(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>) {
      final List<dynamic> candidates = <dynamic>[
        decoded["avatarUrl"],
        decoded["avatar_url"],
        decoded["avatar"],
        decoded["profileImage"],
        decoded["photo"],
        decoded["data"] is Map<String, dynamic>
            ? decoded["data"]["avatarUrl"]
            : null,
        decoded["data"] is Map<String, dynamic>
            ? decoded["data"]["avatar_url"]
            : null,
        decoded["data"] is Map<String, dynamic>
            ? decoded["data"]["avatar"]
            : null,
      ];
      for (final dynamic c in candidates) {
        final String? s = c?.toString();
        if (s != null && s.trim().isNotEmpty) return s.trim();
      }
    }
    return null;
  }

  static final Map<String, String> _mimeByExtension = <String, String>{
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".jfif": "image/jpeg",
    ".pjpeg": "image/jpeg",
    ".pjp": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
  };

  http.MediaType? _suggestMime(String? filename) {
    final String fn = (filename ?? "").trim().toLowerCase();
    if (fn.isEmpty) return null;
    for (final MapEntry<String, String> e in _mimeByExtension.entries) {
      if (fn.endsWith(e.key)) {
        final List<String> parts = e.value.split("/");
        if (parts.length != 2) continue;
        return http.MediaType(parts[0], parts[1]);
      }
    }
    return null;
  }

  static String _prettify(String raw) {
    final String m = raw.trim();
    if (m.isEmpty) return "Unexpected error";
    return m;
  }
}

class PatientRepositoryException implements Exception {
  PatientRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
