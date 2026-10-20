import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import { NotFoundError } from '@shared/errors';

type DeletePatientInput = {
  userId: string;
  patientId: string;
};

export class DeletePatient {
  constructor(private readonly patientRepo: IPatientRepository) {}

  public async execute(input: DeletePatientInput): Promise<void> {
    const existing = await this.patientRepo.findByIdAndUserId(input.patientId, input.userId);
    if (!existing) throw new NotFoundError('Patient not found');
    await this.patientRepo.delete(input.patientId);
  }
}
