import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError } from '@shared/errors';

export class UnassignMedicineBox {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(userId: string, medicineBoxId: string): Promise<MedicineBox> {
    const result = await this.medicineBoxRepo.releaseOwnership(medicineBoxId, userId);
    switch (result.kind) {
      case 'success':
        return result.box;
      case 'not-found':
        throw new NotFoundError('Medicine box not found');
      default:
        throw new NotFoundError('Medicine box not found');
    }
  }
}
