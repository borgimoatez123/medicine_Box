import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import { NotFoundError } from '@shared/errors';

type DeleteMedicationInput = {
  userId: string;
  medicationId: string;
};

type DeleteMedicationOutput = void;

export class DeleteMedication {
  constructor(private readonly medicationRepo: IMedicationRepository) {}

  public async execute(input: DeleteMedicationInput): Promise<DeleteMedicationOutput> {
    const existing = await this.medicationRepo.findByIdAndUserId(
      input.medicationId,
      input.userId,
    );
    if (!existing) throw new NotFoundError('Medication not found');
    await this.medicationRepo.delete(input.medicationId);
  }
}
