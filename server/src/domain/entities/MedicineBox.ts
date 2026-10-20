export type MedicineBoxStatus = 'READY' | 'ACTIVE' | 'MAINTENANCE';
export type DeviceStatus = 'ACTIVE' | 'OFFLINE';

export interface MedicineBox {
  id: string;
  deviceId: string;
  deviceToken: string;
  name: string;
  status: MedicineBoxStatus;
  deviceStatus: DeviceStatus;
  lastSeenAt: Date | null;
  userId: string | null;
  numberOfDrawers: number;
  drawerCapacity: number;
  createdAt: Date;
  updatedAt: Date;
}
