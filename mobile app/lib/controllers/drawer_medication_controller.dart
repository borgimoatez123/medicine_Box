import "package:flutter/foundation.dart";

import "../models/drawer_medication_model.dart";
import "../models/medicine_box_model.dart";
import "../services/drawer_medication_service.dart";

class DrawerMedicationController extends ChangeNotifier {
  DrawerMedicationController({DrawerMedicationService? service})
    : _service = service ?? DrawerMedicationService();

  final DrawerMedicationService _service;

  MedicineBoxModel? Function(String drawerId)? boxForDrawerResolver;

  MedicineBoxModel? _resolveBox(String drawerId) {
    if (boxForDrawerResolver == null) return null;
    return boxForDrawerResolver!(drawerId);
  }

  void _ensureBoxStatusActive(String drawerId) {
    final MedicineBoxModel? box = _resolveBox(drawerId);
    if (box != null && !box.status.isActive) {
      if (box.status.isMaintenance) {
        throw DrawerMedicationControllerException(
          "Your medicine box is under maintenance.",
        );
      }
      if (box.status.isReady) {
        throw DrawerMedicationControllerException(
          "Your medicine box is not active. Please activate your device first.",
        );
      }
      throw DrawerMedicationControllerException(
        "Your medicine box is not active. Please activate your device first.",
      );
    }
  }

  void _ensurePhysicalOperationsAllowed(String drawerId) {
    final MedicineBoxModel? box = _resolveBox(drawerId);
    if (box == null) return;
    if (!box.status.isActive) {
      if (box.status.isMaintenance) {
        throw DrawerMedicationControllerException(
          "Your medicine box is under maintenance.",
        );
      }
      throw DrawerMedicationControllerException(
        "Your medicine box is not active. Please activate your device first.",
      );
    }
    if (box.deviceStatus.isOffline || !box.deviceStatus.isOnline) {
      throw DrawerMedicationControllerException(
        "Your medicine box is offline. Please make sure your device is connected.",
      );
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  final Set<String> _updatingIds = <String>{};
  final Set<String> _deletingIds = <String>{};

  List<DrawerMedicationModel> _assignments = <DrawerMedicationModel>[];
  List<DrawerMedicationModel> get assignments =>
      List<DrawerMedicationModel>.unmodifiable(_assignments);

  String? _error;
  String? get error => _error;

  bool isUpdatingAssignment(String id) => _updatingIds.contains(id.trim());

  bool isDeletingAssignment(String id) => _deletingIds.contains(id.trim());

  DrawerMedicationModel? findById(String id) {
    final String key = id.trim();
    if (key.isEmpty) return null;
    for (final DrawerMedicationModel a in _assignments) {
      if (a.id.trim() == key) return a;
    }
    return null;
  }

  DrawerMedicationModel? findByDrawerId(String drawerId) {
    final String key = drawerId.trim();
    if (key.isEmpty) return null;
    for (final DrawerMedicationModel a in _assignments) {
      if (a.drawerId.trim() == key) return a;
    }
    return null;
  }

  DrawerMedicationModel? findByMedicationId(String medicationId) {
    final String key = medicationId.trim();
    if (key.isEmpty) return null;
    for (final DrawerMedicationModel a in _assignments) {
      if (a.medicationId.trim() == key) return a;
    }
    return null;
  }

  List<DrawerMedicationModel> forBoxDrawerIds(Iterable<String> drawerIds) {
    final Set<String> keys = drawerIds
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return const <DrawerMedicationModel>[];
    return _assignments
        .where((DrawerMedicationModel a) => keys.contains(a.drawerId.trim()))
        .toList(growable: false);
  }

  Future<void> loadAssignments({String? drawerId, String? medicationId}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final List<DrawerMedicationModel> items = await _service.getAssignments(
        drawerId: drawerId,
        medicationId: medicationId,
      );
      final Map<String, DrawerMedicationModel> merged =
          <String, DrawerMedicationModel>{};
      for (final DrawerMedicationModel a in _assignments) {
        if (a.id.isNotEmpty) merged[a.id.trim()] = a;
      }
      for (final DrawerMedicationModel a in items) {
        if (a.id.isNotEmpty) merged[a.id.trim()] = a;
      }
      if (drawerId != null || medicationId != null) {
        final Set<String> keep = items
            .where((DrawerMedicationModel a) => a.id.isNotEmpty)
            .map((DrawerMedicationModel a) => a.id.trim())
            .toSet();
        for (final String id in merged.keys.toList(growable: false)) {
          if (!keep.contains(id) && items.isNotEmpty) merged.remove(id);
        }
      }
      _assignments = merged.values.toList(growable: false);
      notifyListeners();
    } on DrawerMedicationServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      _error = "Unable to load drawer-medication assignments.";
      notifyListeners();
      throw DrawerMedicationControllerException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DrawerMedicationModel> getAssignment(String assignmentId) async {
    try {
      final DrawerMedicationModel fresh = await _service.getAssignmentById(
        assignmentId,
      );
      final String key = fresh.id.trim();
      final int index = _assignments.indexWhere(
        (DrawerMedicationModel a) => a.id.trim() == key,
      );
      if (index >= 0) {
        _assignments[index] = fresh;
      } else if (fresh.id.isNotEmpty) {
        _assignments = <DrawerMedicationModel>[fresh, ..._assignments];
      }
      notifyListeners();
      return fresh;
    } on DrawerMedicationServiceException catch (e) {
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      throw DrawerMedicationControllerException(e.toString());
    }
  }

  Future<DrawerMedicationModel> createAssignment({
    required String drawerId,
    required String medicationId,
    required int quantity,
    required int missingQuantity,
  }) async {
    _ensureBoxStatusActive(drawerId);
    if (quantity < 0) {
      throw DrawerMedicationControllerException("Invalid quantity");
    }
    if (missingQuantity < 0) {
      throw DrawerMedicationControllerException("Invalid missingQuantity");
    }
    if (_isCreating) {
      throw DrawerMedicationControllerException(
        "Another assignment is being created.",
      );
    }
    _isCreating = true;
    _error = null;
    notifyListeners();
    try {
      final DrawerMedicationModel created = await _service.createAssignment(
        drawerId: drawerId,
        medicationId: medicationId,
        quantity: quantity,
        missingQuantity: missingQuantity,
      );
      if (created.id.isNotEmpty) {
        final Set<String> ids = _assignments
            .map((DrawerMedicationModel a) => a.id.trim())
            .where((String s) => s.isNotEmpty)
            .toSet();
        if (!ids.contains(created.id.trim())) {
          _assignments = <DrawerMedicationModel>[created, ..._assignments];
        }
      }
      notifyListeners();
      return created;
    } on DrawerMedicationServiceException catch (e) {
      _error = e.message;
      notifyListeners();
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      _error = "Unable to create drawer-medication assignment.";
      notifyListeners();
      throw DrawerMedicationControllerException(_error!);
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<DrawerMedicationModel> updateAssignment(
    DrawerMedicationModel assignment, {
    bool? isActive,
  }) async {
    _ensurePhysicalOperationsAllowed(assignment.drawerId);
    final String id = assignment.id.trim();
    if (id.isEmpty) {
      throw DrawerMedicationControllerException("Missing assignment id");
    }
    if (_updatingIds.contains(id)) {
      throw DrawerMedicationControllerException(
        "Assignment is already being updated.",
      );
    }
    _updatingIds.add(id);
    _isUpdating = true;
    _error = null;
    notifyListeners();
    final DrawerMedicationModel snapshot = assignment;
    final int index = _assignments.indexWhere(
      (DrawerMedicationModel a) => a.id.trim() == id,
    );
    try {
      final DrawerMedicationModel updated = await _service.updateAssignment(
        id,
        isActive: isActive,
      );
      if (index >= 0) {
        _assignments[index] = updated;
      } else if (updated.id.isNotEmpty) {
        _assignments = <DrawerMedicationModel>[updated, ..._assignments];
      }
      notifyListeners();
      return updated;
    } on DrawerMedicationServiceException catch (e) {
      if (index >= 0) {
        _assignments[index] = snapshot;
        notifyListeners();
      }
      _error = e.message;
      notifyListeners();
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _assignments[index] = snapshot;
        notifyListeners();
      }
      _error = "Unable to update drawer-medication assignment.";
      notifyListeners();
      throw DrawerMedicationControllerException(_error!);
    } finally {
      _updatingIds.remove(id);
      _isUpdating = _updatingIds.isNotEmpty;
      notifyListeners();
    }
  }

  Future<void> deleteAssignment(DrawerMedicationModel assignment) async {
    _ensurePhysicalOperationsAllowed(assignment.drawerId);
    final String id = assignment.id.trim();
    if (id.isEmpty) {
      throw DrawerMedicationControllerException("Missing assignment id");
    }
    if (_deletingIds.contains(id)) {
      throw DrawerMedicationControllerException(
        "Assignment is already being deleted.",
      );
    }
    _deletingIds.add(id);
    _isDeleting = true;
    _error = null;
    notifyListeners();
    final List<DrawerMedicationModel> snapshot = List<DrawerMedicationModel>.of(
      _assignments,
    );
    _assignments = _assignments
        .where((DrawerMedicationModel a) => a.id.trim() != id)
        .toList(growable: false);
    notifyListeners();
    try {
      await _service.deleteAssignment(id);
      notifyListeners();
    } on DrawerMedicationServiceException catch (e) {
      _assignments = snapshot;
      notifyListeners();
      _error = e.message;
      notifyListeners();
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      _assignments = snapshot;
      notifyListeners();
      _error = "Unable to delete drawer-medication assignment.";
      notifyListeners();
      throw DrawerMedicationControllerException(_error!);
    } finally {
      _deletingIds.remove(id);
      _isDeleting = _deletingIds.isNotEmpty;
      notifyListeners();
    }
  }

  Future<DrawerMedicationModel> moveAssignment({
    required DrawerMedicationModel assignment,
    required String toDrawerId,
  }) async {
    _ensurePhysicalOperationsAllowed(assignment.drawerId);
    _ensurePhysicalOperationsAllowed(toDrawerId);
    final String id = assignment.id.trim();
    if (id.isEmpty) {
      throw DrawerMedicationControllerException("Missing assignment id");
    }
    if (_updatingIds.contains(id)) {
      throw DrawerMedicationControllerException(
        "Assignment is already being updated.",
      );
    }
    _updatingIds.add(id);
    _isUpdating = true;
    _error = null;
    notifyListeners();
    final DrawerMedicationModel snapshot = assignment;
    final int index = _assignments.indexWhere(
      (DrawerMedicationModel a) => a.id.trim() == id,
    );
    try {
      final DrawerMedicationModel updated = await _service.moveAssignment(
        assignmentId: id,
        fromDrawerId: snapshot.drawerId,
        toDrawerId: toDrawerId,
        medicationId: snapshot.medicationId,
        originalQuantity: snapshot.quantity,
        originalMissingQuantity: snapshot.missingQuantity,
      );
      if (index >= 0) {
        _assignments[index] = updated;
      } else if (updated.id.isNotEmpty) {
        _assignments = <DrawerMedicationModel>[updated, ..._assignments];
      }
      notifyListeners();
      return updated;
    } on DrawerMedicationServiceException catch (e) {
      if (index >= 0) {
        _assignments[index] = snapshot;
        notifyListeners();
      }
      _error = e.message;
      notifyListeners();
      throw DrawerMedicationControllerException(e.message);
    } catch (e) {
      if (index >= 0) {
        _assignments[index] = snapshot;
        notifyListeners();
      }
      _error = "Unable to move drawer-medication assignment.";
      notifyListeners();
      throw DrawerMedicationControllerException(_error!);
    } finally {
      _updatingIds.remove(id);
      _isUpdating = _updatingIds.isNotEmpty;
      notifyListeners();
    }
  }

  void clearAssignmentsForBoxDrawers(Iterable<String> drawerIds) {
    final Set<String> keys = drawerIds
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return;
    final List<DrawerMedicationModel> removed = _assignments
        .where((DrawerMedicationModel a) => keys.contains(a.drawerId.trim()))
        .toList(growable: false);
    if (removed.isEmpty) return;
    _assignments = _assignments
        .where((DrawerMedicationModel a) => !keys.contains(a.drawerId.trim()))
        .toList(growable: false);
    for (final DrawerMedicationModel a in removed) {
      final String id = a.id.trim();
      if (id.isNotEmpty) {
        _updatingIds.remove(id);
        _deletingIds.remove(id);
      }
    }
    notifyListeners();
  }
}

class DrawerMedicationControllerException implements Exception {
  DrawerMedicationControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
