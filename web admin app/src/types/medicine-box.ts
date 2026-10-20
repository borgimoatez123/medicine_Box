export type MedicineBoxStatus = 'REGISTERED' | 'ACTIVE' | 'OFFLINE' | 'MAINTENANCE';

export interface MedicineBox {
  id: string;
  deviceId: string;
  name: string;
  status: MedicineBoxStatus;
  userId: string | null;
  numberOfDrawers: number;
  drawerCapacity: number;
  createdAt: Date | string;
  updatedAt: Date | string;
}

export interface CreateMedicineBoxRequest {
  deviceId: string;
  deviceToken: string;
  name: string;
  numberOfDrawers: number;
  drawerCapacity: number;
}

export interface UpdateMedicineBoxRequest {
  name?: string;
  numberOfDrawers?: number;
  drawerCapacity?: number;
}
