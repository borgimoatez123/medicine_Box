import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError, ConflictError, BadRequestError } from '@shared/errors';

type AssignMedicationToDrawerInput = {
  userId: string;
  boxId: string;
  drawerId: string;
  medicationId: string;
  quantity: number;
  missingQuantity: number;
};

export type AssignMedicationToDrawerOutput = DrawerMedication;

export class AssignMedicationToDrawer {
  constructor(
    private readonly drawerMedicationRepo: IDrawerMedicationRepository,
    private readonly drawerRepo: IDrawerRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly medicationRepo: IMedicationRepository,
    private readonly patientRepo: IPatientRepository,
  ) {}

  async execute(input: AssignMedicationToDrawerInput): Promise<AssignMedicationToDrawerOutput> {
    const medicineBox = await this.medicineBoxRepo.findByIdAndUserId(input.boxId, input.userId);
    if (!medicineBox) {
      throw new NotFoundError('Medicine box not found');
    }

    const drawer = await this.drawerRepo.findByIdAndMedicineBoxId(input.drawerId, input.boxId);
    if (!drawer) {
      throw new NotFoundError('Drawer not found');
    }

    const medication = await this.medicationRepo.findById(input.medicationId);
    if (!medication) {
      throw new NotFoundError('Medication not found');
    }

    const patient = await this.patientRepo.findById(medication.patientId);
    if (!patient || patient.userId !== input.userId) {
      throw new NotFoundError('Medication not found');
    }

    const drawerCapacity: number = Number.isInteger(medicineBox.drawerCapacity) && medicineBox.drawerCapacity >= 0 ? medicineBox.drawerCapacity : 0;
    const medStock: number = Number.isInteger(medication.quantity) && medication.quantity >= 0 ? medication.quantity : 0;

    if (input.quantity > drawerCapacity) {
      throw new BadRequestError('Quantity exceeds drawer capacity');
    }
    if (input.quantity > medStock) {
      throw new BadRequestError('Quantity exceeds available medication stock');
    }

    const existingDrawer = await this.drawerMedicationRepo.findByDrawerId(input.drawerId);
    const existingMed = await this.drawerMedicationRepo.findByMedicationId(input.medicationId);
    if (existingDrawer || existingMed) {
      throw new ConflictError('Drawer or medication already has an assignment');
    }

    const created = await this.drawerMedicationRepo.create({
      drawerId: input.drawerId,
      medicationId: input.medicationId,
      quantity: input.quantity,
      missingQuantity: input.missingQuantity,
    });

    return created;
  }
}
