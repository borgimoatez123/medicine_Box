import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { Medication, MedicationForm } from '@domain/entities/Medication';
import { ConflictError, NotFoundError } from '@shared/errors';

type CreateMedicationInput = {
  userId: string;
  patientId: string;
  name: string;
  dosage: string;
  form?: MedicationForm;
  quantity: number;
  expiryDate?: Date | null;
};

type CreateMedicationOutput = Medication;

export class CreateMedication {
  constructor(
    private readonly medicationRepo: IMedicationRepository,
    private readonly patientRepo: IPatientRepository,
  ) {}

  public async execute(input: CreateMedicationInput): Promise<CreateMedicationOutput> {
    const patient = await this.patientRepo.findByIdAndUserId(input.patientId, input.userId);
    if (!patient) throw new NotFoundError('Patient not found');

    const identity = {
      patientId: input.patientId,
      name: input.name,
      dosage: input.dosage,
      form: (input.form ?? 'TABLET') as Medication['form'],
      expiryDate: input.expiryDate ?? null,
    };

    const duplicate = await this.medicationRepo.findDuplicate(identity);
    if (duplicate) {
      throw new ConflictError('Medication already exists for this patient');
    }

    return this.medicationRepo.create({
      patientId: input.patientId,
      name: input.name,
      dosage: input.dosage,
      form: identity.form,
      quantity: input.quantity,
      expiryDate: identity.expiryDate,
    });
  }
}
