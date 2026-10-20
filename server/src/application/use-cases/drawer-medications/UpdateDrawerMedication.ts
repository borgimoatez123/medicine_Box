import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import type { UpdateDrawerMedicationData } from '@domain/repositories/IDrawerMedicationRepository';
import { NotFoundError } from '@shared/errors';

export class UpdateDrawerMedication {
  constructor(
    private readonly drawerMedicationRepository: IDrawerMedicationRepository,
    private readonly drawerRepository: IDrawerRepository,
    private readonly medicineBoxRepository: IMedicineBoxRepository,
  ) {}

  async execute(
    userId: string,
    id: string,
    data: UpdateDrawerMedicationData,
  ): Promise<DrawerMedication> {
    const owned = await this.drawerMedicationRepository.findByIdAndUserId(id, userId);
    if (!owned) throw new NotFoundError('Drawer medication not found');
    const drawer = await this.drawerRepository.findByIdAndUserId(owned.drawerId, userId);
    if (!drawer) throw new NotFoundError('Drawer not found');
    const box = await this.medicineBoxRepository.findByIdAndUserId(drawer.medicineBoxId, userId);
    if (!box) throw new NotFoundError('Medicine box not found');
    return this.drawerMedicationRepository.update(id, data);
  }
}
