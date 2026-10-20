import type {
  IDeviceMedicationEventProcessor,
  ProcessDeviceMedicationEventInput,
  ProcessDeviceMedicationEventOutput,
} from '@domain/services/IDeviceMedicationEventProcessor';
import type { MedicationSession } from '@domain/entities/MedicationSession';
import type { DrawerStatus } from '@domain/entities/Drawer';
import type { MedicationSessionResult } from '@domain/entities/MedicationSession';
import { prisma } from '@infrastructure/database/prisma/client';
import { ConflictError } from '@shared/errors/AppError';

const DRAWER_OPERATIONAL_SET = new Set<DrawerStatus>(['LOCKED', 'DISPENSING', 'ERROR']);

const shouldSyncStatus = (status: DrawerStatus): boolean => !DRAWER_OPERATIONAL_SET.has(status);

const sessionToDomain = (row: {
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
  result: (row.result as MedicationSessionResult | null) ?? null,
  occurrenceDate: row.occurrenceDate ?? null,
  occurrenceTime: row.occurrenceTime ?? null,
});

export class PrismaDeviceMedicationEventProcessor implements IDeviceMedicationEventProcessor {
  async processEvent(
    input: ProcessDeviceMedicationEventInput,
  ): Promise<ProcessDeviceMedicationEventOutput> {
    const {
      status,
      quantityTaken,
      drawerMedicationId,
      currentQuantity,
      drawerCapacity,
      scheduleId,
      patientId,
      medicationId,
      drawerId,
      scheduledAt,
      occurrenceDate,
      occurrenceTime,
    } = input;

    const now = new Date();
    const isTaken = status === 'TAKEN';
    const newQuantity = isTaken ? currentQuantity - quantityTaken : currentQuantity;
    const missingQuantity = isTaken ? Math.max(0, drawerCapacity - newQuantity) : Math.max(0, drawerCapacity - currentQuantity);
    const refillRequired = isTaken ? newQuantity === 0 : false;

    const sessionResult: MedicationSessionResult = isTaken ? 'PATIENT_TAKEN' : 'MISSED';

    try {
      const result = await prisma.$transaction(async (tx) => {
        if (isTaken) {
          const dmRow = await tx.drawerMedication.findUnique({
            where: { id: drawerMedicationId },
            select: { id: true, quantity: true, drawerId: true },
          });
          const dmQty = (dmRow?.quantity ?? 0) as number;
          if (dmQty < quantityTaken) {
            throw new ConflictError('Insufficient medication quantity');
          }
        }

        let sessionRow: Parameters<typeof sessionToDomain>[0];
        let duplicate = false;

        try {
          sessionRow = (await tx.medicationSession.create({
            data: {
              scheduleId,
              patientId,
              medicationId,
              drawerId,
              scheduledAt,
              startedAt: now,
              completedAt: now,
              quantityBefore: currentQuantity,
              quantityAfter: newQuantity,
              result: sessionResult,
              occurrenceDate: occurrenceDate ?? null,
              occurrenceTime: occurrenceTime ?? null,
            },
          })) as Parameters<typeof sessionToDomain>[0];
        } catch (createErr) {
          const e = createErr as { code?: string; meta?: { target?: string[] } };
          const isUniqueViolation =
            e?.code === 'P2002' &&
            Array.isArray(e.meta?.target) &&
            (e.meta!.target as string[]).includes('MedicationSession_schedule_occurrence_unique');
          if (!isUniqueViolation) throw createErr;

          duplicate = true;
          const existing = await tx.medicationSession.findFirst({
            where: { scheduleId, occurrenceDate, occurrenceTime },
            orderBy: { scheduledAt: 'desc' },
          });
          if (!existing) throw createErr;
          sessionRow = existing as Parameters<typeof sessionToDomain>[0];
        }

        if (!duplicate && isTaken) {
          const updateResult = await tx.drawerMedication.updateMany({
            where: { id: drawerMedicationId, quantity: { gte: quantityTaken } },
            data: { quantity: newQuantity, missingQuantity },
          });
          if (!updateResult || updateResult.count < 1) {
            throw new ConflictError('Insufficient medication quantity');
          }

          if (newQuantity === 0) {
            const drawer = await tx.drawer.findUnique({
              where: { id: drawerId },
              select: { id: true, status: true },
            });
            if (drawer && shouldSyncStatus(drawer.status as DrawerStatus)) {
              await tx.drawer.update({
                where: { id: drawerId },
                data: { status: 'EMPTY' },
              });
            }
          }
        }

        const session = sessionToDomain(sessionRow);
        return {
          duplicate,
          session,
          remainingQuantity: duplicate
            ? (session.quantityAfter ?? newQuantity)
            : newQuantity,
          refillRequired: duplicate
            ? (session.quantityAfter ?? 0) === 0 && isTaken
            : refillRequired,
          missingQuantity: duplicate
            ? Math.max(0, drawerCapacity - (session.quantityAfter ?? (isTaken ? newQuantity : currentQuantity)))
            : missingQuantity,
        };
      });

      return {
        duplicate: result.duplicate,
        session: result.session,
        remainingQuantity: result.remainingQuantity,
        refillRequired: result.refillRequired,
        missingQuantity: result.missingQuantity,
      } as ProcessDeviceMedicationEventOutput;
    } catch (err) {
      throw err;
    }
  }
}
