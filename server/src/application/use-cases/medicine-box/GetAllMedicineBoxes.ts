import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';

export class GetAllMedicineBoxes {
  constructor(private readonly medicineBoxRepo: IMedicineBoxRepository) {}

  public async execute(): Promise<MedicineBox[]> {
    return this.medicineBoxRepo.findAll();
  }
}
