import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import type { MedicationForm } from '@domain/entities/Medication';
import { BadRequestError, UnauthorizedError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  createMedicationSchema,
  updateMedicationSchema,
} from '@presentation/validators/medication.validator';
import { CreateMedication } from '@application/use-cases/medications/CreateMedication';
import { GetMedications } from '@application/use-cases/medications/GetMedications';
import { GetMedicationById } from '@application/use-cases/medications/GetMedicationById';
import { UpdateMedication } from '@application/use-cases/medications/UpdateMedication';
import { DeleteMedication } from '@application/use-cases/medications/DeleteMedication';
import { PrismaMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicationRepository';
import { PrismaPatientRepository } from '@infrastructure/database/prisma/repositories/PrismaPatientRepository';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => issue.message).join(', ');

const coerceExpiry = (v: unknown): Date | null | undefined => {
  if (v === undefined) return undefined;
  if (v === null) return null;
  return new Date(String(v));
};

export const MedicationController = {
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const validated = createMedicationSchema.safeParse(req.body);
      if (!validated.success) throw new BadRequestError(formatZodErrors(validated.error));
      const userId = req.user.userId;
      const medicationRepository = new PrismaMedicationRepository();
      const patientRepository = new PrismaPatientRepository();
      const createMedication = new CreateMedication(medicationRepository, patientRepository);
      const { expiryDate, form, ...rest } = validated.data;
      const result = await createMedication.execute({
        userId,
        ...rest,
        form: form as MedicationForm,
        expiryDate: coerceExpiry(expiryDate),
      });
      res.status(HTTP_STATUS.CREATED).json({
        status: 'success',
        statusCode: HTTP_STATUS.CREATED,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const userId = req.user.userId;
      const patientId = (req.query.patientId as string | undefined) || undefined;
      const page = req.query.page ? Number(req.query.page) : undefined;
      const limit = req.query.limit ? Number(req.query.limit) : undefined;
      const medicationRepository = new PrismaMedicationRepository();
      const getMedications = new GetMedications(medicationRepository);
      const result = await getMedications.execute({
        userId,
        patientId,
        pagination: { page, limit },
      });
      if (Array.isArray(result)) {
        res.status(HTTP_STATUS.OK).json({
          status: 'success',
          statusCode: HTTP_STATUS.OK,
          data: result,
        });
        return;
      }
      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: result.data,
        meta: result.meta,
      });
    } catch (error) {
      next(error);
    }
  },

  async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const userId = req.user.userId;
      const id = req.params.id as string;
      const medicationRepository = new PrismaMedicationRepository();
      const getMedicationById = new GetMedicationById(medicationRepository);
      const result = await getMedicationById.execute({ userId, medicationId: id });
      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const validated = updateMedicationSchema.safeParse(req.body);
      if (!validated.success) throw new BadRequestError(formatZodErrors(validated.error));
      const userId = req.user.userId;
      const id = req.params.id as string;
      const medicationRepository = new PrismaMedicationRepository();
      const updateMedication = new UpdateMedication(medicationRepository);
      const { expiryDate, form, ...rest } = validated.data;
      const resolvedExpiry = Object.prototype.hasOwnProperty.call(validated.data, 'expiryDate')
        ? coerceExpiry(expiryDate)
        : undefined;
      const result = await updateMedication.execute({
        userId,
        medicationId: id,
        data: { ...rest, form: form as MedicationForm, expiryDate: resolvedExpiry },
      });
      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const userId = req.user.userId;
      const id = req.params.id as string;
      const medicationRepository = new PrismaMedicationRepository();
      const deleteMedication = new DeleteMedication(medicationRepository);
      await deleteMedication.execute({ userId, medicationId: id });
      res.status(HTTP_STATUS.NO_CONTENT).send();
    } catch (error) {
      next(error);
    }
  },
};
