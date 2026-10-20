import type { IMedicationSessionRepository } from '@domain/repositories/IMedicationSessionRepository';
import type { MedicationSessionResult } from '@domain/entities/MedicationSession';

export type GetMedicationEventsInput = {
  deviceId?: string;
  patientId?: string;
  scheduleId?: string;
  drawerId?: string;
  status?: string;
  limit?: number;
  offset?: number;
  /** Authenticated user id (from JWT). When set, results are scoped to that user's patients. */
  userId?: string;
};

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/**
 * Maps the API-facing status filter to the MedicationSessionResult enum value
 * stored in the database.
 *
 *   TAKEN           -> PATIENT_TAKEN
 *   MISSED          -> MISSED
 *   any enum value  -> itself
 */
const mapStatusToResult = (status: string): MedicationSessionResult | null => {
  switch (status) {
    case 'TAKEN':
      return 'PATIENT_TAKEN';
    case 'MISSED':
      return 'MISSED';
    case 'PATIENT_TAKEN':
    case 'PATIENT_SKIPPED':
    case 'FACE_RECOGNITION_FAILED':
    case 'DISPENSING_FAILED':
    case 'DEVICE_FAILURE':
      return status as MedicationSessionResult;
    default:
      return null;
  }
};

export class GetMedicationEvents {
  constructor(
    private readonly medicationSessionRepo: IMedicationSessionRepository,
  ) {}

  public async execute(input: GetMedicationEventsInput) {
    const limit = Math.min(
      Math.max(1, input.limit ?? DEFAULT_LIMIT),
      MAX_LIMIT,
    );
    const offset = Math.max(0, input.offset ?? 0);

    const result = input.status ? mapStatusToResult(input.status) : undefined;

    return this.medicationSessionRepo.findMany(
      {
        deviceId: input.deviceId,
        patientId: input.patientId,
        scheduleId: input.scheduleId,
        drawerId: input.drawerId,
        result: result ?? undefined,
        userId: input.userId,
      },
      { limit, offset },
    );
  }
}
