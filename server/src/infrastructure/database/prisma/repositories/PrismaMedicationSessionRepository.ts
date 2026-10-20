import type {
  IMedicationSessionRepository,
  CreateMedicationSessionData,
  UpdateMedicationSessionPatch,
  MarkSessionResultArgs,
  FindActiveForDrawerResult,
  CreateMedicationSessionWithOccurrenceData,
  MedicationEventFilters,
  MedicationEventPagination,
  MedicationEventListResult,
} from '@domain/repositories/IMedicationSessionRepository';
import type { MedicationSession } from '@domain/entities/MedicationSession';
import { prisma } from '@infrastructure/database/prisma/client';

const toDomain = (row: {
  id: string;
  scheduleId: string;
  patientId: string;
  medicationId: string;
  drawerId: string;
  scheduledAt: Date;
  startedAt: Date | null;
  completedAt: Date | null;
  quantityBefore: number;
  quantityAfter: number | null;
  result: unknown | null;
  occurrenceDate: Date | null;
  occurrenceTime: string | null;
}): MedicationSession => ({
  id: row.id,
  scheduleId: row.scheduleId,
  patientId: row.patientId,
  medicationId: row.medicationId,
  drawerId: row.drawerId,
  scheduledAt: row.scheduledAt,
  startedAt: row.startedAt,
  completedAt: row.completedAt,
  quantityBefore: row.quantityBefore,
  quantityAfter: row.quantityAfter,
  result: (row.result as MedicationSession['result']) ?? null,
  occurrenceDate: row.occurrenceDate ?? null,
  occurrenceTime: row.occurrenceTime ?? null,
});

export class PrismaMedicationSessionRepository implements IMedicationSessionRepository {
  async create(data: CreateMedicationSessionData): Promise<MedicationSession> {
    const row = await prisma.medicationSession.create({
      data: {
        scheduleId: data.scheduleId,
        patientId: data.patientId,
        medicationId: data.medicationId,
        drawerId: data.drawerId,
        scheduledAt: data.scheduledAt,
        startedAt: data.startedAt ?? null,
        quantityBefore: data.quantityBefore,
      },
    });
    return toDomain(row as Parameters<typeof toDomain>[0]);
  }

  async createWithOccurrence(data: CreateMedicationSessionWithOccurrenceData): Promise<MedicationSession> {
    const row = await prisma.medicationSession.create({
      data: {
        scheduleId: data.scheduleId,
        patientId: data.patientId,
        medicationId: data.medicationId,
        drawerId: data.drawerId,
        scheduledAt: data.scheduledAt,
        startedAt: data.startedAt ?? null,
        completedAt: data.completedAt ?? null,
        quantityBefore: data.quantityBefore,
        quantityAfter: data.quantityAfter ?? null,
        result: data.result ?? null,
        occurrenceDate: data.occurrenceDate ?? null,
        occurrenceTime: data.occurrenceTime ?? null,
      },
    });
    return toDomain(row as Parameters<typeof toDomain>[0]);
  }

  async findById(id: string): Promise<MedicationSession | null> {
    const row = await prisma.medicationSession.findUnique({ where: { id } });
    return row ? toDomain(row as Parameters<typeof toDomain>[0]) : null;
  }

  async findByOccurrence(
    scheduleId: string,
    occurrenceDate: Date,
    occurrenceTime: string,
  ): Promise<MedicationSession | null> {
    const row = await prisma.medicationSession.findFirst({
      where: { scheduleId, occurrenceDate, occurrenceTime },
    });
    return row ? toDomain(row as Parameters<typeof toDomain>[0]) : null;
  }

  async findActiveForDrawer(drawerId: string): Promise<FindActiveForDrawerResult> {
    const row = await prisma.medicationSession.findFirst({
      where: { drawerId, completedAt: null, result: null },
      orderBy: { scheduledAt: 'desc' },
    });
    if (!row) return { kind: 'none' };
    return { kind: 'found', session: toDomain(row as Parameters<typeof toDomain>[0]) };
  }

  async findLatestForSchedule(scheduleId: string): Promise<MedicationSession | null> {
    const row = await prisma.medicationSession.findFirst({
      where: { scheduleId },
      orderBy: { scheduledAt: 'desc' },
    });
    return row ? toDomain(row as Parameters<typeof toDomain>[0]) : null;
  }

  async update(id: string, patch: UpdateMedicationSessionPatch): Promise<MedicationSession | null> {
    const exists = await prisma.medicationSession.findUnique({ where: { id } });
    if (!exists) return null;
    const data: Record<string, unknown> = {};
    if ('startedAt' in patch) data.startedAt = patch.startedAt ?? null;
    if ('completedAt' in patch) data.completedAt = patch.completedAt ?? null;
    if ('quantityAfter' in patch) data.quantityAfter = patch.quantityAfter;
    if ('result' in patch) data.result = patch.result;
    if (Object.keys(data).length === 0) return toDomain(exists as Parameters<typeof toDomain>[0]);
    const updated = await prisma.medicationSession.update({ where: { id }, data });
    return toDomain(updated as Parameters<typeof toDomain>[0]);
  }

  async markResult(args: MarkSessionResultArgs): Promise<MedicationSession | null> {
    const now = new Date();
    return this.update(args.id, {
      result: args.result,
      completedAt: args.completedAt ?? now,
      quantityAfter: args.quantityAfter,
    });
  }

  async listByDrawer(drawerId: string, limit = 100): Promise<MedicationSession[]> {
    const rows = await prisma.medicationSession.findMany({
      where: { drawerId },
      orderBy: { scheduledAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => toDomain(r as Parameters<typeof toDomain>[0]));
  }

  async findMany(
    filters: MedicationEventFilters,
    pagination: MedicationEventPagination,
  ): Promise<MedicationEventListResult> {
    const where: Record<string, unknown> = {};

    if (filters.patientId) where.patientId = filters.patientId;
    if (filters.scheduleId) where.scheduleId = filters.scheduleId;
    if (filters.drawerId) where.drawerId = filters.drawerId;
    if (filters.result) where.result = filters.result;

    // deviceId is not a column on MedicationSession; it lives on
    // MedicineBox.deviceId, reached through Drawer.medicineBoxId.
    if (filters.deviceId) {
      where.drawer = { medicineBox: { deviceId: filters.deviceId } };
    }

    // Multi-tenant isolation: scope to patients owned by the authenticated user.
    if (filters.userId) {
      where.patient = { userId: filters.userId };
    }

    const [total, rows] = await Promise.all([
      prisma.medicationSession.count({ where }),
      prisma.medicationSession.findMany({
        where,
        orderBy: { scheduledAt: 'desc' },
        skip: pagination.offset,
        take: pagination.limit,
        include: {
          drawer: {
            select: {
              medicineBox: { select: { deviceId: true } },
            },
          },
        },
      }),
    ]);

    return {
      events: rows.map((r) => {
        const session = toDomain(r as Parameters<typeof toDomain>[0]);
        const deviceId =
          (r as { drawer?: { medicineBox?: { deviceId?: string | null } } })
            .drawer?.medicineBox?.deviceId ?? null;
        return { ...session, deviceId };
      }),
      total,
      limit: pagination.limit,
      offset: pagination.offset,
    };
  }
}
