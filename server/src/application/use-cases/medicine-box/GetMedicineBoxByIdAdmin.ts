import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError } from '@shared/errors';

export class GetMedicineBoxByIdAdmin {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(boxId: string): Promise<MedicineBox> {
    const b = await this.medicineBoxRepo.findById(boxId);
    if (!b) throw new NotFoundError('Medicine box not found');
    return b;
  }
}
