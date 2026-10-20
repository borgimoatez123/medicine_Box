import "../../models/drawer_command_response_model.dart";
import "../../models/drawer_model.dart";
import "../../models/medicine_box_model.dart";
import "../../models/medicine_box_sensor_model.dart";
import "../api_client.dart";
import "../../utils/constants/api_constants.dart";

class SmartBoxRepository {
  SmartBoxRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Map<String, dynamic> _canonicalizeKeys(Map<String, dynamic> raw) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final Map<String, String> aliases = <String, String>{
      "id": "id",
      "device_id": "deviceId",
      "deviceID": "deviceId",
      "deviceId": "deviceId",
      "device_token": "deviceToken",
      "deviceToken": "deviceToken",
      "name": "name",
      "status": "status",
      "number_of_drawers": "numberOfDrawers",
      "numberOfDrawers": "numberOfDrawers",
      "drawer_capacity": "drawerCapacity",
      "drawerCapacity": "drawerCapacity",
      "user_id": "userId",
      "userId": "userId",
      "medicine_box_id": "medicineBoxId",
      "medicineBoxId": "medicineBoxId",
      "drawer_number": "drawerNumber",
      "drawerNumber": "drawerNumber",
      "medication_id": "medicationId",
      "medicationId": "medicationId",
      "last_dispensed_at": "lastDispensedAt",
      "lastDispensedAt": "lastDispensedAt",
      "firmware_version": "firmwareVersion",
      "firmwareVersion": "firmwareVersion",
      "last_seen_at": "lastSeenAt",
      "lastSeenAt": "lastSeenAt",
      "created_at": "createdAt",
      "createdAt": "createdAt",
      "updated_at": "updatedAt",
      "updatedAt": "updatedAt",
      "page": "page",
      "limit": "limit",
      "total": "total",
      "total_pages": "totalPages",
      "totalPages": "totalPages",
    };
    raw.forEach((String key, dynamic value) {
      final String canonical = aliases[key] ?? key;
      out[canonical] = value;
    });
    return out;
  }

  static const Set<String> _allowedActivateKeys = <String>{
    "deviceId",
    "deviceToken",
  };

  static const Set<String> _allowedUpdateBoxKeys = <String>{"name"};
  static const Set<String> _allowedUpdateDrawerKeys = <String>{"status"};

  Map<String, dynamic> _sanitizeActivateBody(Map<String, dynamic> body) {
    final Map<String, dynamic> c = _canonicalizeKeys(body);
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String k in c.keys) {
      if (_allowedActivateKeys.contains(k)) {
        out[k] = c[k];
      }
    }
    return out;
  }

  Map<String, dynamic> _sanitizeUpdateBoxBody(Map<String, dynamic> body) {
    final Map<String, dynamic> c = _canonicalizeKeys(body);
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String k in c.keys) {
      if (_allowedUpdateBoxKeys.contains(k)) out[k] = c[k];
    }
    return out;
  }

  Map<String, dynamic> _sanitizeUpdateDrawerBody(Map<String, dynamic> body) {
    final Map<String, dynamic> c = _canonicalizeKeys(body);
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String k in c.keys) {
      if (_allowedUpdateDrawerKeys.contains(k)) out[k] = c[k];
    }
    return out;
  }

  int? _httpStatus(Object e) {
    final String s = e.toString().toLowerCase();
    if (s.contains("401")) return 401;
    if (s.contains("404")) return 404;
    if (s.contains("409")) return 409;
    if (s.contains("400")) return 400;
    if (s.contains("500")) return 500;
    return null;
  }

  String? _extractBackendMessage(Object e) {
    if (e is ApiHttpException) {
      final String m = e.message.trim();
      return m.isNotEmpty ? m : null;
    }
    return null;
  }

  String _friendly(Object e) {
    if (e is SmartBoxRepositoryException) return e.message;
    final int? status = _httpStatus(e);
    if (status == 401) return "Invalid device credentials.";
    if (status == 404) return "Medicine box not found.";
    if (status == 409) {
      final String? backendMsg = _extractBackendMessage(e);
      if (backendMsg != null) {
        final String lower = backendMsg.toLowerCase();
        if (lower.contains("maintenance")) {
          return "Your medicine box is under maintenance.";
        }
        if (lower.contains("offline") || lower.contains("not connected")) {
          return "Your medicine box is offline. Please make sure your device is connected.";
        }
        if (lower.contains("inactive") ||
            lower.contains("not active") ||
            lower.contains("activate")) {
          return "Your medicine box is not active. Please activate your device first.";
        }
        return backendMsg;
      }
      return "Medicine box already activated.";
    }
    final String s = e.toString();
    if (s.trim().isEmpty) return "Request failed.";
    return s;
  }

  Map<String, dynamic>? _unwrapData(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is Map<String, dynamic>) {
        return _canonicalizeKeys(data);
      }
      return _canonicalizeKeys(decoded);
    }
    return null;
  }

  MedicineBoxPageResult _extractBoxPage(dynamic decoded) {
    final MedicineBoxPaginationMeta meta = const MedicineBoxPaginationMeta(
      page: 1,
      limit: 20,
      total: 0,
      totalPages: 0,
    );
    final List<MedicineBoxModel> items = <MedicineBoxModel>[];
    if (decoded is List) {
      for (final dynamic d in decoded) {
        if (d is Map<String, dynamic>) {
          items.add(MedicineBoxModel.fromJson(_canonicalizeKeys(d)));
        }
      }
      return (items: items, meta: meta);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        for (final dynamic d in data) {
          if (d is Map<String, dynamic>) {
            items.add(MedicineBoxModel.fromJson(_canonicalizeKeys(d)));
          }
        }
      } else {
        if (data is Map<String, dynamic>) {
          final dynamic maybeList = data["items"] ?? data["data"];
          if (maybeList is List) {
            for (final dynamic d in maybeList) {
              if (d is Map<String, dynamic>) {
                items.add(MedicineBoxModel.fromJson(_canonicalizeKeys(d)));
              }
            }
          }
        }
      }
      final dynamic metaRaw = decoded["meta"];
      if (metaRaw is Map<String, dynamic>) {
        return (
          items: items,
          meta: MedicineBoxPaginationMeta.fromJson(_canonicalizeKeys(metaRaw)),
        );
      }
    }
    return (items: items, meta: meta);
  }

  DrawerPageResult _extractDrawerPage(dynamic decoded) {
    final DrawerPaginationMeta meta = const DrawerPaginationMeta(
      page: 1,
      limit: 20,
      total: 0,
      totalPages: 0,
    );
    final List<DrawerModel> items = <DrawerModel>[];
    if (decoded is List) {
      for (final dynamic d in decoded) {
        if (d is Map<String, dynamic>) {
          items.add(DrawerModel.fromJson(_canonicalizeKeys(d)));
        }
      }
      return (items: items, meta: meta);
    }
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded["data"];
      if (data is List) {
        for (final dynamic d in data) {
          if (d is Map<String, dynamic>) {
            items.add(DrawerModel.fromJson(_canonicalizeKeys(d)));
          }
        }
      }
      final dynamic metaRaw = decoded["meta"];
      if (metaRaw is Map<String, dynamic>) {
        return (
          items: items,
          meta: DrawerPaginationMeta.fromJson(_canonicalizeKeys(metaRaw)),
        );
      }
    }
    return (items: items, meta: meta);
  }

  Future<MedicineBoxModel> activateDevice(ActivateBoxRequest req) async {
    final String did = req.deviceId.trim();
    final String tok = req.deviceToken.trim();
    if (did.isEmpty || tok.isEmpty) {
      throw SmartBoxRepositoryException(
        "Invalid medicine box QR code — missing deviceId or deviceToken.",
      );
    }
    final Map<String, dynamic> body = _sanitizeActivateBody(req.toJson());
    try {
      final dynamic decoded = await _apiClient.post(
        ApiConstants.activateMedicineBox,
        body: body,
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Failed to activate medicine box.");
      }
      return MedicineBoxModel.fromJson(json);
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 401) {
        throw SmartBoxRepositoryException("Invalid device credentials.");
      }
      if (status == 404) {
        throw SmartBoxRepositoryException("Medicine box not found.");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<MedicineBoxPageResult> listMedicineBoxes({
    int? page,
    int? limit,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    if (page != null && page > 0) query["page"] = page.toString();
    if (limit != null && limit > 0) query["limit"] = limit.toString();
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.medicineBoxes,
        queryParameters: query.isEmpty ? null : query,
      );
      return _extractBoxPage(decoded);
    } catch (e) {
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<List<MedicineBoxModel>> loadMyActiveBoxes({int limit = 50}) async {
    final MedicineBoxPageResult r = await listMedicineBoxes(
      page: 1,
      limit: limit,
    );
    return List<MedicineBoxModel>.from(r.items);
  }

  Future<MedicineBoxModel> getMedicineBoxById(String id) async {
    final String bid = id.trim();
    if (bid.isEmpty) {
      throw SmartBoxRepositoryException("Missing medicine box id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.medicineBoxes}/$bid",
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Medicine box not found");
      }
      return MedicineBoxModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw SmartBoxRepositoryException("Medicine box not found");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<MedicineBoxModel> updateBoxName({
    required String boxId,
    required UpdateMedicineBoxNameRequest request,
  }) async {
    final String bid = boxId.trim();
    if (bid.isEmpty) {
      throw SmartBoxRepositoryException("Missing medicine box id");
    }
    if (request.isEmpty) {
      throw SmartBoxRepositoryException("Name cannot be empty.");
    }
    final Map<String, dynamic> body = _sanitizeUpdateBoxBody(request.body);
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.medicineBoxes}/$bid",
        body: body,
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Failed to update medicine box");
      }
      return MedicineBoxModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw SmartBoxRepositoryException("Medicine box not found");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<DrawerPageResult> listDrawers({
    required String medicineBoxId,
    int? page,
    int? limit,
  }) async {
    final String mbid = medicineBoxId.trim();
    if (mbid.isEmpty) {
      throw SmartBoxRepositoryException("Missing medicine box id");
    }
    final Map<String, dynamic> query = <String, dynamic>{"medicineBoxId": mbid};
    if (page != null && page > 0) query["page"] = page.toString();
    if (limit != null && limit > 0) query["limit"] = limit.toString();
    try {
      final dynamic decoded = await _apiClient.get(
        ApiConstants.drawers,
        queryParameters: query,
      );
      return _extractDrawerPage(decoded);
    } catch (e) {
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<List<DrawerModel>> getDrawersForBox(String medicineBoxId) async {
    final DrawerPageResult r = await listDrawers(
      medicineBoxId: medicineBoxId,
      limit: 200,
    );
    return List<DrawerModel>.from(r.items);
  }

  Future<DrawerModel> getDrawerById(String drawerId) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxRepositoryException("Missing drawer id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.drawers}/$did",
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Drawer not found");
      }
      return DrawerModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw SmartBoxRepositoryException("Drawer not found");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<DrawerModel> updateDrawerStatus({
    required String drawerId,
    required UpdateDrawerStatusRequest request,
  }) async {
    final String did = drawerId.trim();
    if (did.isEmpty) throw SmartBoxRepositoryException("Missing drawer id");
    final Map<String, dynamic> body = _sanitizeUpdateDrawerBody(request.body);
    try {
      final dynamic decoded = await _apiClient.patch(
        "${ApiConstants.drawers}/$did",
        body: body,
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Drawer status update failed.");
      }
      return DrawerModel.fromJson(json);
    } catch (e) {
      if (_httpStatus(e) == 404) {
        throw SmartBoxRepositoryException("Drawer not found.");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(_friendly(e));
    }
  }

  Future<MedicineBoxSensorStateResponse> getMedicineBoxSensors(
    String medicineBoxId,
  ) async {
    final String mbid = medicineBoxId.trim();
    if (mbid.isEmpty) {
      throw SmartBoxRepositoryException("Missing medicine box id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.medicineBoxes}/$mbid/sensors",
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        return MedicineBoxSensorStateResponse(
          medicineBoxId: mbid,
          drawers: const <DrawerSensorState>[],
        );
      }
      return MedicineBoxSensorStateResponse.fromJson(json);
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 401) {
        throw SmartBoxRepositoryException(
          "Your session has expired. Please log in again.",
        );
      }
      if (status == 404) {
        throw SmartBoxRepositoryException("Medicine box unavailable");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      final String msg = _friendly(e);
      if (msg.toLowerCase().contains("not found") ||
          msg.toLowerCase().contains("no longer own")) {
        throw SmartBoxRepositoryException("Medicine box unavailable");
      }
      throw SmartBoxRepositoryException(msg);
    }
  }

  Future<DrawerSensorState> getDrawerSensors(String drawerId) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxRepositoryException("Missing drawer id");
    }
    try {
      final dynamic decoded = await _apiClient.get(
        "${ApiConstants.drawers}/$did/sensors",
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        return DrawerSensorState(
          drawerId: did,
          drawerIndex: 1,
          fireDetected: false,
        );
      }
      final DrawerSensorState state = DrawerSensorState.fromSingleDrawerJson(
        json,
      );
      if (state.drawerId.isEmpty) {
        return DrawerSensorState(
          drawerId: did,
          drawerIndex: state.drawerIndex,
          medicineBoxId: state.medicineBoxId,
          temperature: state.temperature,
          humidity: state.humidity,
          fireDetected: state.fireDetected,
          updatedAt: state.updatedAt,
        );
      }
      return state;
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 401) {
        throw SmartBoxRepositoryException(
          "Your session has expired. Please log in again.",
        );
      }
      if (status == 404) {
        throw SmartBoxRepositoryException("Drawer unavailable.");
      }
      if (e is SmartBoxRepositoryException) rethrow;
      final String msg = _friendly(e);
      if (msg.toLowerCase().contains("not found") ||
          msg.toLowerCase().contains("no longer own") ||
          msg.toLowerCase().contains("another user")) {
        throw SmartBoxRepositoryException("Drawer unavailable.");
      }
      throw SmartBoxRepositoryException("Unable to load drawer sensor data.");
    }
  }

  Future<DrawerCommandResponse> _sendDrawerCommand(
    String drawerId,
    String action, {
    String? reason,
  }) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxRepositoryException("Missing drawer id");
    }
    final String path = action;
    try {
      final Map<String, dynamic> body = <String, dynamic>{};
      if (reason != null && reason.trim().isNotEmpty)
        body["reason"] = reason.trim();
      final dynamic decoded = await _apiClient.post(
        "${ApiConstants.drawers}/$did/$path",
        body: body,
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException(
          "Unexpected empty response from server.",
        );
      }
      final DrawerCommandResponse r = DrawerCommandResponse.fromJson(json);
      if (r.commandId.isEmpty) {
        throw SmartBoxRepositoryException(
          "Server did not return a command id.",
        );
      }
      return r;
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 401) {
        throw SmartBoxRepositoryException(
          "Your session has expired. Please log in again.",
        );
      }
      if (status == 404) {
        throw SmartBoxRepositoryException(
          "This drawer is no longer available.",
        );
      }
      if (status == 400) {
        throw SmartBoxRepositoryException(
          "This drawer is not connected to a medicine box device.",
        );
      }
      if (e is SmartBoxRepositoryException) rethrow;
      final String msg = _friendly(e);
      final String lower = msg.toLowerCase();
      if (lower.contains("not found") ||
          lower.contains("no longer own") ||
          lower.contains("another user")) {
        throw SmartBoxRepositoryException(
          "This drawer is no longer available.",
        );
      }
      if (lower.contains("device") &&
          (lower.contains("not associated") ||
              lower.contains("not connected") ||
              lower.contains("missing"))) {
        throw SmartBoxRepositoryException(
          "This drawer is not connected to a medicine box device.",
        );
      }
      if (lower.contains("timeout") || lower.contains("timed out")) {
        throw SmartBoxRepositoryException(
          "The request timed out. Please try again.",
        );
      }
      if (lower.contains("socket") ||
          lower.contains("dns") ||
          lower.contains("unreachable") ||
          lower.contains("failed host") ||
          lower.contains("failed to connect")) {
        throw SmartBoxRepositoryException(
          "Unable to connect to the medicine box server.\nPlease check your connection and try again.",
        );
      }
      throw SmartBoxRepositoryException(
        "Unable to send the drawer command. Please try again.",
      );
    }
  }

  Future<DrawerCommandResponse> openDrawer(String drawerId, {String? reason}) {
    return _sendDrawerCommand(
      drawerId,
      "open",
      reason: reason ?? "Manual open by user",
    );
  }

  Future<DrawerCommandResponse> closeDrawer(String drawerId, {String? reason}) {
    return _sendDrawerCommand(
      drawerId,
      "close",
      reason: reason ?? "Manual close by user",
    );
  }

  Future<MedicineBoxModel> unassignMedicineBox(String boxId) async {
    final String bid = boxId.trim();
    if (bid.isEmpty) {
      throw SmartBoxRepositoryException("Missing medicine box id.");
    }
    try {
      final dynamic decoded = await _apiClient.post(
        "${ApiConstants.medicineBoxes}/$bid/unassign",
      );
      final Map<String, dynamic>? json = _unwrapData(decoded);
      if (json == null) {
        throw SmartBoxRepositoryException("Failed to unassign medicine box.");
      }
      return MedicineBoxModel.fromJson(json);
    } catch (e) {
      final int? status = _httpStatus(e);
      if (status == 401) {
        throw SmartBoxRepositoryException(
          "Your session has expired. Please log in again.",
        );
      }
      if (status == 404) {
        throw SmartBoxRepositoryException(
          "Medicine box not found or you no longer own it.",
        );
      }
      if (status == 400 || status == 409) {
        final String msg = e.toString().trim();
        if (msg.isNotEmpty &&
            msg.toLowerCase().contains("already") == false &&
            msg.length < 220) {
          throw SmartBoxRepositoryException(msg);
        }
        throw SmartBoxRepositoryException(
          "Unable to unassign the medicine box. No changes were applied.",
        );
      }
      if (e is SmartBoxRepositoryException) rethrow;
      throw SmartBoxRepositoryException(
        "Unable to unassign the medicine box. No changes were applied.",
      );
    }
  }
}

class SmartBoxRepositoryException implements Exception {
  SmartBoxRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
