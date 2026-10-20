import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { Medication } from '@domain/entities/Medication';
import type { PaginationParams, PaginatedResult } from '@shared/types';

type GetMedicationsInput = {
  userId: string;
  patientId?: string;
  pagination?: PaginationParams;
};

type GetMedicationsOutput = PaginatedResult<Medication> | Medication[];

export class GetMedications {
  constructor(private readonly medicationRepo: IMedicationRepository) {}

  public async execute(input: GetMedicationsInput): Promise<GetMedicationsOutput> {
    const result = await this.medicationRepo.findAllByUserId(input.userId, {
      patientId: input.patientId,
      params: input.pagination,
    });
    const arr: Medication[] = Array.isArray(result) ? result : result.data;
    if (input.patientId && arr.length === 0) {
      // Per §15: if patientId filter provided but zero results = cannot distinguish
      // "empty patient had no meds" vs "patient not owned". We still won't throw here
      // because the findAllByUserId query already enforced ownership. An empty
      // owned patient legitimately returns []. It's the query semantic we need.
    }
    return result;
  }
}
