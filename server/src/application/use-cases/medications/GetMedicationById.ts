import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { Medication } from '@domain/entities/Medication';
import { NotFoundError } from '@shared/errors';

type GetMedicationByIdInput = {
  userId: string;
  medicationId: string;
};

type GetMedicationByIdOutput = Medication;

export class GetMedicationById {
  constructor(private readonly medicationRepo: IMedicationRepository) {}

  public async execute(input: GetMedicationByIdInput): Promise<GetMedicationByIdOutput> {
    const medication = await this.medicationRepo.findByIdAndUserId(
      input.medicationId,
      input.userId,
    );
    if (!medication) throw new NotFoundError('Medication not found');
    return medication;
  }
}
