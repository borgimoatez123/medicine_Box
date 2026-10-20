import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import type { FindDrawerMedicationsOptions } from '@domain/repositories/IDrawerMedicationRepository';

export class GetMyDrawerMedications {
  constructor(private readonly drawerMedicationRepository: IDrawerMedicationRepository) {}

  async execute(userId: string, options?: FindDrawerMedicationsOptions): Promise<DrawerMedication[]> {
    return this.drawerMedicationRepository.findAllByUserId(userId, options);
  }
}
