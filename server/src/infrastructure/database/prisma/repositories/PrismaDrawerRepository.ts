import type {
  IDrawerRepository,
  CreateDrawerData,
  UpdateDrawerData,
  FindDrawersOptions,
} from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';
import { prisma } from '@infrastructure/database/prisma/client';

export class PrismaDrawerRepository implements IDrawerRepository {
  async findById(id: string): Promise<Drawer | null> {
    const d = await prisma.drawer.findUnique({ where: { id } });
    return d ? this.toDomain(d) : null;
  }

  async findAll(): Promise<Drawer[]> {
    const data = await prisma.drawer.findMany({
      orderBy: [
        { medicineBoxId: 'asc' },
        { drawerNumber: 'asc' },
      ],
    });
    return data.map(this.toDomain);
  }

  async findAllByMedicineBoxId(medicineBoxId: string): Promise<Drawer[]> {
    const data = await prisma.drawer.findMany({
      where: { medicineBoxId },
      orderBy: { drawerNumber: 'asc' },
    });
    return data.map(this.toDomain);
  }

  async findAllByUserId(userId: string, options?: FindDrawersOptions): Promise<Drawer[]> {
    const where: Record<string, unknown> = {
      medicineBox: { userId },
    };
    if (options?.medicineBoxId) {
      where.medicineBoxId = options.medicineBoxId;
    }
    const data = await prisma.drawer.findMany({
      where,
      orderBy: [
        { medicineBoxId: 'asc' },
        { drawerNumber: 'asc' },
      ],
    });
    return data.map(this.toDomain);
  }

  async findByIdAndMedicineBoxId(id: string, medicineBoxId: string): Promise<Drawer | null> {
    const d = await prisma.drawer.findFirst({
      where: { id, medicineBoxId },
    });
    return d ? this.toDomain(d) : null;
  }

  async findByIdAndUserId(id: string, userId: string): Promise<Drawer | null> {
    const d = await prisma.drawer.findFirst({
      where: {
        id,
        medicineBox: { userId },
      },
    });
    return d ? this.toDomain(d) : null;
  }

  async findByMedicineBoxIdAndDrawerNumber(
    medicineBoxId: string,
    drawerNumber: number,
  ): Promise<Drawer | null> {
    const d = await prisma.drawer.findUnique({
      where: {
        medicineBoxId_drawerNumber: { medicineBoxId, drawerNumber },
      },
    });
    return d ? this.toDomain(d) : null;
  }

  async findNumbersByMedicineBoxId(medicineBoxId: string): Promise<number[]> {
    const rows = await prisma.drawer.findMany({
      where: { medicineBoxId },
      select: { drawerNumber: true },
    });
    return rows.map((r) => r.drawerNumber);
  }

  async create(data: CreateDrawerData): Promise<Drawer> {
    const d = await prisma.drawer.create({ data });
    return this.toDomain(d);
  }

  async createMany(data: CreateDrawerData[]): Promise<Drawer[]> {
    if (data.length === 0) return [];
    const rows = await prisma.$transaction(
      data.map((d) => prisma.drawer.create({ data: d })),
    );
    return rows.map(this.toDomain);
  }

  async update(id: string, data: UpdateDrawerData): Promise<Drawer> {
    const patch: Record<string, unknown> = {};
    if (data.status !== undefined) patch.status = data.status;
    const d = await prisma.drawer.update({ where: { id }, data: patch });
    return this.toDomain(d);
  }

  private toDomain(model: {
    id: string;
    medicineBoxId: string;
    drawerNumber: number;
    status: Drawer['status'];
    createdAt: Date;
    updatedAt: Date;
  }): Drawer {
    return {
      id: model.id,
      medicineBoxId: model.medicineBoxId,
      drawerNumber: model.drawerNumber,
      status: model.status,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
