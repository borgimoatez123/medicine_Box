import type { DeviceCommand, DeviceCommandType } from '@domain/entities/DeviceCommand';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDeviceCommandRepository } from '@domain/repositories/IDeviceCommandRepository';
import { NotFoundError } from '@shared/errors';

export type PendingDeviceCommandDTO = {
  commandId: string;
  type: DeviceCommandType;
  drawerId: string | null;
  reason: string | null;
  createdAt: Date;
};

export class GetPendingDeviceCommands {
  constructor(
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly commandRepo: IDeviceCommandRepository,
  ) {}

  async execute(deviceId: string): Promise<PendingDeviceCommandDTO[]> {
    const cleanDeviceId = deviceId.trim();
    const box = await this.medicineBoxRepo.findByDeviceId(cleanDeviceId);
    if (!box) {
      throw new NotFoundError('Device not found');
    }

    const commands = await this.commandRepo.findPendingByDeviceId(cleanDeviceId);
    if (commands.length > 0) {
      await this.commandRepo.markManyAsSentInTransaction(commands.map(c => c.id));
    }

    return commands.map(mapPending);
  }
}

const mapPending = (c: DeviceCommand): PendingDeviceCommandDTO => ({
  commandId: c.id,
  type: c.type,
  drawerId: c.drawerId,
  reason: c.reason,
  createdAt: c.createdAt,
});
