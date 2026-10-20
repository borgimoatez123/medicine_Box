import "../data/repositories/drawer_medication_repository.dart";
import "../models/drawer_medication_model.dart";

class DrawerMedicationService {
  DrawerMedicationService({DrawerMedicationRepository? repository})
    : _repository = repository ?? DrawerMedicationRepository();

  final DrawerMedicationRepository _repository;

  static bool _isValidUuidish(String value) {
    final String v = value.trim();
    if (v.isEmpty) return false;
    if (v.length < 6) return false;
    return true;
  }

  Future<List<DrawerMedicationModel>> getAssignments({
    String? drawerId,
    String? medicationId,
  }) {
    final String? did = drawerId?.trim();
    final String? mid = medicationId?.trim();
    if (did != null && did.isNotEmpty && !_isValidUuidish(did)) {
      throw DrawerMedicationServiceException("Invalid drawer ID format");
    }
    if (mid != null && mid.isNotEmpty && !_isValidUuidish(mid)) {
      throw DrawerMedicationServiceException("Invalid medication ID format");
    }
    return _repository.getAssignments(drawerId: did, medicationId: mid);
  }

  Future<List<DrawerMedicationModel>> getAssignmentsByDrawer(String drawerId) {
    final String did = drawerId.trim();
    if (did.isEmpty) {
      throw DrawerMedicationServiceException("Missing drawer id");
    }
    if (!_isValidUuidish(did)) {
      throw DrawerMedicationServiceException("Invalid drawer ID format");
    }
    return _repository.getAssignmentsByDrawer(did);
  }

  Future<List<DrawerMedicationModel>> getAssignmentsByMedication(
    String medicationId,
  ) {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw DrawerMedicationServiceException("Missing medication id");
    }
    if (!_isValidUuidish(mid)) {
      throw DrawerMedicationServiceException("Invalid medication ID format");
    }
    return _repository.getAssignmentsByMedication(mid);
  }

  Future<DrawerMedicationModel> getAssignmentById(String assignmentId) {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationServiceException("Missing assignment id");
    }
    if (!_isValidUuidish(aid)) {
      throw DrawerMedicationServiceException("Invalid assignment ID format");
    }
    return _repository.getAssignmentById(aid);
  }

  Future<DrawerMedicationModel> createAssignment({
    required String drawerId,
    required String medicationId,
    required int quantity,
    required int missingQuantity,
  }) async {
    final String did = drawerId.trim();
    final String mid = medicationId.trim();
    if (did.isEmpty || !_isValidUuidish(did)) {
      throw DrawerMedicationServiceException("Invalid drawer ID format");
    }
    if (mid.isEmpty || !_isValidUuidish(mid)) {
      throw DrawerMedicationServiceException("Invalid medication ID format");
    }
    if (quantity < 0) {
      throw DrawerMedicationServiceException("Invalid quantity");
    }
    if (missingQuantity < 0) {
      throw DrawerMedicationServiceException("Invalid missingQuantity");
    }
    final CreateDrawerMedicationRequest request = CreateDrawerMedicationRequest(
      drawerId: did,
      medicationId: mid,
      quantity: quantity,
      missingQuantity: missingQuantity,
    );
    return _repository.createAssignment(request);
  }

  Future<DrawerMedicationModel> updateAssignment(
    String assignmentId, {
    bool? isActive,
  }) async {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationServiceException("Missing assignment id");
    }
    if (!_isValidUuidish(aid)) {
      throw DrawerMedicationServiceException("Invalid assignment ID format");
    }
    final UpdateDrawerMedicationRequest request = UpdateDrawerMedicationRequest(
      isActive: isActive,
    );
    if (request.isEmpty) {
      return _repository.getAssignmentById(aid);
    }
    return _repository.updateAssignment(aid, request);
  }

  Future<DrawerMedicationModel> moveAssignment({
    required String assignmentId,
    required String fromDrawerId,
    required String toDrawerId,
    required String medicationId,
    int? originalQuantity,
    int? originalMissingQuantity,
  }) async {
    final String aid = assignmentId.trim();
    final String fromDid = fromDrawerId.trim();
    final String toDid = toDrawerId.trim();
    final String mid = medicationId.trim();
    final int qty = originalQuantity != null && originalQuantity >= 0
        ? originalQuantity
        : 0;
    final int mq =
        originalMissingQuantity != null && originalMissingQuantity >= 0
        ? originalMissingQuantity
        : 0;
    if (aid.isEmpty) {
      throw DrawerMedicationServiceException("Missing assignment id");
    }
    if (fromDid.isEmpty) {
      throw DrawerMedicationServiceException("Missing source drawer id");
    }
    if (toDid.isEmpty) {
      throw DrawerMedicationServiceException("Missing target drawer id");
    }
    if (mid.isEmpty) {
      throw DrawerMedicationServiceException("Missing medication id");
    }
    if (fromDid == toDid) {
      throw DrawerMedicationServiceException(
        "Target drawer must be different from the current drawer",
      );
    }
    await _repository.deleteAssignment(aid);
    try {
      return _repository.createAssignment(
        CreateDrawerMedicationRequest(
          drawerId: toDid,
          medicationId: mid,
          quantity: qty,
          missingQuantity: mq,
        ),
      );
    } catch (e) {
      try {
        await _repository.createAssignment(
          CreateDrawerMedicationRequest(
            drawerId: fromDid,
            medicationId: mid,
            quantity: qty,
            missingQuantity: mq,
          ),
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> deleteAssignment(String assignmentId) {
    final String aid = assignmentId.trim();
    if (aid.isEmpty) {
      throw DrawerMedicationServiceException("Missing assignment id");
    }
    if (!_isValidUuidish(aid)) {
      throw DrawerMedicationServiceException("Invalid assignment ID format");
    }
    return _repository.deleteAssignment(aid);
  }
}

class DrawerMedicationServiceException implements Exception {
  DrawerMedicationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
