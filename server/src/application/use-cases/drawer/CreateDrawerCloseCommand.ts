import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDeviceCommandRepository } from '@domain/repositories/IDeviceCommandRepository';
import type { DeviceCommand } from '@domain/entities/DeviceCommand';
import { BadRequestError, NotFoundError } from '@shared/errors';

export type CreateDrawerCloseCommandResult = DeviceCommand;

export class CreateDrawerCloseCommand {
  constructor(
    private readonly drawerRepo: IDrawerRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly commandRepo: IDeviceCommandRepository,
  ) {}

  async execute(
    userId: string,
    drawerId: string,
    reason?: string | null,
  ): Promise<CreateDrawerCloseCommandResult> {
    const cleanDrawerId = drawerId.trim();
    const drawer = await this.drawerRepo.findByIdAndUserId(cleanDrawerId, userId);
    if (!drawer) {
      throw new NotFoundError('Drawer not found');
    }

    const box = await this.medicineBoxRepo.findById(drawer.medicineBoxId);
    if (!box || box.userId !== userId) {
      throw new NotFoundError('Drawer not found');
    }

    const boxDeviceId = (box.deviceId ?? '').trim();
    if (!boxDeviceId) {
      throw new BadRequestError(
        'Cannot close drawer: the MedicineBox has no deviceId associated; configure a device first.',
      );
    }

    const created = await this.commandRepo.create({
      deviceId: boxDeviceId,
      drawerId: cleanDrawerId,
      type: 'CLOSE_DRAWER',
      status: 'PENDING',
      reason: reason && reason.trim() ? reason.trim() : 'MANUAL',
    });

    return created;
  }
}
