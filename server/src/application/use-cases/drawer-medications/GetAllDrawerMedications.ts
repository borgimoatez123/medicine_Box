import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';

export class GetAllDrawerMedications {
  constructor(private readonly drawerMedicationRepository: IDrawerMedicationRepository) {}

  async execute(): Promise<DrawerMedication[]> {
    return this.drawerMedicationRepository.findAll();
  }
}
