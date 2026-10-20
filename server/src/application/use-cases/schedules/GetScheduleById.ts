import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import type { Schedule } from '@domain/entities/Schedule';
import { NotFoundError } from '@shared/errors';

export class GetScheduleById {
  constructor(private readonly scheduleRepo: IScheduleRepository) {}

  public async execute(userId: string, scheduleId: string): Promise<Schedule> {
    const s = await this.scheduleRepo.findByIdAndUserId(scheduleId, userId);
    if (!s) {
      throw new NotFoundError('Schedule not found');
    }
    return s;
  }
}
