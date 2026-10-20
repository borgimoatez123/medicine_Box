import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError } from '@shared/errors';

export class GetMedicineBoxById {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(userId: string, boxId: string): Promise<MedicineBox> {
    const b = await this.medicineBoxRepo.findByIdAndUserId(boxId, userId);
    if (!b) throw new NotFoundError('Medicine box not found');
    return b;
  }
}
