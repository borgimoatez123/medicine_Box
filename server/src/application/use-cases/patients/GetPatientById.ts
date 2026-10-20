import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { Patient } from '@domain/entities/Patient';
import { NotFoundError } from '@shared/errors';

type GetPatientByIdInput = {
  userId: string;
  patientId: string;
};

type GetPatientByIdOutput = Patient;

export class GetPatientById {
  constructor(private readonly patientRepo: IPatientRepository) {}

  public async execute(input: GetPatientByIdInput): Promise<GetPatientByIdOutput> {
    const patient = await this.patientRepo.findByIdAndUserId(input.patientId, input.userId);
    if (!patient) throw new NotFoundError('Patient not found');
    return patient;
  }
}
