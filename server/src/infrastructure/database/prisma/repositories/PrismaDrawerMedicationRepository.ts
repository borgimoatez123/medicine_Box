import type {
  IDrawerMedicationRepository,
  CreateDrawerMedicationData,
  UpdateDrawerMedicationData,
  FindDrawerMedicationsOptions,
  UpsertDrawerMedicationData,
} from '@domain/repositories/IDrawerMedicationRepository';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import type { DrawerStatus } from '@domain/entities/Drawer';
import { prisma } from '@infrastructure/database/prisma/client';
import { ConflictError } from '@shared/errors/AppError';

const OWNERSHIP_WHERE = (userId: string) => ({
  drawer: { medicineBox: { userId } },
  medication: { patient: { userId } },
});

const DRAWER_OPERATIONAL_SET = new Set<DrawerStatus>(['LOCKED', 'DISPENSING', 'ERROR']);

const shouldSyncStatus = (status: DrawerStatus): boolean =>
  !DRAWER_OPERATIONAL_SET.has(status);

const computeTargetStatus = (active: boolean): DrawerStatus =>
  active ? 'LOADED' : 'EMPTY';

const drawerStatusPatch = (
  currentStatus: DrawerStatus,
  nextIsActive: boolean,
): DrawerStatus | null => {
  if (!shouldSyncStatus(currentStatus)) return null;
  const target = computeTargetStatus(nextIsActive);
  return currentStatus === target ? null : target;
};

export class PrismaDrawerMedicationRepository implements IDrawerMedicationRepository {
  async create(data: CreateDrawerMedicationData): Promise<DrawerMedication> {
    try {
      const now = new Date();
      const isActive = data.isActive ?? true;
      const drawerId = data.drawerId;
      const result = await prisma.$transaction(async (tx) => {
        const drawer = await tx.drawer.findUnique({ where: { id: drawerId } });
        const dm = await tx.drawerMedication.create({
          data: {
            assignedAt: now,
            isActive,
            drawerId: data.drawerId,
            medicationId: data.medicationId,
            quantity: data.quantity ?? null,
            missingQuantity: data.missingQuantity ?? null,
          },
        });
        if (drawer) {
          const target = drawerStatusPatch(drawer.status, isActive);
          if (target) {
            await tx.drawer.update({ where: { id: drawerId }, data: { status: target } });
          }
        }
        return dm;
      });
      return this.toDomain(result);
    } catch (err) {
      const e = err as { code?: string; meta?: { target?: string[] } };
      if (e?.code === 'P2002' && Array.isArray(e.meta?.target) && e.meta!.target.length > 0) {
        const targets = new Set(e.meta!.target);
        if (targets.has('drawerId') || targets.has('medicationId')) {
          throw new ConflictError('Drawer or medication already has an assignment');
        }
      }
      throw err;
    }
  }

  async findById(id: string): Promise<DrawerMedication | null> {
    const dm = await prisma.drawerMedication.findUnique({ where: { id } });
    return dm ? this.toDomain(dm) : null;
  }

  async findAll(): Promise<DrawerMedication[]> {
    const rows = await prisma.drawerMedication.findMany();
    return rows.map(this.toDomain);
  }

  async findByIdAndUserId(id: string, userId: string): Promise<DrawerMedication | null> {
    const dm = await prisma.drawerMedication.findFirst({
      where: { id, ...OWNERSHIP_WHERE(userId) },
    });
    return dm ? this.toDomain(dm) : null;
  }

  async findAllByUserId(
    userId: string,
    options?: FindDrawerMedicationsOptions,
  ): Promise<DrawerMedication[]> {
    const where: Record<string, unknown> = { ...OWNERSHIP_WHERE(userId) };
    if (options?.drawerId) where.drawerId = options.drawerId;
    if (options?.medicationId) where.medicationId = options.medicationId;
    const rows = await prisma.drawerMedication.findMany({ where });
    return rows.map(this.toDomain);
  }

  async findAllByMedicineBoxId(medicineBoxId: string): Promise<DrawerMedication[]> {
    const rows = await prisma.drawerMedication.findMany({
      where: { drawer: { medicineBoxId } },
    });
    return rows.map(this.toDomain);
  }

  async findByDrawerId(drawerId: string): Promise<DrawerMedication | null> {
    const dm = await prisma.drawerMedication.findUnique({ where: { drawerId } });
    return dm ? this.toDomain(dm) : null;
  }

  async findByMedicationId(medicationId: string): Promise<DrawerMedication | null> {
    const dm = await prisma.drawerMedication.findUnique({ where: { medicationId } });
    return dm ? this.toDomain(dm) : null;
  }

  async upsert(data: UpsertDrawerMedicationData): Promise<DrawerMedication> {
    try {
      const now = new Date();
      const drawerId = data.drawerId;
      const isActive = data.isActive ?? true;
      const result = await prisma.$transaction(async (tx) => {
        const drawer = await tx.drawer.findUnique({ where: { id: drawerId } });
        const dm = await tx.drawerMedication.upsert({
          where: { drawerId },
          create: {
            assignedAt: data.assignedAt ?? now,
            isActive,
            drawerId,
            medicationId: data.medicationId,
            quantity: data.quantity ?? null,
            missingQuantity: data.missingQuantity ?? null,
          },
          update: {
            medicationId: data.medicationId,
            assignedAt: data.assignedAt ?? now,
            isActive,
            quantity: data.quantity ?? null,
            missingQuantity: data.missingQuantity ?? null,
          },
        });
        if (drawer) {
          const target = drawerStatusPatch(drawer.status, isActive);
          if (target) {
            await tx.drawer.update({ where: { id: drawerId }, data: { status: target } });
          }
        }
        return dm;
      });
      return this.toDomain(result);
    } catch (err) {
      const e = err as { code?: string; meta?: { target?: string[] } };
      if (e?.code === 'P2002' && Array.isArray(e.meta?.target) && e.meta!.target.length > 0) {
        const targets = new Set(e.meta!.target);
        if (targets.has('drawerId') || targets.has('medicationId')) {
          throw new ConflictError('Drawer or medication already has an assignment');
        }
      }
      throw err;
    }
  }

  async update(id: string, data: UpdateDrawerMedicationData): Promise<DrawerMedication> {
    const patch: Record<string, unknown> = {};
    if (data.isActive !== undefined) patch.isActive = data.isActive;
    if ('quantity' in data) patch.quantity = data.quantity;
    if ('missingQuantity' in data) patch.missingQuantity = data.missingQuantity;
    if (Object.keys(patch).length === 0) {
      const dm = await prisma.drawerMedication.findUnique({ where: { id } });
      if (!dm) throw new ConflictError('Drawer medication not found');
      return this.toDomain(dm);
    }

    const result = await prisma.$transaction(async (tx) => {
      const dm = await tx.drawerMedication.update({ where: { id }, data: patch, include: { drawer: true } });
      const nextIsActive = (dm as { isActive: boolean }).isActive;
      const drawer = (dm as { drawer: { id: string; status: DrawerStatus } }).drawer;
      if (drawer && data.isActive !== undefined) {
        const target = drawerStatusPatch(drawer.status, nextIsActive);
        if (target) {
          await tx.drawer.update({ where: { id: drawer.id }, data: { status: target } });
        }
      }
      return dm;
    });
    return this.toDomain(result);
  }

  async delete(id: string): Promise<void> {
    await prisma.$transaction(async (tx) => {
      const dm = await tx.drawerMedication.findUnique({
        where: { id },
        include: { drawer: true },
      });
      if (!dm) return;
      const drawer = (dm as { drawer: { id: string; status: DrawerStatus } }).drawer;
      await tx.drawerMedication.delete({ where: { id } });
      if (drawer) {
        const target = drawerStatusPatch(drawer.status, false);
        if (target) {
          await tx.drawer.update({ where: { id: drawer.id }, data: { status: target } });
        }
      }
    });
  }

  private toDomain(model: {
    id: string;
    drawerId: string;
    medicationId: string;
    quantity: number | null;
    missingQuantity: number | null;
    assignedAt: Date;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
  }): DrawerMedication {
    return {
      id: model.id,
      drawerId: model.drawerId,
      medicationId: model.medicationId,
      quantity: model.quantity,
      missingQuantity: model.missingQuantity,
      assignedAt: model.assignedAt,
      isActive: model.isActive,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
