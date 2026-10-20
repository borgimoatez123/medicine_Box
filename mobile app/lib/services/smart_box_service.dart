import "dart:convert";

import "package:flutter/foundation.dart";

import "../data/repositories/smart_box_repository.dart";
import "../models/drawer_command_response_model.dart";
import "../models/drawer_model.dart";
import "../models/medicine_box_model.dart";
import "../models/medicine_box_sensor_model.dart";

class MedicineBoxQrPayload {
  const MedicineBoxQrPayload({
    required this.deviceId,
    required this.deviceToken,
  });

  final String deviceId;
  final String deviceToken;

  static MedicineBoxQrPayload parse(String rawPayload) {
    if (kDebugMode) {
      debugPrint("QR detected");
    }
    if (rawPayload.trim().isEmpty) {
      throw const InvalidMedicineBoxQrException();
    }
    final String raw = rawPayload.trim();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const InvalidMedicineBoxQrException();
    } catch (_) {
      throw const InvalidMedicineBoxQrException();
    }
    if (decoded is! Map<String, dynamic>) {
      throw const InvalidMedicineBoxQrException();
    }
    if (kDebugMode) {
      debugPrint("QR JSON parsed");
    }
    final Map<String, dynamic> map = decoded;
    final Object? deviceIdRaw = map["deviceId"];
    final Object? deviceTokenRaw = map["deviceToken"];

    final String? deviceIdString = deviceIdRaw is String ? deviceIdRaw : null;
    final String deviceId = (deviceIdString ?? "").trim();
    if (deviceId.isEmpty) {
      throw const MissingMedicineBoxDeviceIdException();
    }

    final String? deviceTokenString = deviceTokenRaw is String
        ? deviceTokenRaw
        : null;
    final String deviceToken = (deviceTokenString ?? "").trim();
    if (deviceToken.isEmpty) {
      throw const MissingMedicineBoxDeviceTokenException();
    }

    if (kDebugMode) {
      debugPrint("Medicine Box deviceId: $deviceId");
      debugPrint("deviceToken present: ${deviceToken.isNotEmpty}");
    }

    return MedicineBoxQrPayload(deviceId: deviceId, deviceToken: deviceToken);
  }
}

abstract class MedicineBoxQrParseException implements Exception {
  const MedicineBoxQrParseException();
  String get message;
  @override
  String toString() => message;
}

class InvalidMedicineBoxQrException extends MedicineBoxQrParseException {
  const InvalidMedicineBoxQrException();
  @override
  String get message => "Invalid medicine box QR code.";
}

class MissingMedicineBoxDeviceIdException extends MedicineBoxQrParseException {
  const MissingMedicineBoxDeviceIdException();
  @override
  String get message => "QR code does not contain a device ID.";
}

class MissingMedicineBoxDeviceTokenException
    extends MedicineBoxQrParseException {
  const MissingMedicineBoxDeviceTokenException();
  @override
  String get message => "QR code does not contain a valid device token.";
}

class SmartBoxService {
  SmartBoxService({SmartBoxRepository? repository})
    : _repository = repository ?? SmartBoxRepository();
  final SmartBoxRepository _repository;

  @Deprecated(
    "Use MedicineBoxQrPayload.parse(raw) which throws typed parse exceptions instead.",
  )
  ({String deviceId, String deviceToken})? parseDevicePayload(
    String rawPayload,
  ) {
    try {
      final MedicineBoxQrPayload p = MedicineBoxQrPayload.parse(rawPayload);
      return (deviceId: p.deviceId, deviceToken: p.deviceToken);
    } on MedicineBoxQrParseException {
      return null;
    }
  }

  Future<MedicineBoxModel> activateBox({
    required String deviceId,
    required String deviceToken,
  }) async {
    if (deviceId.trim().isEmpty) {
      throw SmartBoxServiceException(
        const MissingMedicineBoxDeviceIdException().message,
      );
    }
    if (deviceToken.trim().isEmpty) {
      throw SmartBoxServiceException(
        const MissingMedicineBoxDeviceTokenException().message,
      );
    }
    final ActivateBoxRequest request = ActivateBoxRequest(
      deviceId: deviceId.trim(),
      deviceToken: deviceToken.trim(),
    );
    try {
      return await _repository.activateDevice(request);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<List<MedicineBoxModel>> loadMyBoxes({int limit = 50}) async {
    try {
      return await _repository.loadMyActiveBoxes(limit: limit);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<MedicineBoxModel> getBox(String boxId) async {
    final String id = boxId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing medicine box id");
    try {
      return await _repository.getMedicineBoxById(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<MedicineBoxModel> renameBox(String boxId, String newName) async {
    final String id = boxId.trim();
    final String name = newName.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing medicine box id");
    if (name.isEmpty) throw SmartBoxServiceException("Name cannot be empty.");
    if (name.length > 64) {
      throw SmartBoxServiceException("Name must be 64 characters or fewer.");
    }
    final UpdateMedicineBoxNameRequest req = UpdateMedicineBoxNameRequest(
      name: name,
    );
    try {
      return await _repository.updateBoxName(boxId: id, request: req);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<List<DrawerModel>> loadDrawers(String medicineBoxId) async {
    final String id = medicineBoxId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing medicine box id");
    try {
      return await _repository.getDrawersForBox(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<DrawerModel> getDrawer(String drawerId) async {
    final String id = drawerId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing drawer id");
    try {
      return await _repository.getDrawerById(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<DrawerModel> updateDrawerStatus(
    String drawerId,
    DrawerStatus status,
  ) async {
    final String id = drawerId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing drawer id");
    final List<DrawerStatus> allowed = const <DrawerStatus>[
      DrawerStatus.empty,
      DrawerStatus.loaded,
      DrawerStatus.locked,
      DrawerStatus.dispensing,
      DrawerStatus.error,
    ];
    if (!allowed.contains(status)) {
      throw SmartBoxServiceException(
        "Invalid drawer status. Allowed values: EMPTY, LOADED, LOCKED, DISPENSING, ERROR.",
      );
    }
    final UpdateDrawerStatusRequest req = UpdateDrawerStatusRequest(
      status: status,
    );
    try {
      return await _repository.updateDrawerStatus(drawerId: id, request: req);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<MedicineBoxSensorStateResponse> loadSensorState(
    String medicineBoxId,
  ) async {
    final String id = medicineBoxId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing medicine box id");
    try {
      return await _repository.getMedicineBoxSensors(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<DrawerSensorState> loadDrawerSensorState(String drawerId) async {
    final String id = drawerId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing drawer id");
    try {
      return await _repository.getDrawerSensors(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<DrawerCommandResponse> openDrawer(
    String drawerId, {
    String? reason,
  }) async {
    final String id = drawerId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing drawer id");
    try {
      return await _repository.openDrawer(id, reason: reason);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<DrawerCommandResponse> closeDrawer(
    String drawerId, {
    String? reason,
  }) async {
    final String id = drawerId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing drawer id");
    try {
      return await _repository.closeDrawer(id, reason: reason);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }

  Future<MedicineBoxModel> unassignBox(String boxId) async {
    final String id = boxId.trim();
    if (id.isEmpty) throw SmartBoxServiceException("Missing medicine box id.");
    try {
      return await _repository.unassignMedicineBox(id);
    } on SmartBoxRepositoryException catch (e) {
      throw SmartBoxServiceException(e.message);
    }
  }
}

class SmartBoxServiceException implements Exception {
  SmartBoxServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
