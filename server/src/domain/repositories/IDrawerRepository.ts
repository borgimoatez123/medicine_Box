import type { Drawer } from '@domain/entities/Drawer';

export type CreateDrawerData = Omit<Drawer, 'id' | 'createdAt' | 'updatedAt' | 'status'> & {
  status?: Drawer['status'];
};

export type UpdateDrawerData = Partial<{
  status: Drawer['status'];
}>;

export interface FindDrawersOptions {
  medicineBoxId?: string;
}

export interface IDrawerRepository {
  findById(id: string): Promise<Drawer | null>;
  findAll(): Promise<Drawer[]>;
  findAllByMedicineBoxId(medicineBoxId: string): Promise<Drawer[]>;
  findAllByUserId(userId: string, options?: FindDrawersOptions): Promise<Drawer[]>;
  findByIdAndMedicineBoxId(id: string, medicineBoxId: string): Promise<Drawer | null>;
  findByIdAndUserId(id: string, userId: string): Promise<Drawer | null>;
  findByMedicineBoxIdAndDrawerNumber(
    medicineBoxId: string,
    drawerNumber: number,
  ): Promise<Drawer | null>;
  findNumbersByMedicineBoxId(medicineBoxId: string): Promise<number[]>;
  create(data: CreateDrawerData): Promise<Drawer>;
  createMany(data: CreateDrawerData[]): Promise<Drawer[]>;
  update(id: string, data: UpdateDrawerData): Promise<Drawer>;
}
