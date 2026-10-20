import type { Schedule } from '@domain/entities/Schedule';
import type { PaginationParams, PaginatedResult } from '@shared/types';

export type CreateScheduleData = Omit<Schedule, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdateScheduleData = Partial<
  Omit<Schedule, 'id' | 'createdAt' | 'updatedAt' | 'medicationId'>
>;

export type ScheduleDeviceSyncMedicationInfo = {
  id: string;
  name: string;
};

export type ScheduleDeviceSyncDrawerMedicationInfo = {
  id: string;
  drawerId: string;
  quantity: number;
  isActive: boolean;
  drawer: {
    medicineBoxId: string;
  };
};

export type ScheduleDeviceSyncRow = {
  schedule: Schedule;
  medication: ScheduleDeviceSyncMedicationInfo;
  drawerMedication: ScheduleDeviceSyncDrawerMedicationInfo | null;
};

export interface IScheduleRepository {
  findById(id: string): Promise<Schedule | null>;
  findByIdAndUserId(id: string, userId: string): Promise<Schedule | null>;
  findAllByUserId(
    userId: string,
    options?: { medicationId?: string; patientId?: string; params?: PaginationParams },
  ): Promise<PaginatedResult<Schedule> | Schedule[]>;
  findAllActiveByPatientIdForDeviceSync(patientId: string): Promise<ScheduleDeviceSyncRow[]>;
  findAllByMedicationId(
    medicationId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Schedule> | Schedule[]>;
  findByIdAndMedicationId(id: string, medicationId: string): Promise<Schedule | null>;
  create(data: CreateScheduleData): Promise<Schedule>;
  update(id: string, data: UpdateScheduleData): Promise<Schedule>;
  delete(id: string): Promise<void>;
}
