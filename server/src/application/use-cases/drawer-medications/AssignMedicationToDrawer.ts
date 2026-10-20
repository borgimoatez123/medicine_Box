import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError, ConflictError, BadRequestError } from '@shared/errors';

export type AssignMedicationToDrawerOutput = DrawerMedication;

export class AssignMedicationToDrawer {
  constructor(
    private readonly drawerMedicationRepository: IDrawerMedicationRepository,
    private readonly drawerRepository: IDrawerRepository,
    private readonly medicationRepository: IMedicationRepository,
    private readonly medicineBoxRepository: IMedicineBoxRepository,
  ) {}

  async execute(
    userId: string,
    data: { drawerId: string; medicationId: string; quantity: number; missingQuantity: number },
  ): Promise<AssignMedicationToDrawerOutput> {
    const [drawer, medication] = await Promise.all([
      this.drawerRepository.findByIdAndUserId(data.drawerId, userId),
      this.medicationRepository.findByIdAndUserId(data.medicationId, userId),
    ]);
    if (!drawer || !medication) throw new NotFoundError('Drawer or medication not found');

    const box = await this.medicineBoxRepository.findByIdAndUserId(drawer.medicineBoxId, userId);
    if (!box) throw new NotFoundError('Medicine box not found');

    const drawerCapacity: number = Number.isInteger(box.drawerCapacity) && box.drawerCapacity >= 0 ? box.drawerCapacity : 0;
    const medStock: number = Number.isInteger(medication.quantity) && medication.quantity >= 0 ? medication.quantity : 0;

    if (data.quantity > drawerCapacity) {
      throw new BadRequestError('Quantity exceeds drawer capacity');
    }
    if (data.quantity > medStock) {
      throw new BadRequestError('Quantity exceeds available medication stock');
    }

    const [drawerAssigned, medicationAssigned] = await Promise.all([
      this.drawerMedicationRepository.findByDrawerId(data.drawerId),
      this.drawerMedicationRepository.findByMedicationId(data.medicationId),
    ]);
    if (drawerAssigned || medicationAssigned) {
      throw new ConflictError('Drawer or medication already has an assignment');
    }

    const created = await this.drawerMedicationRepository.create({
      drawerId: data.drawerId,
      medicationId: data.medicationId,
      quantity: data.quantity,
      missingQuantity: data.missingQuantity,
    });

    return created;
  }
}
