export interface DrawerMedication {
  id: string;
  drawerId: string;
  medicationId: string;
  quantity: number | null;
  missingQuantity: number | null;
  assignedAt: Date;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
