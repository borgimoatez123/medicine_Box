import type {
  IMedicineBoxRepository,
  AdminUpdateMedicineBoxData,
} from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError } from '@shared/errors';

export class AdminUpdateMedicineBox {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(
    boxId: string,
    patch: AdminUpdateMedicineBoxData,
  ): Promise<MedicineBox> {
    const existing = await this.medicineBoxRepo.findById(boxId);
    if (!existing) throw new NotFoundError('Medicine box not found');
    const data: AdminUpdateMedicineBoxData = {};
    if (patch.name !== undefined) data.name = patch.name;
    if (patch.numberOfDrawers !== undefined) data.numberOfDrawers = patch.numberOfDrawers;
    if (patch.drawerCapacity !== undefined) data.drawerCapacity = patch.drawerCapacity;
    return this.medicineBoxRepo.adminUpdate(boxId, data);
  }
}
