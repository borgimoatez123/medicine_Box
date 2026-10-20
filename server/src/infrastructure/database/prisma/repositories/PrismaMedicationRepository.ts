import type {
  IMedicationRepository,
  CreateMedicationData,
  UpdateMedicationData,
  MedicationIdentity,
} from '@domain/repositories/IMedicationRepository';
import type { Medication } from '@domain/entities/Medication';
import type { PaginationParams, PaginatedResult } from '@shared/types';
import { calculatePagination, buildPaginatedResult } from '@shared/utils';
import { prisma } from '@infrastructure/database/prisma/client';
import { ConflictError } from '@shared/errors/AppError';

const normalizeForCompare = (v: string): string => v.trim().toLowerCase();

const IDENTITY_TARGETS = new Set(['patientId', 'name', 'dosage', 'form', 'expiryDate']);

export class PrismaMedicationRepository implements IMedicationRepository {
  async findById(id: string): Promise<Medication | null> {
    const m = await prisma.medication.findUnique({ where: { id } });
    return m ? this.toDomain(m) : null;
  }

  async findByIdAndPatientId(id: string, patientId: string): Promise<Medication | null> {
    const m = await prisma.medication.findFirst({
      where: { id, patientId },
    });
    return m ? this.toDomain(m) : null;
  }

  async findByIdAndUserId(id: string, userId: string): Promise<Medication | null> {
    const m = await prisma.medication.findFirst({
      where: { id, patient: { userId } },
    });
    return m ? this.toDomain(m) : null;
  }

  async findDuplicate(
    identity: MedicationIdentity,
    options?: { excludeId?: string },
  ): Promise<Medication | null> {
    const { patientId, name, dosage, form, expiryDate } = identity;
    const normalizedName = normalizeForCompare(name);
    const normalizedDosage = normalizeForCompare(dosage);
    const all = await prisma.medication.findMany({
      where: {
        patientId,
        form,
        expiryDate: expiryDate !== null && expiryDate !== undefined ? expiryDate : { equals: null },
        id: options?.excludeId ? { not: options.excludeId } : undefined,
      },
    });
    for (const row of all) {
      if (
        normalizeForCompare(row.name) === normalizedName &&
        normalizeForCompare(row.dosage) === normalizedDosage
      ) {
        return this.toDomain(row);
      }
    }
    return null;
  }

  async findAllByPatientId(
    patientId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Medication> | Medication[]> {
    if (!params) {
      const data = await prisma.medication.findMany({ where: { patientId } });
      return data.map(this.toDomain);
    }
    const { skip, take, page, limit } = calculatePagination(params);
    const [total, data] = await Promise.all([
      prisma.medication.count({ where: { patientId } }),
      prisma.medication.findMany({ where: { patientId }, skip, take }),
    ]);
    return buildPaginatedResult(data.map(this.toDomain), total, page, limit);
  }

  async findAllByUserId(
    userId: string,
    options?: { patientId?: string; params?: PaginationParams },
  ): Promise<PaginatedResult<Medication> | Medication[]> {
    const params = options?.params;
    const patientFilter = options?.patientId ? { id: options.patientId, userId } : { userId };
    const where = { patient: patientFilter };
    if (!params) {
      const data = await prisma.medication.findMany({ where });
      return data.map(this.toDomain);
    }
    const { skip, take, page, limit } = calculatePagination(params);
    const [total, data] = await Promise.all([
      prisma.medication.count({ where }),
      prisma.medication.findMany({ where, skip, take }),
    ]);
    return buildPaginatedResult(data.map(this.toDomain), total, page, limit);
  }

  async create(data: CreateMedicationData): Promise<Medication> {
    try {
      const m = await prisma.medication.create({ data });
      return this.toDomain(m);
    } catch (err) {
      const e = err as { code?: string; meta?: { target?: string[] } };
      if (
        e?.code === 'P2002' &&
        Array.isArray(e.meta?.target) &&
        e.meta!.target.length > 0 &&
        e.meta!.target.every((t) => IDENTITY_TARGETS.has(t))
      ) {
        throw new ConflictError('Medication already exists for this patient');
      }
      throw err;
    }
  }

  async update(id: string, data: UpdateMedicationData): Promise<Medication> {
    try {
      const m = await prisma.medication.update({ where: { id }, data });
      return this.toDomain(m);
    } catch (err) {
      const e = err as { code?: string; meta?: { target?: string[] } };
      if (
        e?.code === 'P2002' &&
        Array.isArray(e.meta?.target) &&
        e.meta!.target.length > 0 &&
        e.meta!.target.every((t) => IDENTITY_TARGETS.has(t))
      ) {
        throw new ConflictError('Medication already exists for this patient');
      }
      throw err;
    }
  }

  async delete(id: string): Promise<void> {
    await prisma.medication.delete({ where: { id } });
  }

  private toDomain(model: {
    id: string;
    patientId: string;
    name: string;
    dosage: string;
    form: Medication['form'];
    quantity: number;
    expiryDate: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }): Medication {
    return {
      id: model.id,
      patientId: model.patientId,
      name: model.name,
      dosage: model.dosage,
      form: model.form,
      quantity: model.quantity,
      expiryDate: model.expiryDate,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
