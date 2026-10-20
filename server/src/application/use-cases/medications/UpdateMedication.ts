import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { Medication, MedicationForm } from '@domain/entities/Medication';
import { ConflictError, NotFoundError } from '@shared/errors';

type UpdateMedicationInput = {
  userId: string;
  medicationId: string;
  data: {
    name?: string;
    dosage?: string;
    form?: MedicationForm;
    quantity?: number;
    expiryDate?: Date | null;
  };
};

type UpdateMedicationOutput = Medication;

export class UpdateMedication {
  constructor(private readonly medicationRepo: IMedicationRepository) {}

  public async execute(input: UpdateMedicationInput): Promise<UpdateMedicationOutput> {
    const existing = await this.medicationRepo.findByIdAndUserId(
      input.medicationId,
      input.userId,
    );
    if (!existing) throw new NotFoundError('Medication not found');

    const patch: Record<string, unknown> = {};
    if (input.data.name !== undefined) patch.name = input.data.name;
    if (input.data.dosage !== undefined) patch.dosage = input.data.dosage;
    if (input.data.form !== undefined) patch.form = input.data.form;
    if (input.data.quantity !== undefined) patch.quantity = input.data.quantity;
    if (Object.prototype.hasOwnProperty.call(input.data, 'expiryDate')) {
      patch.expiryDate = input.data.expiryDate;
    }

    const identityChanging =
      'name' in patch ||
      'dosage' in patch ||
      'form' in patch ||
      'expiryDate' in patch;

    if (identityChanging) {
      const candidateIdentity = {
        patientId: existing.patientId,
        name: (patch.name as string) ?? existing.name,
        dosage: (patch.dosage as string) ?? existing.dosage,
        form: (patch.form as Medication['form']) ?? existing.form,
        expiryDate:
          'expiryDate' in patch ? (patch.expiryDate as Date | null) : existing.expiryDate,
      };
      const collision = await this.medicationRepo.findDuplicate(candidateIdentity, {
        excludeId: existing.id,
      });
      if (collision) {
        throw new ConflictError('Medication already exists for this patient');
      }
    }

    return this.medicationRepo.update(input.medicationId, patch);
  }
}
