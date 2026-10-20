import type { MedicineBox } from '@domain/entities/MedicineBox';

export type CreateMedicineBoxData = Omit<
  MedicineBox,
  | 'id'
  | 'createdAt'
  | 'updatedAt'
  | 'status'
  | 'userId'
  | 'deviceStatus'
  | 'lastSeenAt'
> & {
  status?: MedicineBox['status'];
  userId?: string | null;
  deviceStatus?: MedicineBox['deviceStatus'];
  lastSeenAt?: MedicineBox['lastSeenAt'];
};

export type UpdateMedicineBoxData = Partial<
  Omit<
    MedicineBox,
    'id' | 'createdAt' | 'updatedAt' | 'deviceId' | 'deviceToken' | 'userId' | 'status'
  >
>;

export type AdminUpdateMedicineBoxData = Partial<
  Omit<
    MedicineBox,
    'id' | 'createdAt' | 'updatedAt' | 'deviceId' | 'deviceToken' | 'userId'
  >
> & {
  status?: MedicineBox['status'];
};

export type PublicMedicineBox = Omit<MedicineBox, 'deviceToken'>;

export type ActivateResult =
  | { kind: 'success'; box: MedicineBox }
  | { kind: 'wrong-token' }
  | { kind: 'not-found' }
  | { kind: 'already-owned' };

export type ReleaseOwnershipResult =
  | { kind: 'success'; box: MedicineBox }
  | { kind: 'not-found' };

export interface IMedicineBoxRepository {
  findById(id: string): Promise<MedicineBox | null>;
  findAllByUserId(userId: string): Promise<MedicineBox[]>;
  findAll(): Promise<MedicineBox[]>;
  findByDeviceId(deviceId: string): Promise<MedicineBox | null>;
  findByIdAndUserId(id: string, userId: string): Promise<MedicineBox | null>;
  existsByDeviceId(deviceId: string): Promise<boolean>;
  create(data: CreateMedicineBoxData): Promise<MedicineBox>;
  update(id: string, data: UpdateMedicineBoxData): Promise<MedicineBox>;
  adminUpdate(id: string, data: AdminUpdateMedicineBoxData): Promise<MedicineBox>;
  activateAtomic(
    deviceId: string,
    userId: string,
  ): Promise<ActivateResult>;
  releaseOwnership(
    medicineBoxId: string,
    userId: string,
  ): Promise<ReleaseOwnershipResult>;
  markDeviceSeen(deviceId: string): Promise<MedicineBox | null>;
  markStaleDevicesOffline(thresholdMs: number): Promise<number>;
}
