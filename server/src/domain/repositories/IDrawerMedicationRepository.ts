import type { DrawerMedication } from '@domain/entities/DrawerMedication';

export type CreateDrawerMedicationData = Omit<
  DrawerMedication,
  'id' | 'createdAt' | 'updatedAt' | 'assignedAt' | 'isActive' | 'quantity' | 'missingQuantity'
> & {
  assignedAt?: Date;
  isActive?: boolean;
  quantity?: DrawerMedication['quantity'];
  missingQuantity?: DrawerMedication['missingQuantity'];
};

export type UpdateDrawerMedicationData = Partial<{
  isActive: boolean;
  quantity: DrawerMedication['quantity'];
  missingQuantity: DrawerMedication['missingQuantity'];
}>;

export type UpsertDrawerMedicationData = Omit<
  DrawerMedication,
  'id' | 'createdAt' | 'updatedAt' | 'assignedAt' | 'isActive' | 'quantity' | 'missingQuantity'
> & {
  assignedAt?: Date;
  isActive?: boolean;
  quantity?: DrawerMedication['quantity'];
  missingQuantity?: DrawerMedication['missingQuantity'];
};

export interface FindDrawerMedicationsOptions {
  drawerId?: string;
  medicationId?: string;
}

export interface IDrawerMedicationRepository {
  create(data: CreateDrawerMedicationData): Promise<DrawerMedication>;
  findById(id: string): Promise<DrawerMedication | null>;
  findByIdAndUserId(id: string, userId: string): Promise<DrawerMedication | null>;
  findAll(): Promise<DrawerMedication[]>;
  findAllByUserId(
    userId: string,
    options?: FindDrawerMedicationsOptions,
  ): Promise<DrawerMedication[]>;
  findAllByMedicineBoxId(medicineBoxId: string): Promise<DrawerMedication[]>;
  findByDrawerId(drawerId: string): Promise<DrawerMedication | null>;
  findByMedicationId(medicationId: string): Promise<DrawerMedication | null>;
  upsert(data: UpsertDrawerMedicationData): Promise<DrawerMedication>;
  update(id: string, data: UpdateDrawerMedicationData): Promise<DrawerMedication>;
  delete(id: string): Promise<void>;
}
