import "../data/repositories/medication_repository.dart";
import "../models/medication_model.dart";

class MedicationService {
  MedicationService({MedicationRepository? repository})
    : _repository = repository ?? MedicationRepository();

  final MedicationRepository _repository;

  static bool _isValidUuidish(String value) {
    final String v = value.trim();
    if (v.isEmpty) return false;
    if (v.length < 6) return false;
    return true;
  }

  Future<MedicationPageResult> listMyMedications({
    String? patientId,
    int? page,
    int? limit,
  }) {
    return _repository.listMyMedications(
      patientId: patientId,
      page: page,
      limit: limit,
    );
  }

  Future<List<MedicationModel>> getMedicationsByPatient(String patientId) {
    final String pid = patientId.trim();
    if (pid.isEmpty) {
      throw MedicationServiceException("Missing patient id");
    }
    return _repository.getMedicationsByPatient(pid);
  }

  Future<MedicationModel> getMedicationById(String medicationId) {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationServiceException("Missing medication id");
    }
    return _repository.getMedicationById(mid);
  }

  Future<MedicationModel> createMedication({
    required String patientId,
    required String name,
    required String dosage,
    MedicationForm form = MedicationForm.tablet,
    required int quantity,
    DateTime? expiryDate,
  }) async {
    final String pid = patientId.trim();
    final String n = name.trim();
    final String d = dosage.trim();
    if (pid.isEmpty || !_isValidUuidish(pid)) {
      throw MedicationServiceException("Invalid patient ID format");
    }
    if (n.isEmpty) {
      throw MedicationServiceException("Medication name is required");
    }
    if (d.isEmpty) {
      throw MedicationServiceException("Dosage is required");
    }
    if (!kSupportedMedicationForms.contains(form)) {
      throw MedicationServiceException(
        "Invalid form. Use: TABLET, CAPSULE, LIQUID, INJECTION, CREAM, POWDER, OTHER.",
      );
    }
    if (quantity < 1) {
      throw MedicationServiceException("Quantity must be at least 1");
    }
    final CreateMedicationRequest request = CreateMedicationRequest(
      patientId: pid,
      name: n,
      dosage: d,
      form: form,
      quantity: quantity,
      expiryDate: expiryDate,
    );
    return _repository.createMedication(request);
  }

  Future<MedicationModel> updateMedication(
    String medicationId, {
    String? name,
    String? dosage,
    MedicationForm? form,
    int? quantity,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationServiceException("Missing medication id");
    }
    final String? n = name?.trim();
    final String? d = dosage?.trim();
    if (n != null && n.isEmpty) {
      throw MedicationServiceException("Medication name cannot be empty");
    }
    if (d != null && d.isEmpty) {
      throw MedicationServiceException("Dosage cannot be empty");
    }
    if (form != null && !kSupportedMedicationForms.contains(form)) {
      throw MedicationServiceException(
        "Invalid form. Use: TABLET, CAPSULE, LIQUID, INJECTION, CREAM, POWDER, OTHER.",
      );
    }
    if (quantity != null && quantity < 1) {
      throw MedicationServiceException("Quantity must be at least 1");
    }
    final UpdateMedicationRequest request = UpdateMedicationRequest(
      name: n,
      dosage: d,
      form: form,
      quantity: quantity,
      expiryDate: expiryDate,
      clearExpiryDate: clearExpiryDate,
    );
    if (request.isEmpty) {
      return _repository.getMedicationById(mid);
    }
    return _repository.updateMedication(mid, request);
  }

  Future<void> deleteMedication(String medicationId) {
    final String mid = medicationId.trim();
    if (mid.isEmpty) {
      throw MedicationServiceException("Missing medication id");
    }
    return _repository.deleteMedication(mid);
  }
}

class MedicationServiceException implements Exception {
  MedicationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
