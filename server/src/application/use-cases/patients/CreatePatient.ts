import type { IPatientRepository, CreatePatientData } from '@domain/repositories/IPatientRepository';
import type { Patient } from '@domain/entities/Patient';

export type CreatePatientInput = {
  userId: string;
  fullName: string;
  dateOfBirth?: Date | string | null;
  gender?: string | null;
  weightKg?: number | null;
  heightCm?: number | null;
  bloodType?: string | null;
  allergies?: string | null;
  notes?: string | null;
  avatarUrl?: string | null;
};

type CreatePatientOutput = Patient;

const toDate = (v: Date | string | null | undefined): Date | null => {
  if (v === undefined || v === null) return null;
  if (v instanceof Date) return v;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

export class CreatePatient {
  constructor(private readonly patientRepo: IPatientRepository) {}

  public async execute(input: CreatePatientInput): Promise<CreatePatientOutput> {
    const data: CreatePatientData = {
      userId: input.userId,
      fullName: input.fullName,
      dateOfBirth: toDate(input.dateOfBirth),
      gender: input.gender ?? null,
      weightKg: input.weightKg ?? null,
      heightCm: input.heightCm ?? null,
      bloodType: input.bloodType ?? null,
      allergies: input.allergies ?? null,
      notes: input.notes ?? null,
      avatarUrl: input.avatarUrl ?? null,
    };
    return this.patientRepo.create(data);
  }
}
