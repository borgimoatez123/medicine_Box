import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError } from '@shared/errors';

export class GetDrawerMedicationByIdAdmin {
  constructor(private readonly drawerMedicationRepository: IDrawerMedicationRepository) {}

  async execute(id: string): Promise<DrawerMedication> {
    const assignment = await this.drawerMedicationRepository.findById(id);
    if (!assignment) throw new NotFoundError('Drawer medication not found');
    return assignment;
  }
}
