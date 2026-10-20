import type { Patient } from '@domain/entities/Patient';
import type { PaginationParams, PaginatedResult } from '@shared/types';

export type CreatePatientData = Omit<Patient, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdatePatientData = Partial<Omit<Patient, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>;

export interface IPatientRepository {
  findById(id: string): Promise<Patient | null>;
  findByIdAndUserId(id: string, userId: string): Promise<Patient | null>;
  findAllByUserId(
    userId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Patient> | Patient[]>;
  findFirstByUserId(userId: string): Promise<Patient | null>;
  create(data: CreatePatientData): Promise<Patient>;
  update(id: string, data: UpdatePatientData): Promise<Patient>;
  delete(id: string): Promise<void>;
}
