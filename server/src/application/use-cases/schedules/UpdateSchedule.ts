import type {
  IScheduleRepository,
  UpdateScheduleData,
} from '@domain/repositories/IScheduleRepository';
import type { Schedule } from '@domain/entities/Schedule';
import { NotFoundError } from '@shared/errors';

export class UpdateSchedule {
  constructor(private readonly scheduleRepo: IScheduleRepository) {}

  public async execute(
    userId: string,
    scheduleId: string,
    patch: UpdateScheduleData,
  ): Promise<Schedule> {
    const existing = await this.scheduleRepo.findByIdAndUserId(
      scheduleId,
      userId,
    );
    if (!existing) {
      throw new NotFoundError('Schedule not found');
    }

    const data: UpdateScheduleData = {};
    if (patch.dosage !== undefined) data.dosage = patch.dosage;
    if (patch.timesPerDay !== undefined) data.timesPerDay = patch.timesPerDay;
    if (patch.times !== undefined) data.times = patch.times;
    if (patch.startDate !== undefined) data.startDate = patch.startDate;
    if (Object.prototype.hasOwnProperty.call(patch, 'endDate'))
      data.endDate = patch.endDate;
    if (Object.prototype.hasOwnProperty.call(patch, 'daysOfWeek'))
      data.daysOfWeek = patch.daysOfWeek;
    if (patch.status !== undefined) data.status = patch.status;
    if (Object.prototype.hasOwnProperty.call(patch, 'notes'))
      data.notes = patch.notes;
    if (patch.refillReminder !== undefined) data.refillReminder = patch.refillReminder;
    if (patch.isActive !== undefined) data.isActive = patch.isActive;

    if (
      patch.endDate !== undefined &&
      patch.startDate === undefined &&
      patch.endDate !== null &&
      existing.startDate &&
      new Date(patch.endDate).getTime() < new Date(existing.startDate).getTime()
    ) {
      data.startDate = existing.startDate;
    }

    return this.scheduleRepo.update(scheduleId, data);
  }
}
