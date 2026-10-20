import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { ConflictError } from '@shared/errors';

export class AddMedicineBox {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(data: {
    deviceId: string;
    deviceToken: string;
    name: string;
    numberOfDrawers: number;
    drawerCapacity: number;
  }): Promise<MedicineBox> {
    const existing = await this.medicineBoxRepo.existsByDeviceId(data.deviceId);
    if (existing) {
      throw new ConflictError('Device ID already registered');
    }
    return this.medicineBoxRepo.create({
      deviceId: data.deviceId,
      deviceToken: data.deviceToken,
      name: data.name,
      status: 'READY',
      userId: null,
      numberOfDrawers: data.numberOfDrawers,
      drawerCapacity: data.drawerCapacity,
    });
  }
}
