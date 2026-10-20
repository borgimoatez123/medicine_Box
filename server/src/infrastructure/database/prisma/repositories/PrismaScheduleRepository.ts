import type {
  IScheduleRepository,
  CreateScheduleData,
  UpdateScheduleData,
  ScheduleDeviceSyncRow,
} from '@domain/repositories/IScheduleRepository';
import type { Schedule } from '@domain/entities/Schedule';
import type { PaginationParams, PaginatedResult } from '@shared/types';
import { calculatePagination, buildPaginatedResult } from '@shared/utils';
import { prisma } from '@infrastructure/database/prisma/client';
import { Prisma, type Schedule as PrismaSchedule } from '@prisma/client';

export class PrismaScheduleRepository implements IScheduleRepository {
  async findById(id: string): Promise<Schedule | null> {
    const s = await prisma.schedule.findUnique({ where: { id } });
    return s ? this.toDomain(s) : null;
  }

  async findByIdAndUserId(id: string, userId: string): Promise<Schedule | null> {
    const s = await prisma.schedule.findFirst({
      where: {
        id,
        medication: {
          patient: { userId },
        },
      },
    });
    return s ? this.toDomain(s) : null;
  }

  async findAllByUserId(
    userId: string,
    options?: { medicationId?: string; patientId?: string; params?: PaginationParams },
  ): Promise<PaginatedResult<Schedule> | Schedule[]> {
    const medicationPatientFilter: Record<string, unknown> = { userId };
    if (options?.patientId) {
      (medicationPatientFilter as { id?: string }).id = options.patientId;
    }
    const medicationFilter: Record<string, unknown> = options?.medicationId
      ? { id: options.medicationId, patient: medicationPatientFilter }
      : { patient: medicationPatientFilter };
    const where: Prisma.ScheduleWhereInput = {
      medication: medicationFilter,
    };

    if (!options?.params) {
      const data = await prisma.schedule.findMany({ where });
      return data.map((m) => this.toDomain(m));
    }
    const { skip, take, page, limit } = calculatePagination(options.params);
    const [total, data] = await Promise.all([
      prisma.schedule.count({ where }),
      prisma.schedule.findMany({ where, skip, take }),
    ]);
    return buildPaginatedResult(
      data.map((m) => this.toDomain(m)),
      total,
      page,
      limit,
    );
  }

  async findByIdAndMedicationId(
    id: string,
    medicationId: string,
  ): Promise<Schedule | null> {
    const s = await prisma.schedule.findFirst({
      where: { id, medicationId },
    });
    return s ? this.toDomain(s) : null;
  }

  async findAllByMedicationId(
    medicationId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Schedule> | Schedule[]> {
    if (!params) {
      const data = await prisma.schedule.findMany({ where: { medicationId } });
      return data.map((m) => this.toDomain(m));
    }
    const { skip, take, page, limit } = calculatePagination(params);
    const [total, data] = await Promise.all([
      prisma.schedule.count({ where: { medicationId } }),
      prisma.schedule.findMany({ where: { medicationId }, skip, take }),
    ]);
    return buildPaginatedResult(
      data.map((m) => this.toDomain(m)),
      total,
      page,
      limit,
    );
  }

  async findAllActiveByPatientIdForDeviceSync(patientId: string): Promise<ScheduleDeviceSyncRow[]> {
    const rows = await prisma.schedule.findMany({
      where: {
        status: 'ACTIVE',
        isActive: true,
        medication: { patientId },
      },
      include: {
        medication: {
          select: {
            id: true,
            name: true,
            drawerMedication: {
              where: { isActive: true },
              select: {
                id: true,
                drawerId: true,
                quantity: true,
                isActive: true,
                drawer: {
                  select: {
                    id: true,
                    medicineBoxId: true,
                  },
                },
              },
            },
          },
        },
      },
    });

    return rows.map((prismaRow): ScheduleDeviceSyncRow => {
      const dm = prismaRow.medication.drawerMedication;
      return {
        schedule: this.toDomain(prismaRow),
        medication: {
          id: prismaRow.medication.id,
          name: prismaRow.medication.name,
        },
        drawerMedication: dm ? {
          id: dm.id,
          drawerId: dm.drawerId,
          quantity: dm.quantity ?? 0,
          isActive: dm.isActive,
          drawer: {
            medicineBoxId: dm.drawer.medicineBoxId,
          },
        } : null,
      };
    });
  }

  async create(data: CreateScheduleData): Promise<Schedule> {
    const input: Prisma.ScheduleUncheckedCreateInput = {
      medicationId: data.medicationId,
      dosage: data.dosage,
      timesPerDay: data.timesPerDay,
      times: data.times === null ? Prisma.JsonNull : (data.times),
      startDate: data.startDate,
      endDate: data.endDate,
      daysOfWeek: data.daysOfWeek === null ? Prisma.JsonNull : (data.daysOfWeek),
      status: data.status,
      notes: data.notes,
      refillReminder: data.refillReminder,
      isActive: data.isActive,
    };
    const s = await prisma.schedule.create({ data: input });
    return this.toDomain(s);
  }

  async update(id: string, data: UpdateScheduleData): Promise<Schedule> {
    const input: Prisma.ScheduleUncheckedUpdateInput = {};
    if (data.dosage !== undefined) input.dosage = data.dosage;
    if (data.timesPerDay !== undefined) input.timesPerDay = data.timesPerDay;
    if (data.times !== undefined)
      input.times = data.times === null ? Prisma.JsonNull : (data.times);
    if (data.startDate !== undefined) input.startDate = data.startDate;
    if (data.endDate !== undefined) input.endDate = data.endDate;
    if (data.daysOfWeek !== undefined)
      input.daysOfWeek = data.daysOfWeek === null ? Prisma.JsonNull : (data.daysOfWeek);
    if (data.status !== undefined) input.status = data.status;
    if (data.notes !== undefined) input.notes = data.notes;
    if (data.refillReminder !== undefined) input.refillReminder = data.refillReminder;
    if (data.isActive !== undefined) input.isActive = data.isActive;
    const s = await prisma.schedule.update({ where: { id }, data: input });
    return this.toDomain(s);
  }

  async delete(id: string): Promise<void> {
    await prisma.schedule.delete({ where: { id } });
  }

  private toDomain(model: PrismaSchedule): Schedule {
    return {
      id: model.id,
      medicationId: model.medicationId,
      dosage: model.dosage,
      timesPerDay: model.timesPerDay,
      times: (model.times) ?? null,
      startDate: model.startDate,
      endDate: model.endDate,
      daysOfWeek: (model.daysOfWeek) ?? null,
      status: model.status,
      notes: model.notes,
      refillReminder: model.refillReminder,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isActive: model.isActive,
    };
  }
}
