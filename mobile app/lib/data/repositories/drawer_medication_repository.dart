import "../../models/drawer_medication_model.dart";
import "../../utils/constants/api_constants.dart";
import "../api_client.dart";

class DrawerMedicationRepository {
  DrawerMedicationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Set<String> _allowedCreateKeys = <String>{
    "drawerId",
    "medicationId",
    "quantity",
    "missingQuantity",
  };

  static const Set<String> _allowedUpdateKeys = <String>{"isActive"};

  static const Map<String, String> _canonicalAliases = <String, String>{
    "drawer_id": "drawerId",
    "drawer": "drawerId",
    "medication_id": "medicationId",
    "medication": "medicationId",
    "is_active": "isActive",
    "active": "isActive",
    "missing_quantity": "missingQuantity",
    "remainingQuantity": "missingQuantity",
    "remaining_quantity": "missingQuantity",
    "overflowQuantity": "missingQuantity",
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

  static int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final int? parsed = int.tryParse(value.toString().trim());
    return parsed;
  }

  static dynamic _coerceValue(String canonical, dynamic value) {
    if (canonical == "drawerId" || canonical == "medicationId") {
      if (value == null) return null;
      final String s = value.toString().trim();
      return s.isEmpty ? null : s;
    }
    if (canonical == "isActive") {
      if (value is bool) return value;
      if (value is String) {
        final String s = value.trim().toLowerCase();
        if (s == "true" || s == "1" || s == "yes") return true;
        if (s == "false" || s == "0" || s == "no") return false;
      }
      return null;
    }
    if (canonical == "quantity" || canonical == "missingQuantity") {
      final int? n = _coerceInt(value);
      if (n == null) return null;
      if (n < 0) return null;
      return n;
    }
    return value;
  }

  static Map<String, dynamic> _sanitizeCreateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key, isCreate: true);
      if (canonical == null) continue;
      final dynamic coerced = _coerceValue(canonical, entry.value);
      if (coerced != null) body[canonical] = coerced;
    }
    final String? did = body["drawerId"]?.toString();
    if (did == null || did.trim().isEmpty) {
      throw DrawerMedicationRepositoryException("Missing drawer id");
    }
    final String? mid = body["medicationId"]?.toString();
    if (mid == null || mid.trim().isEmpty) {
      throw DrawerMedicationRepositoryException("Missing medication id");
    }
    final Object? q = body["quantity"];
    if (q is! int) {
      throw DrawerMedicationRepositoryException("Missing or invalid quantity");
    }
    final Object? mq = body["missingQuantity"];
    if (mq is! int) {
      throw DrawerMedicationRepositoryException(
        "Missing or invalid missingQuantity",
      );
    }
    body["drawerId"] = did.trim();
    body["medicationId"] = mid.trim();
    body["quantity"] = q;
    body["missingQuantity"] = mq;
    return body;
  }

  static Map<String, dynamic> sanitizeCreateBodyPublic(
    Map<String, dynamic> input,
  ) => _sanitizeCreateBody(input);

  static Map<String, dynamic> _sanitizeUpdateBody(Map<String, dynamic> input) {
    final Map<String, dynamic> body = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in input.entries) {
      final String? canonical = _canonicalKey(entry.key, isCreate: false);
      if (canonical == null) continue;
      final dynamic coerced = _coerceValue(canonical, entry.value);
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
    if (status == 404) return "Drawer or medication not found";
    if (status == 409)
      return "Assignment conflict: drawer or medication already assigned";
    if (status == 400) return "Invalid assignment payload";
    if (status == 401) return "Authentication failure";
    if (e is ApiClientException) return e.message;
    if (e is DrawerMedicationRepositoryException) return e.message;
    return e.toString();
  }

  List<DrawerMedicationModel> _extractList(dynamic decoded) {
    if (decoded == null) return const <DrawerMedicationModel>[];
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DrawerMedicationModel.fromJson)
          .toList(growable: false);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(DrawerMedicationModel.fromJson)
            .toList(growable: false);
      }
      if (data is Map<String, dynamic>) {
        final dynamic inner =
            data["assignments"] ?? data["items"] ?? data["drawerMedications"];
        if (inner is List) {
          return inner
              .whereType<Map<String, dynamic>>()
              .map(DrawerMedicationModel.fromJson)
              .toList(growable: false);
        }
      }
    }
    return const <DrawerMedicationModel>[];
  }

  DrawerMedicationModel? _extractOne(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      Map<String, dynamic>? json;
      if (data is Map<String, dynamic>) {
        json = data;
      } else {
        json = decoded;
      }
      return DrawerMedicationModel.fromJson(json);
    }
    return null;
  }

  Future<List<DrawerMedicationModel>> getAssignments({
    String? drawerId,
    String? medicationId,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    final String? did = drawerId?.trim();
    if (did != null && did.isNotEmpty) query["drawerId"] = did;
    final String? mid = medicationId?.trim();
    if (mid != null && mid.isNotEmpty) query["medicationId"] = mid;
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.drawerMedications,
        queryParameters: query.isEmpty ? null : query,
      );
      return _extractList(decoded);
    } catch (e) {
      throw DrawerMedicationRepositoryException(_friendly(e));
    }
  }

  Future<List<DrawerMedicationModel>> getAssignmentsByDrawer(
    String drawerId,
  ) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw DrawerMedicationRepositoryException("Missing drawer id");
    }
    return getAssignments(drawerId: did);
  }

  Future<List<DrawerMedicationModel>> getAssignmentsByMedication(
    String medicationId,
  ) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw DrawerMedicationRepositoryException("Missing medication id");
    }
    return getAssignments(medicationId: mid);
  }

  Future<DrawerMedicationModel> getAssignmentById(String assignmentId) async {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationRepositoryException("Missing assignment id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.drawerMedications}/$aid",
      );
      final DrawerMedicationModel? model = _extractOne(decoded);
      if (model == null) {
        throw DrawerMedicationRepositoryException("Assignment not found");
      }
      return model;
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw DrawerMedicationRepositoryException("Assignment not found");
      }
      if (e is DrawerMedicationRepositoryException) rethrow;
      throw DrawerMedicationRepositoryException(_friendly(e));
    }
  }

  Future<DrawerMedicationModel> createAssignment(
    CreateDrawerMedicationRequest request,
  ) async {
    final Map<String, dynamic> body = _sanitizeCreateBody(request.toJson());
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.drawerMedications,
        body: body,
      );
      final DrawerMedicationModel? created = _extractOne(decoded);
      if (created == null) {
        throw DrawerMedicationRepositoryException(
          "Failed to create drawer medication assignment",
        );
      }
      return created;
    } catch (e) {
      if (e is DrawerMedicationRepositoryException) rethrow;
      throw DrawerMedicationRepositoryException(_friendly(e));
    }
  }

  Future<DrawerMedicationModel> updateAssignment(
    String assignmentId,
    UpdateDrawerMedicationRequest request,
  ) async {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationRepositoryException("Missing assignment id");
    }
    final Map<String, dynamic> body = _sanitizeUpdateBody(request.body);
    if (body.isEmpty) {
      return getAssignmentById(aid);
    }
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.drawerMedications}/$aid",
        body: body,
      );
      final DrawerMedicationModel? updated = _extractOne(decoded);
      if (updated == null) {
        return getAssignmentById(aid);
      }
      return updated;
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw DrawerMedicationRepositoryException("Assignment not found");
      }
      if (e is DrawerMedicationRepositoryException) rethrow;
      throw DrawerMedicationRepositoryException(_friendly(e));
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationRepositoryException("Missing assignment id");
    }
    try {
      await _apiClient.delete("${ApiConstants.drawerMedications}/$aid");
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw DrawerMedicationRepositoryException("Assignment not found");
      }
      if (e is DrawerMedicationRepositoryException) rethrow;
      throw DrawerMedicationRepositoryException(_friendly(e));
    }
  }
}

class DrawerMedicationRepositoryException implements Exception {
  DrawerMedicationRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
