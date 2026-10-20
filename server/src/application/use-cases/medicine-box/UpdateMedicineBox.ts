import type {
  IMedicineBoxRepository,
  UpdateMedicineBoxData,
} from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError } from '@shared/errors';

export class UpdateMedicineBox {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(
    userId: string,
    boxId: string,
    patch: UpdateMedicineBoxData,
  ): Promise<MedicineBox> {
    const existing = await this.medicineBoxRepo.findByIdAndUserId(boxId, userId);
    if (!existing) throw new NotFoundError('Medicine box not found');
    const data: UpdateMedicineBoxData = {};
    if (patch.name !== undefined) data.name = patch.name;
    return this.medicineBoxRepo.update(boxId, data);
  }
}
