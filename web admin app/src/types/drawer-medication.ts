export interface DrawerMedication {
  id: string;
  drawerId: string;
  medicationId: string;
  assignedAt: Date | string;
  isActive: boolean;
  createdAt: Date | string;
  updatedAt: Date | string;
}
