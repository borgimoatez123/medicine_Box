import "../../models/medication_model.dart";
import "../../utils/constants/api_constants.dart";
import "../api_client.dart";

class MedicationRepository {
  MedicationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Set<String> _allowedCreateKeys = <String>{
    "patientId",
    "name",
    "dosage",
    "form",
    "quantity",
    "expiryDate",
  };

  static const Set<String> _allowedUpdateKeys = <String>{
    "name",
    "dosage",
    "form",
    "quantity",
    "expiryDate",
  };

  static const Map<String, String> _canonicalAliases = <String, String>{
    "patient_id": "patientId",
    "patient": "patientId",
    "medicationName": "name",
    "medication_name": "name",
    "title": "name",
    "dose": "dosage",
    "amount": "dosage",
    "type": "form",
    "medicationForm": "form",
    "medication_form": "form",
    "qty": "quantity",
    "count": "quantity",
    "expirationDate": "expiryDate",
    "expiration_date": "expiryDate",
    "exp_date": "expiryDate",
    "expDate": "expiryDate",
  };

  static String? _canonicalKey(String key) {
    final String k = key.trim();
    if (_allowedCreateKeys.contains(k)) return k;
    final String? aliased = _canonicalAliases[k];
    if (aliased != null && _allowedCreateKeys.contains(aliased)) return aliased;
    return null;
  }

  static dynamic _coerceValue(String canonical, dynamic value) {
    if (value == null) return null;
    if (canonical == "patientId" || canonical == "name" || canonical == "dosage") {
      final String s = value.toString().trim();
      return s.isEmpty ? null : s;
    }
    if (canonical == "form") {
      if (value is MedicationForm) return value.backendValue;
      if (value is String) {
        final String s = value.trim();
        if (s.isEmpty) return null;
        final MedicationForm? form = s.toMedicationFormOrNull;
        return form?.backendValue;
      }
      return null;
    }
    if (canonical == "quantity") {
      if (value is int) return value;
      if (value is double) {
        if (!value.isFinite) return null;
        if (value == value.truncateToDouble()) return value.toInt();
        return value.round();
      }
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }
    if (canonical == "expiryDate") {
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
    return value;
  }

  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  static Map<String, dynamic> _sanitizeCreateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key);
      if (canonical == null) continue;
      if (!_allowedCreateKeys.contains(canonical)) continue;
      final dynamic coerced = _coerceValue(canonical, entry.value);
      if (canonical == "expiryDate") {
        if (input.containsKey(entry.key)) {
          body[canonical] = coerced;
        }
      } else if (coerced != null) {
        body[canonical] = coerced;
      }
    }
    final String? pid = body["patientId"]?.toString();
    if (pid == null || pid.trim().isEmpty) {
      throw MedicationRepositoryException("Missing patient id");
    }
    final String? name = body["name"]?.toString();
    if (name == null || name.trim().isEmpty) {
      throw MedicationRepositoryException("Medication name is required");
    }
    final String? dosage = body["dosage"]?.toString();
    if (dosage == null || dosage.trim().isEmpty) {
      throw MedicationRepositoryException("Dosage is required");
    }
    final int? qty = body["quantity"] is int ? body["quantity"] as int : null;
    if (qty == null) {
      throw MedicationRepositoryException("Quantity must be at least 1");
    }
    body["patientId"] = pid.trim();
    body["name"] = name.trim();
    body["dosage"] = dosage.trim();
    body["form"] ??= MedicationForm.tablet.backendValue;
    return body;
  }

  static Map<String, dynamic> _sanitizeUpdateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key);
      if (canonical == null) continue;
      if (!_allowedUpdateKeys.contains(canonical)) continue;
      if (canonical == "patientId") continue;
      final dynamic value = entry.value;
      if (canonical == "expiryDate") {
        if (value == null) {
          body["expiryDate"] = null;
          continue;
        }
        final dynamic coerced = _coerceValue(canonical, value);
        if (coerced != null) body["expiryDate"] = coerced;
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
    if (status == 404) return "Medication not found";
    if (e is ApiClientException) return e.message;
    if (e is MedicationRepositoryException) return e.message;
    return e.toString();
  }

  MedicationPageResult _extractPage(dynamic decoded) {
    List<MedicationModel> items = <MedicationModel>[];
    MedicationPaginationMeta? meta;
    if (decoded == null) {
      return (items: items, meta: meta);
    }
    if (decoded is List) {
      items = decoded
          .whereType<Map<String, dynamic>>()
          .map(MedicationModel.fromJson)
          .toList(growable: false);
      return (items: items, meta: meta);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        items = data
            .whereType<Map<String, dynamic>>()
            .map(MedicationModel.fromJson)
            .toList(growable: false);
      } else if (data is Map<String, dynamic>) {
        final dynamic innerItems = data["medications"] ?? data["items"];
        if (innerItems is List) {
          items = innerItems
              .whereType<Map<String, dynamic>>()
              .map(MedicationModel.fromJson)
              .toList(growable: false);
        }
      }
      final dynamic metaRaw = decoded["meta"];
      if (metaRaw is Map<String, dynamic>) {
        meta = MedicationPaginationMeta.fromJson(metaRaw);
      }
    }
    return (items: items, meta: meta);
  }

  Future<MedicationPageResult> listMyMedications({
    String? patientId,
    int? page,
    int? limit,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    final String? pid = patientId?.trim();
    if (pid != null && pid.isNotEmpty) query["patientId"] = pid;
    if (page != null && page > 0) query["page"] = page.toString();
    if (limit != null && limit > 0) query["limit"] = limit.toString();
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.medications,
        queryParameters: query.isEmpty ? null : query,
      );
      return _extractPage(decoded);
    } catch (e) {
      throw MedicationRepositoryException(_friendly(e));
    }
  }

  Future<List<MedicationModel>> getMedicationsByPatient(String patientId) async {
    final String pid = patientId.trim();
    if (pid.isEmpty) {
      throw MedicationRepositoryException("Missing patient id");
    }
    final MedicationPageResult result = await listMyMedications(patientId: pid);
    return List<MedicationModel>.of(result.items);
  }

  Future<MedicationModel> getMedicationById(String medicationId) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationRepositoryException("Missing medication id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.medications}/$mid",
      );
      if (decoded == null) {
        throw MedicationRepositoryException("Medication not found");
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
        throw MedicationRepositoryException("Medication not found");
      }
      return MedicationModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw MedicationRepositoryException("Medication not found");
      }
      if (e is MedicationRepositoryException) rethrow;
      throw MedicationRepositoryException(_friendly(e));
    }
  }

  Future<MedicationModel> createMedication(CreateMedicationRequest request) async {
    final Map<String, dynamic> body = _sanitizeCreateBody(request.toJson());
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.medications,
        body: body,
      );
      if (decoded == null) {
        throw MedicationRepositoryException("Failed to create medication");
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
        throw MedicationRepositoryException("Failed to create medication");
      }
      return MedicationModel.fromJson(json);
    } catch (e) {
      if (e is MedicationRepositoryException) rethrow;
      throw MedicationRepositoryException(_friendly(e));
    }
  }

  Future<MedicationModel> updateMedication(
    String medicationId,
    UpdateMedicationRequest request,
  ) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationRepositoryException("Missing medication id");
    }
    final Map<String, dynamic> body = _sanitizeUpdateBody(request.body);
    if (body.isEmpty) {
      return getMedicationById(mid);
    }
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.medications}/$mid",
        body: body,
      );
      if (decoded == null) {
        return getMedicationById(mid);
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
        return getMedicationById(mid);
      }
      return MedicationModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw MedicationRepositoryException("Medication not found");
      }
      if (e is MedicationRepositoryException) rethrow;
      throw MedicationRepositoryException(_friendly(e));
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationRepositoryException("Missing medication id");
    }
    try {
      await _apiClient.delete("${ApiConstants.medications}/$mid");
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw MedicationRepositoryException("Medication not found");
      }
      if (e is MedicationRepositoryException) rethrow;
      throw MedicationRepositoryException(_friendly(e));
    }
  }
}

class MedicationRepositoryException implements Exception {
  MedicationRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
