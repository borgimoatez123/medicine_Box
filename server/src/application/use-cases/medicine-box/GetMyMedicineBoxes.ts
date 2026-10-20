import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';

export class GetMyMedicineBoxes {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(userId: string): Promise<MedicineBox[]> {
    return this.medicineBoxRepo.findAllByUserId(userId);
  }
}
