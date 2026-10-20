import type { Medication } from '@domain/entities/Medication';
import type { PaginationParams, PaginatedResult } from '@shared/types';

export type CreateMedicationData = Omit<Medication, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdateMedicationData = Partial<
  Omit<Medication, 'id' | 'patientId' | 'createdAt' | 'updatedAt'>
>;

export type MedicationIdentity = {
  patientId: string;
  name: string;
  dosage: string;
  form: Medication['form'];
  expiryDate: Date | null;
};

export interface IMedicationRepository {
  findById(id: string): Promise<Medication | null>;
  findByIdAndPatientId(id: string, patientId: string): Promise<Medication | null>;
  findByIdAndUserId(id: string, userId: string): Promise<Medication | null>;
  findDuplicate(
    identity: MedicationIdentity,
    options?: { excludeId?: string },
  ): Promise<Medication | null>;
  findAllByPatientId(
    patientId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Medication> | Medication[]>;
  findAllByUserId(
    userId: string,
    options?: { patientId?: string; params?: PaginationParams },
  ): Promise<PaginatedResult<Medication> | Medication[]>;
  create(data: CreateMedicationData): Promise<Medication>;
  update(id: string, data: UpdateMedicationData): Promise<Medication>;
  delete(id: string): Promise<void>;
}
