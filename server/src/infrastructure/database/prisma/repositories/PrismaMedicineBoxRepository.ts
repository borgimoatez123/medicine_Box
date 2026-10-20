import type {
  IMedicineBoxRepository,
  CreateMedicineBoxData,
  UpdateMedicineBoxData,
  AdminUpdateMedicineBoxData,
  ActivateResult,
  PublicMedicineBox,
  ReleaseOwnershipResult,
} from '@domain/repositories/IMedicineBoxRepository';
import type { MedicineBox, MedicineBoxStatus, DeviceStatus } from '@domain/entities/MedicineBox';
import { prisma } from '@infrastructure/database/prisma/client';
import type { MedicineBox as PrismaMedicineBox } from '@prisma/client';

export const toPublicMedicineBox = (box: MedicineBox): PublicMedicineBox => {
  const { deviceToken: _secret, ...safe } = box;
  void _secret;
  return safe;
};

export class PrismaMedicineBoxRepository implements IMedicineBoxRepository {
  async findById(id: string): Promise<MedicineBox | null> {
    const box = await prisma.medicineBox.findUnique({ where: { id } });
    return box ? this.toDomain(box) : null;
  }

  async findAll(): Promise<MedicineBox[]> {
    const data = await prisma.medicineBox.findMany({ orderBy: { createdAt: 'desc' } });
    return data.map((b) => this.toDomain(b));
  }

  async findAllByUserId(userId: string): Promise<MedicineBox[]> {
    const data = await prisma.medicineBox.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return data.map((b) => this.toDomain(b));
  }

  async findByDeviceId(deviceId: string): Promise<MedicineBox | null> {
    const box = await prisma.medicineBox.findUnique({ where: { deviceId } });
    return box ? this.toDomain(box) : null;
  }

  async findByIdAndUserId(id: string, userId: string): Promise<MedicineBox | null> {
    const box = await prisma.medicineBox.findFirst({
      where: { id, userId },
    });
    return box ? this.toDomain(box) : null;
  }

  async existsByDeviceId(deviceId: string): Promise<boolean> {
    const count = await prisma.medicineBox.count({ where: { deviceId } });
    return count > 0;
  }

  async create(data: CreateMedicineBoxData): Promise<MedicineBox> {
    const box = await prisma.medicineBox.create({
      data: {
        deviceId: data.deviceId,
        deviceToken: data.deviceToken,
        name: data.name,
        status: (data.status as MedicineBoxStatus) ?? 'READY',
        deviceStatus: (data.deviceStatus as DeviceStatus) ?? 'OFFLINE',
        lastSeenAt: data.lastSeenAt ?? null,
        userId: data.userId ?? null,
        numberOfDrawers: data.numberOfDrawers,
        drawerCapacity: data.drawerCapacity,
      },
    });
    return this.toDomain(box);
  }

  async update(id: string, data: UpdateMedicineBoxData): Promise<MedicineBox> {
    const patch: Record<string, unknown> = {};
    if (data.name !== undefined) patch.name = data.name;
    if (data.numberOfDrawers !== undefined) patch.numberOfDrawers = data.numberOfDrawers;
    if (data.drawerCapacity !== undefined) patch.drawerCapacity = data.drawerCapacity;
    const box = await prisma.medicineBox.update({ where: { id }, data: patch });
    return this.toDomain(box);
  }

  async adminUpdate(id: string, data: AdminUpdateMedicineBoxData): Promise<MedicineBox> {
    const patch: Record<string, unknown> = {};
    if (data.name !== undefined) patch.name = data.name;
    if (data.numberOfDrawers !== undefined) patch.numberOfDrawers = data.numberOfDrawers;
    if (data.drawerCapacity !== undefined) patch.drawerCapacity = data.drawerCapacity;
    if (data.status !== undefined) patch.status = data.status as MedicineBoxStatus;
    const box = await prisma.medicineBox.update({ where: { id }, data: patch });
    return this.toDomain(box);
  }

  async activateAtomic(deviceId: string, userId: string): Promise<ActivateResult> {
    const found = await prisma.medicineBox.findUnique({ where: { deviceId } });
    if (!found) return { kind: 'not-found' };
    try {
      const updated = await prisma.medicineBox.updateMany({
        where: {
          deviceId,
          userId: null,
          status: 'READY',
        },
        data: {
          userId,
          status: 'ACTIVE',
        },
      });
      if (updated.count === 0) {
        return { kind: 'already-owned' };
      }
      const box = await prisma.medicineBox.findUnique({ where: { deviceId } });
      if (!box) return { kind: 'not-found' };
      return { kind: 'success', box: this.toDomain(box) };
    } catch {
      const current = await prisma.medicineBox.findUnique({ where: { deviceId } });
      if (!current) return { kind: 'not-found' };
      if (current.userId !== null || current.status !== 'READY') {
        return { kind: 'already-owned' };
      }
      return { kind: 'already-owned' };
    }
  }

  async releaseOwnership(
    medicineBoxId: string,
    userId: string,
  ): Promise<ReleaseOwnershipResult> {
    try {
      const result = await prisma.$transaction(async (tx) => {
        const owned = await tx.medicineBox.findFirst({
          where: { id: medicineBoxId, userId },
          select: { id: true },
        });
        if (!owned) return { kind: 'not-found' as const };

        const drawers = await tx.drawer.findMany({
          where: { medicineBoxId },
          select: { id: true },
        });
        const drawerIds = drawers.map((d) => d.id);

        if (drawerIds.length > 0) {
          await tx.drawerMedication.deleteMany({
            where: { drawerId: { in: drawerIds } },
          });

          await tx.drawer.updateMany({
            where: { id: { in: drawerIds } },
            data: { status: 'EMPTY' },
          });
        }

        const updated = await tx.medicineBox.updateMany({
          where: { id: medicineBoxId, userId },
          data: {
            userId: null,
            status: 'READY',
          },
        });
        if (updated.count === 0) return { kind: 'not-found' as const };

        const box = await tx.medicineBox.findUnique({
          where: { id: medicineBoxId },
        });
        if (!box) return { kind: 'not-found' as const };
        return { kind: 'success' as const, box: this.toDomain(box) };
      });
      return result;
    } catch {
      const current = await prisma.medicineBox.findFirst({
        where: { id: medicineBoxId, userId },
      });
      if (!current) return { kind: 'not-found' };
      throw new Error('releaseOwnership transaction failed');
    }
  }

  async markDeviceSeen(deviceId: string): Promise<MedicineBox | null> {
    try {
      const box = await prisma.medicineBox.update({
        where: { deviceId },
        data: { deviceStatus: 'ACTIVE', lastSeenAt: new Date() },
      });
      return this.toDomain(box);
    } catch {
      return null;
    }
  }

  async markStaleDevicesOffline(thresholdMs: number): Promise<number> {
    const thresholdDate = new Date(Date.now() - thresholdMs);
    const result = await prisma.medicineBox.updateMany({
      where: {
        deviceStatus: 'ACTIVE',
        lastSeenAt: { lt: thresholdDate },
      },
      data: { deviceStatus: 'OFFLINE' },
    });
    return result.count;
  }

  private toDomain(model: PrismaMedicineBox): MedicineBox {
    return {
      id: model.id,
      deviceId: model.deviceId,
      deviceToken: model.deviceToken,
      name: model.name,
      status: model.status as MedicineBoxStatus,
      deviceStatus: model.deviceStatus as DeviceStatus,
      lastSeenAt: model.lastSeenAt,
      userId: model.userId,
      numberOfDrawers: model.numberOfDrawers,
      drawerCapacity: model.drawerCapacity,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
