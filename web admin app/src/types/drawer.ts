export type DrawerStatus = 'EMPTY' | 'LOADED' | 'LOCKED' | 'DISPENSING' | 'ERROR';

export interface Drawer {
  id: string;
  medicineBoxId: string;
  drawerNumber: number;
  status: DrawerStatus;
  createdAt: Date | string;
  updatedAt: Date | string;
}

export interface UpdateDrawerRequest {
  status?: DrawerStatus;
}
