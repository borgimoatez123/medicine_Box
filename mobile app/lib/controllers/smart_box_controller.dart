import "package:flutter/foundation.dart";

import "../data/repositories/smart_box_repository.dart";
import "../models/drawer_command_response_model.dart";
import "../models/drawer_model.dart";
import "../models/medicine_box_model.dart";
import "../models/medicine_box_sensor_model.dart";
import "../services/smart_box_service.dart";

class SmartBoxController extends ChangeNotifier {
  SmartBoxController({SmartBoxService? service, SmartBoxRepository? repository})
    : _service = service ?? SmartBoxService(repository: repository);
  final SmartBoxService _service;

  bool _isLoading = false;
  bool _isActivating = false;
  bool _isRenamingBox = false;
  bool _isUnassigningBox = false;
  bool _isLoadingDrawers = false;
  bool _isLoadingSensors = false;
  final Set<String> _loadingDrawerSensors = <String>{};
  final Set<String> _sendingDrawerCommands = <String>{};
  final Set<String> _unassigningBoxIds = <String>{};
  final Map<String, bool> _updatingDrawers = <String, bool>{};

  List<MedicineBoxModel> _boxes = const <MedicineBoxModel>[];
  final Map<String, List<DrawerModel>> _drawersByBox =
      <String, List<DrawerModel>>{};
  final Map<String, DrawerModel> _drawerById = <String, DrawerModel>{};
  final Map<String, MedicineBoxSensorStateResponse> _sensorStateByBox =
      <String, MedicineBoxSensorStateResponse>{};
  final Map<String, DrawerSensorState> _sensorStateByDrawer =
      <String, DrawerSensorState>{};
  final Map<String, DrawerCommandResponse> _lastCommandByDrawer =
      <String, DrawerCommandResponse>{};

  String? _error;
  String? _lastCommandId;
  String? _lastCommandType;
  String? _lastCommandStatus;

  bool get isLoading => _isLoading;
  bool get isActivating => _isActivating;
  bool get isRenamingBox => _isRenamingBox;
  bool get isUnassigningBox => _isUnassigningBox;
  bool isUnassigningBoxId(String boxId) {
    final String id = boxId.trim();
    if (id.isEmpty) return false;
    return _unassigningBoxIds.contains(id);
  }

  bool get isLoadingDrawers => _isLoadingDrawers;
  bool get isLoadingSensors => _isLoadingSensors;
  bool isLoadingDrawerSensors(String drawerId) {
    final String id = drawerId.trim();
    if (id.isEmpty) return false;
    return _loadingDrawerSensors.contains(id);
  }

  bool isSendingDrawerCommand(String drawerId) {
    final String id = drawerId.trim();
    if (id.isEmpty) return false;
    return _sendingDrawerCommands.contains(id);
  }

  bool isDrawerUpdating(String drawerId) => _updatingDrawers[drawerId] ?? false;
  List<MedicineBoxModel> get boxes => _boxes;
  String? get error => _error;
  String? get lastCommandId => _lastCommandId;
  String? get lastCommandType => _lastCommandType;
  String? get lastCommandStatus => _lastCommandStatus;

  DrawerCommandResponse? lastDrawerCommand(String drawerId) {
    final String id = drawerId.trim();
    if (id.isEmpty) return null;
    return _lastCommandByDrawer[id];
  }

  List<DrawerModel> drawersForBox(String boxId) {
    final String id = boxId.trim();
    if (id.isEmpty) return const <DrawerModel>[];
    final List<DrawerModel>? list = _drawersByBox[id];
    if (list == null) return const <DrawerModel>[];
    return List<DrawerModel>.unmodifiable(list);
  }

  DrawerModel? drawerById(String drawerId) {
    final String id = drawerId.trim();
    if (id.isEmpty) return null;
    return _drawerById[id];
  }

  MedicineBoxSensorStateResponse? sensorStateForBox(String boxId) {
    final String id = boxId.trim();
    if (id.isEmpty) return null;
    return _sensorStateByBox[id];
  }

  DrawerSensorState? sensorStateForDrawer(String drawerId) {
    final String id = drawerId.trim();
    if (id.isEmpty) return null;
    return _sensorStateByDrawer[id];
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<List<MedicineBoxModel>> loadBoxes({int limit = 50}) async {
    if (_isLoading) return List<MedicineBoxModel>.from(_boxes);
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final List<MedicineBoxModel> list = await _service.loadMyBoxes(
        limit: limit,
      );
      _boxes = list;
      for (final MedicineBoxModel b in list) {
        if (b.id.trim().isEmpty) continue;
      }
      return List<MedicineBoxModel>.from(_boxes);
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MedicineBoxModel> reloadBox(String boxId) async {
    final String id = boxId.trim();
    try {
      final MedicineBoxModel box = await _service.getBox(id);
      final int index = _boxes.indexWhere(
        (MedicineBoxModel b) => b.id.trim() == id,
      );
      if (index >= 0) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        next[index] = box;
        _boxes = next;
      } else {
        _boxes = List<MedicineBoxModel>.from(<MedicineBoxModel>[
          box,
          ..._boxes,
        ]);
      }
      notifyListeners();
      return box;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<MedicineBoxModel> activateBox({
    required String deviceId,
    required String deviceToken,
  }) async {
    if (_isActivating) {
      throw SmartBoxControllerException("Activation already in progress.");
    }
    _isActivating = true;
    _error = null;
    notifyListeners();
    try {
      final MedicineBoxModel created = await _service.activateBox(
        deviceId: deviceId,
        deviceToken: deviceToken,
      );
      final String id = created.id.trim();
      final int index = _boxes.indexWhere(
        (MedicineBoxModel b) => b.id.trim() == id,
      );
      if (index >= 0) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        next[index] = created;
        _boxes = next;
      } else {
        _boxes = List<MedicineBoxModel>.from(<MedicineBoxModel>[
          created,
          ..._boxes,
        ]);
      }
      notifyListeners();
      return created;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isActivating = false;
      notifyListeners();
    }
  }

  Future<MedicineBoxModel> renameBox(String boxId, String newName) async {
    final String id = boxId.trim();
    if (id.isEmpty) {
      throw SmartBoxControllerException("Missing medicine box id");
    }
    if (_isRenamingBox) {
      throw SmartBoxControllerException("Rename already in progress.");
    }
    _isRenamingBox = true;
    _error = null;
    notifyListeners();
    final MedicineBoxModel? snapshot = _findBox(id);
    if (snapshot != null) {
      final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
      final int idx = next.indexWhere(
        (MedicineBoxModel b) => b.id.trim() == id,
      );
      if (idx >= 0) {
        next[idx] = snapshot.copyWith(name: newName.trim());
        _boxes = next;
        notifyListeners();
      }
    }
    try {
      final MedicineBoxModel updated = await _service.renameBox(id, newName);
      final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
      final int idx = next.indexWhere(
        (MedicineBoxModel b) => b.id.trim() == id,
      );
      if (idx >= 0) {
        next[idx] = updated;
      } else {
        next.insert(0, updated);
      }
      _boxes = next;
      notifyListeners();
      return updated;
    } on SmartBoxServiceException catch (e) {
      if (snapshot != null) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        final int idx = next.indexWhere(
          (MedicineBoxModel b) => b.id.trim() == id,
        );
        if (idx >= 0) next[idx] = snapshot;
        _boxes = next;
      }
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      if (snapshot != null) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        final int idx = next.indexWhere(
          (MedicineBoxModel b) => b.id.trim() == id,
        );
        if (idx >= 0) next[idx] = snapshot;
        _boxes = next;
        notifyListeners();
      }
      _error = e.toString();
      rethrow;
    } finally {
      _isRenamingBox = false;
      notifyListeners();
    }
  }

  Future<List<DrawerModel>> loadDrawersForBox(String medicineBoxId) async {
    final String mbid = medicineBoxId.trim();
    if (mbid.isEmpty) {
      throw SmartBoxControllerException("Missing medicine box id");
    }
    _isLoadingDrawers = true;
    _error = null;
    notifyListeners();
    try {
      final List<DrawerModel> list = await _service.loadDrawers(mbid);
      list.sort(
        (DrawerModel a, DrawerModel b) =>
            a.drawerNumber.compareTo(b.drawerNumber),
      );
      _drawersByBox[mbid] = list;
      for (final DrawerModel d in list) {
        if (d.id.trim().isEmpty) continue;
        _drawerById[d.id.trim()] = d;
      }
      notifyListeners();
      return List<DrawerModel>.from(list);
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoadingDrawers = false;
      notifyListeners();
    }
  }

  Future<MedicineBoxSensorStateResponse> loadSensorStateForBox(
    String medicineBoxId,
  ) async {
    final String mbid = medicineBoxId.trim();
    if (mbid.isEmpty) {
      throw SmartBoxControllerException("Missing medicine box id");
    }
    _isLoadingSensors = true;
    notifyListeners();
    try {
      final MedicineBoxSensorStateResponse state = await _service
          .loadSensorState(mbid);
      _sensorStateByBox[mbid] = state;
      notifyListeners();
      return state;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoadingSensors = false;
      notifyListeners();
    }
  }

  Future<DrawerSensorState> loadDrawerSensorState(String drawerId) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxControllerException("Missing drawer id");
    }
    _loadingDrawerSensors.add(did);
    notifyListeners();
    try {
      final DrawerSensorState state = await _service.loadDrawerSensorState(did);
      _sensorStateByDrawer[did] = state;
      final String mbid = (state.medicineBoxId ?? "").trim();
      if (mbid.isNotEmpty) {
        final MedicineBoxSensorStateResponse? boxState =
            _sensorStateByBox[mbid];
        if (boxState != null) {
          final List<DrawerSensorState> next = List<DrawerSensorState>.of(
            boxState.drawers,
          );
          bool found = false;
          for (int i = 0; i < next.length; i++) {
            if (next[i].drawerId.trim() == did) {
              next[i] = state;
              found = true;
              break;
            }
          }
          if (!found) {
            next.add(state);
            next.sort(
              (DrawerSensorState a, DrawerSensorState b) =>
                  a.drawerIndex.compareTo(b.drawerIndex),
            );
          }
          _sensorStateByBox[mbid] = MedicineBoxSensorStateResponse(
            medicineBoxId: mbid,
            drawers: List<DrawerSensorState>.unmodifiable(next),
          );
        }
      }
      notifyListeners();
      return state;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _loadingDrawerSensors.remove(did);
      notifyListeners();
    }
  }

  Future<DrawerCommandResponse> openDrawer(
    String drawerId, {
    String? reason,
  }) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxControllerException("Missing drawer id");
    }
    if (_sendingDrawerCommands.contains(did)) {
      throw SmartBoxControllerException("A drawer command is already in progress.");
    }
    _sendingDrawerCommands.add(did);
    notifyListeners();
    try {
      final DrawerCommandResponse r = await _service.openDrawer(
        did,
        reason: reason,
      );
      _lastCommandId = r.commandId;
      _lastCommandType = r.type;
      _lastCommandStatus = r.status;
      _lastCommandByDrawer[did] = r;
      notifyListeners();
      return r;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _sendingDrawerCommands.remove(did);
      notifyListeners();
    }
  }

  Future<DrawerCommandResponse> closeDrawer(
    String drawerId, {
    String? reason,
  }) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxControllerException("Missing drawer id");
    }
    if (_sendingDrawerCommands.contains(did)) {
      throw SmartBoxControllerException("A drawer command is already in progress.");
    }
    _sendingDrawerCommands.add(did);
    notifyListeners();
    try {
      final DrawerCommandResponse r = await _service.closeDrawer(
        did,
        reason: reason,
      );
      _lastCommandId = r.commandId;
      _lastCommandType = r.type;
      _lastCommandStatus = r.status;
      _lastCommandByDrawer[did] = r;
      notifyListeners();
      return r;
    } on SmartBoxServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _sendingDrawerCommands.remove(did);
      notifyListeners();
    }
  }

  Future<DrawerModel> updateDrawerStatus(
    String drawerId,
    DrawerStatus nextStatus,
  ) async {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw SmartBoxControllerException("Missing drawer id");
    }
    _updatingDrawers[did] = true;
    _error = null;
    notifyListeners();

    final DrawerModel? snapshot = _drawerById[did];
    final String? snapshotBoxId = snapshot?.medicineBoxId.trim();
    if (snapshot != null) {
      final DrawerModel updated = snapshot.copyWith(status: nextStatus);
      _drawerById[did] = updated;
      if (snapshotBoxId != null && snapshotBoxId.isNotEmpty) {
        final List<DrawerModel> list = List<DrawerModel>.from(
          _drawersByBox[snapshotBoxId] ?? const <DrawerModel>[],
        );
        final int idx = list.indexWhere((DrawerModel d) => d.id.trim() == did);
        if (idx >= 0) {
          list[idx] = updated;
        } else {
          list.add(updated);
        }
        _drawersByBox[snapshotBoxId] = list;
      }
      notifyListeners();
    }
    try {
      final DrawerModel returned = await _service.updateDrawerStatus(
        did,
        nextStatus,
      );
      _drawerById[did] = returned;
      final String boxId = returned.medicineBoxId.trim();
      if (boxId.isNotEmpty) {
        final List<DrawerModel> list = List<DrawerModel>.from(
          _drawersByBox[boxId] ?? const <DrawerModel>[],
        );
        final int idx = list.indexWhere((DrawerModel d) => d.id.trim() == did);
        if (idx >= 0) {
          list[idx] = returned;
        } else {
          list.add(returned);
        }
        list.sort(
          (DrawerModel a, DrawerModel b) =>
              a.drawerNumber.compareTo(b.drawerNumber),
        );
        _drawersByBox[boxId] = list;
      }
      notifyListeners();
      return returned;
    } on SmartBoxServiceException catch (e) {
      if (snapshot != null &&
          snapshotBoxId != null &&
          snapshotBoxId.isNotEmpty) {
        _drawerById[did] = snapshot;
        final List<DrawerModel> list = List<DrawerModel>.from(
          _drawersByBox[snapshotBoxId] ?? const <DrawerModel>[],
        );
        final int idx = list.indexWhere((DrawerModel d) => d.id.trim() == did);
        if (idx >= 0) list[idx] = snapshot;
        _drawersByBox[snapshotBoxId] = list;
        notifyListeners();
      }
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      if (snapshot != null &&
          snapshotBoxId != null &&
          snapshotBoxId.isNotEmpty) {
        _drawerById[did] = snapshot;
        final List<DrawerModel> list = List<DrawerModel>.from(
          _drawersByBox[snapshotBoxId] ?? const <DrawerModel>[],
        );
        final int idx = list.indexWhere((DrawerModel d) => d.id.trim() == did);
        if (idx >= 0) list[idx] = snapshot;
        _drawersByBox[snapshotBoxId] = list;
        notifyListeners();
      }
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _updatingDrawers.remove(did);
      notifyListeners();
    }
  }

  List<String> orphanDrawerIdsForBox(String boxId) {
    final String id = boxId.trim();
    if (id.isEmpty) return const <String>[];
    return _drawerById.keys
        .where(
          (String dId) => (_drawerById[dId]?.medicineBoxId.trim() ?? "") == id,
        )
        .toList(growable: false);
  }

  Future<MedicineBoxModel> unassignBox(String boxId) async {
    final String id = boxId.trim();
    if (id.isEmpty) {
      throw SmartBoxControllerException("Missing medicine box id.");
    }
    if (_isUnassigningBox || _unassigningBoxIds.contains(id)) {
      throw SmartBoxControllerException("Unassign already in progress.");
    }
    final MedicineBoxModel? snap = _findBox(id);
    if (snap != null && snap.status.isMaintenance) {
      throw SmartBoxControllerException(
        "Your medicine box is under maintenance and cannot be unassigned right now.",
      );
    }
    _isUnassigningBox = true;
    _unassigningBoxIds.add(id);
    _error = null;
    notifyListeners();
    final MedicineBoxModel? snapshot = _findBox(id);
    try {
      final MedicineBoxModel returned = await _service.unassignBox(id);
      final MedicineBoxModel updated = returned.copyWith(
        status: MedicineBoxStatus.ready,
        userId: null,
      );
      final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
      final int idx = next.indexWhere(
        (MedicineBoxModel b) => b.id.trim() == id,
      );
      if (idx >= 0) {
        next[idx] = updated;
      } else {
        next.insert(0, updated);
      }
      _boxes = next;
      _drawersByBox.remove(id);
      _sensorStateByBox.remove(id);
      final List<String> orphanDrawerIds = orphanDrawerIdsForBox(id);
      for (final String dId in orphanDrawerIds) {
        _drawerById.remove(dId);
      }
      notifyListeners();
      return updated;
    } on SmartBoxServiceException catch (e) {
      if (snapshot != null) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        final int idx = next.indexWhere(
          (MedicineBoxModel b) => b.id.trim() == id,
        );
        if (idx >= 0) next[idx] = snapshot;
        _boxes = next;
      }
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      if (snapshot != null) {
        final List<MedicineBoxModel> next = List<MedicineBoxModel>.from(_boxes);
        final int idx = next.indexWhere(
          (MedicineBoxModel b) => b.id.trim() == id,
        );
        if (idx >= 0) next[idx] = snapshot;
        _boxes = next;
      }
      _error = "Unable to unassign the medicine box. No changes were applied.";
      notifyListeners();
      rethrow;
    } finally {
      _unassigningBoxIds.remove(id);
      _isUnassigningBox = _unassigningBoxIds.isNotEmpty;
      notifyListeners();
    }
  }

  MedicineBoxModel? findById(String boxId) {
    final String id = boxId.trim();
    if (id.isEmpty) return null;
    return _findBox(id);
  }

  MedicineBoxModel? _findBox(String id) {
    for (final MedicineBoxModel b in _boxes) {
      if (b.id.trim() == id) return b;
    }
    return null;
  }
}

class SmartBoxControllerException implements Exception {
  SmartBoxControllerException(this.message);
  final String message;
  @override
  String toString() => message;
}
