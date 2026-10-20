import type {
  IPatientRepository,
  CreatePatientData,
  UpdatePatientData,
} from '@domain/repositories/IPatientRepository';
import type { Patient } from '@domain/entities/Patient';
import type { PaginationParams, PaginatedResult } from '@shared/types';
import { calculatePagination, buildPaginatedResult } from '@shared/utils';
import { prisma } from '@infrastructure/database/prisma/client';

const decimalToNumber = (v: { toNumber(): number } | null): number | null =>
  v ? v.toNumber() : null;

export class PrismaPatientRepository implements IPatientRepository {
  async findById(id: string): Promise<Patient | null> {
    const patient = await prisma.patient.findUnique({ where: { id } });
    return patient ? this.toDomain(patient) : null;
  }

  async findByIdAndUserId(id: string, userId: string): Promise<Patient | null> {
    const patient = await prisma.patient.findFirst({
      where: { id, userId },
    });
    return patient ? this.toDomain(patient) : null;
  }

  async findAllByUserId(
    userId: string,
    params?: PaginationParams,
  ): Promise<PaginatedResult<Patient> | Patient[]> {
    if (!params) {
      const data = await prisma.patient.findMany({ where: { userId } });
      return data.map(this.toDomain);
    }
    const { skip, take, page, limit } = calculatePagination(params);
    const [total, data] = await Promise.all([
      prisma.patient.count({ where: { userId } }),
      prisma.patient.findMany({ where: { userId }, skip, take }),
    ]);
    return buildPaginatedResult(data.map(this.toDomain), total, page, limit);
  }

  async findFirstByUserId(userId: string): Promise<Patient | null> {
    const patient = await prisma.patient.findFirst({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
    return patient ? this.toDomain(patient) : null;
  }

  async create(data: CreatePatientData): Promise<Patient> {
    const patient = await prisma.patient.create({ data });
    return this.toDomain(patient);
  }

  async update(id: string, data: UpdatePatientData): Promise<Patient> {
    const patient = await prisma.patient.update({ where: { id }, data });
    return this.toDomain(patient);
  }

  async delete(id: string): Promise<void> {
    await prisma.patient.delete({ where: { id } });
  }

  private toDomain(model: {
    id: string;
    userId: string;
    fullName: string;
    dateOfBirth: Date | null;
    gender: string | null;
    weightKg: { toNumber(): number } | null;
    heightCm: { toNumber(): number } | null;
    bloodType: string | null;
    allergies: string | null;
    notes: string | null;
    avatarUrl: string | null;
    createdAt: Date;
    updatedAt: Date;
  }): Patient {
    return {
      id: model.id,
      userId: model.userId,
      fullName: model.fullName,
      dateOfBirth: model.dateOfBirth,
      gender: model.gender,
      weightKg: decimalToNumber(model.weightKg),
      heightCm: decimalToNumber(model.heightCm),
      bloodType: model.bloodType,
      allergies: model.allergies,
      notes: model.notes,
      avatarUrl: model.avatarUrl,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
