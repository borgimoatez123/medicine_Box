export type DrawerStatus = 'EMPTY' | 'LOADED' | 'LOCKED' | 'DISPENSING' | 'ERROR';

export interface Drawer {
  id: string;
  medicineBoxId: string;
  drawerNumber: number;
  status: DrawerStatus;
  createdAt: Date;
  updatedAt: Date;
}
