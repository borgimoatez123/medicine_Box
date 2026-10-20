import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { Schedule, ScheduleStatus } from '@domain/entities/Schedule';
import { NotFoundError } from '@shared/errors';

export class CreateSchedule {
  constructor(
    private readonly scheduleRepo: IScheduleRepository,
    private readonly medicationRepo: IMedicationRepository,
  ) {}

  public async execute(
    userId: string,
    data: {
      medicationId: string;
      dosage: string;
      timesPerDay?: number | null;
      times?: unknown | null;
      startDate: Date;
      endDate?: Date | null;
      daysOfWeek?: unknown | null;
      status?: ScheduleStatus;
      notes?: string | null;
      refillReminder?: boolean;
      isActive?: boolean;
    },
  ): Promise<Schedule> {
    const owned = await this.medicationRepo.findByIdAndUserId(
      data.medicationId,
      userId,
    );
    if (!owned) {
      throw new NotFoundError('Medication not found');
    }

    const schedule = await this.scheduleRepo.create({
      medicationId: data.medicationId,
      dosage: data.dosage,
      timesPerDay: data.timesPerDay ?? null,
      times: data.times ?? null,
      startDate: data.startDate,
      endDate: data.endDate ?? null,
      daysOfWeek: data.daysOfWeek ?? null,
      status: data.status ?? 'ACTIVE',
      notes: data.notes ?? null,
      refillReminder: data.refillReminder ?? false,
      isActive: data.isActive ?? true,
    });

    return schedule;
  }
}
