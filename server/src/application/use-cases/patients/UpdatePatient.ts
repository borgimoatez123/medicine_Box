import type { IPatientRepository, UpdatePatientData } from '@domain/repositories/IPatientRepository';
import type { Patient } from '@domain/entities/Patient';
import { NotFoundError } from '@shared/errors';

export type UpdatePatientInput = {
  userId: string;
  patientId: string;
  fullName?: string;
  dateOfBirth?: Date | string | null;
  gender?: string | null;
  weightKg?: number | null;
  heightCm?: number | null;
  bloodType?: string | null;
  allergies?: string | null;
  notes?: string | null;
  avatarUrl?: string | null;
};

type UpdatePatientOutput = Patient;

const toDate = (v: Date | string | null | undefined): Date | null | undefined => {
  if (v === undefined) return undefined;
  if (v === null) return null;
  if (v instanceof Date) return v;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

export class UpdatePatient {
  constructor(private readonly patientRepo: IPatientRepository) {}

  public async execute(input: UpdatePatientInput): Promise<UpdatePatientOutput> {
    const existing = await this.patientRepo.findByIdAndUserId(input.patientId, input.userId);
    if (!existing) throw new NotFoundError('Patient not found');

    const patch: UpdatePatientData = {};
    if (input.fullName !== undefined) patch.fullName = input.fullName;
    if (input.dateOfBirth !== undefined) patch.dateOfBirth = toDate(input.dateOfBirth);
    if (input.gender !== undefined) patch.gender = input.gender;
    if (input.weightKg !== undefined) patch.weightKg = input.weightKg;
    if (input.heightCm !== undefined) patch.heightCm = input.heightCm;
    if (input.bloodType !== undefined) patch.bloodType = input.bloodType;
    if (input.allergies !== undefined) patch.allergies = input.allergies;
    if (input.notes !== undefined) patch.notes = input.notes;
    if (input.avatarUrl !== undefined) patch.avatarUrl = input.avatarUrl;

    return this.patientRepo.update(input.patientId, patch);
  }
}
