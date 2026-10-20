import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { Schedule } from '@domain/entities/Schedule';
import type { PaginationParams, PaginatedResult } from '@shared/types';
import { NotFoundError } from '@shared/errors/AppError';

export class GetSchedules {
  constructor(
    private readonly scheduleRepo: IScheduleRepository,
    private readonly patientRepo?: IPatientRepository,
  ) {}

  public async execute(
    userId: string,
    options?: { medicationId?: string; patientId?: string; params?: PaginationParams },
  ): Promise<PaginatedResult<Schedule> | Schedule[]> {
    if (options?.patientId) {
      if (!this.patientRepo) {
        throw new NotFoundError('Patient not found');
      }
      const patient = await this.patientRepo.findByIdAndUserId(options.patientId, userId);
      if (!patient) {
        throw new NotFoundError('Patient not found');
      }
    }
    return this.scheduleRepo.findAllByUserId(userId, options);
  }
}
