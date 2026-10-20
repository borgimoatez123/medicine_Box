import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { Patient } from '@domain/entities/Patient';
import type { PaginationParams, PaginatedResult } from '@shared/types';

type GetPatientsInput = {
  userId: string;
  page?: number;
  limit?: number;
};

type GetPatientsOutput = Patient[] | PaginatedResult<Patient>;

export class GetPatients {
  constructor(private readonly patientRepo: IPatientRepository) {}

  public async execute(input: GetPatientsInput): Promise<GetPatientsOutput> {
    const params: PaginationParams | undefined =
      input.page && input.limit ? { page: input.page, limit: input.limit } : undefined;
    return this.patientRepo.findAllByUserId(input.userId, params);
  }
}
