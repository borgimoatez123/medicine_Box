import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import { NotFoundError } from '@shared/errors';

export class DeleteSchedule {
  constructor(private readonly scheduleRepo: IScheduleRepository) {}

  public async execute(userId: string, scheduleId: string): Promise<void> {
    const existing = await this.scheduleRepo.findByIdAndUserId(
      scheduleId,
      userId,
    );
    if (!existing) {
      throw new NotFoundError('Schedule not found');
    }
    await this.scheduleRepo.delete(scheduleId);
  }
}
