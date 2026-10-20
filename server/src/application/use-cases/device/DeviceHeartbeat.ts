import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { DeviceStatus } from '@domain/entities/MedicineBox';
import { NotFoundError, BadRequestError } from '@shared/errors';

export type HeartbeatResult = {
  deviceId: string;
  status: DeviceStatus;
  lastSeen: Date;
};

export class DeviceHeartbeat {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(deviceId: string): Promise<HeartbeatResult> {
    const trimmed = deviceId?.trim() ?? '';
    if (trimmed.length === 0) {
      throw new BadRequestError('deviceId is required');
    }

    const existing = await this.medicineBoxRepo.findByDeviceId(trimmed);
    if (!existing) {
      throw new NotFoundError('Device not found');
    }

    const updated = await this.medicineBoxRepo.markDeviceSeen(trimmed);
    if (!updated) {
      throw new NotFoundError('Device not found');
    }

    return {
      deviceId: updated.deviceId,
      status: updated.deviceStatus,
      lastSeen: updated.lastSeenAt ?? new Date(),
    };
  }
}
