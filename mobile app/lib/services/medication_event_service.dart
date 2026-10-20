import "../data/repositories/medication_event_repository.dart";
import "../models/medication_event_model.dart";

class MedicationEventService {
  MedicationEventService({MedicationEventRepository? repository})
    : _repository = repository ?? MedicationEventRepository();

  final MedicationEventRepository _repository;

  Future<MedicationEventListResult> loadMedicationEvents({
    String? patientId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _repository.getMedicationEvents(
        patientId: patientId,
        limit: limit,
        offset: offset,
      );
    } on MedicationEventRepositoryException catch (e) {
      throw MedicationEventServiceException(e.message);
    }
  }
}

class MedicationEventServiceException implements Exception {
  MedicationEventServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
