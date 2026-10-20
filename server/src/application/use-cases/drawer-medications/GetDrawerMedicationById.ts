import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError } from '@shared/errors';

export class GetDrawerMedicationById {
  constructor(private readonly drawerMedicationRepository: IDrawerMedicationRepository) {}

  async execute(userId: string, id: string): Promise<DrawerMedication> {
    const assignment = await this.drawerMedicationRepository.findByIdAndUserId(id, userId);
    if (!assignment) throw new NotFoundError('Drawer medication not found');
    return assignment;
  }
}
