import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import {
  NotFoundError,
  UnauthorizedError,
  ConflictError,
} from '@shared/errors';

export class ActivateMedicineBox {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(
    userId: string,
    credentials: { deviceId: string; deviceToken: string },
  ): Promise<MedicineBox> {
    const existing = await this.medicineBoxRepo.findByDeviceId(credentials.deviceId);
    if (!existing) {
      throw new NotFoundError('Medicine box not found');
    }
    if (existing.deviceToken !== credentials.deviceToken) {
      throw new UnauthorizedError('Invalid device credentials');
    }
    if (existing.userId !== null && existing.userId !== userId) {
      throw new ConflictError('Medicine box already activated');
    }
    if (existing.status !== 'READY') {
      if (existing.userId === userId && existing.status === 'ACTIVE') {
        return existing;
      }
      if (existing.status === 'MAINTENANCE') {
        throw new ConflictError('Medicine box is under maintenance');
      }
      throw new ConflictError('Medicine box already activated');
    }
    const result = await this.medicineBoxRepo.activateAtomic(credentials.deviceId, userId);
    switch (result.kind) {
      case 'success':
        return result.box;
      case 'not-found':
        throw new NotFoundError('Medicine box not found');
      case 'already-owned':
        throw new ConflictError('Medicine box already activated');
      case 'wrong-token':
        throw new UnauthorizedError('Invalid device credentials');
      default:
        throw new ConflictError('Medicine box already activated');
    }
  }
}
