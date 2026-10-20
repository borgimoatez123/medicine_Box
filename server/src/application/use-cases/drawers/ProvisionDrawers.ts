import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { Drawer } from '@domain/entities/Drawer';
import { NotFoundError } from '@shared/errors';

export class ProvisionDrawers {
  constructor(
    private readonly drawerRepository: IDrawerRepository,
    private readonly medicineBoxRepository: IMedicineBoxRepository,
  ) {}

  async execute(medicineBoxId: string): Promise<Drawer[]> {
    const box = await this.medicineBoxRepository.findById(medicineBoxId);
    if (!box) throw new NotFoundError('MedicineBox not found');

    const { numberOfDrawers } = box;
    const existingNumbers = new Set(
      await this.drawerRepository.findNumbersByMedicineBoxId(medicineBoxId),
    );

    const missing: number[] = [];
    for (let n = 1; n <= numberOfDrawers; n += 1) {
      if (!existingNumbers.has(n)) missing.push(n);
    }

    if (missing.length === 0) {
      return this.drawerRepository.findAllByMedicineBoxId(medicineBoxId);
    }

    const payload = missing.map((drawerNumber) => ({
      medicineBoxId,
      drawerNumber,
      status: 'EMPTY' as const,
    }));

    await this.drawerRepository.createMany(payload);
    return this.drawerRepository.findAllByMedicineBoxId(medicineBoxId);
  }
}
