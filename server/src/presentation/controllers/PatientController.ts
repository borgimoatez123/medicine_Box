import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import type { UploadPatientAvatarFile } from '@application/use-cases/patients/UploadPatientAvatar';
import { BadRequestError, UnauthorizedError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  createPatientSchema,
  updatePatientSchema,
} from '@presentation/validators/patient.validator';
import { CreatePatient } from '@application/use-cases/patients/CreatePatient';
import { GetPatients } from '@application/use-cases/patients/GetPatients';
import { GetPatientById } from '@application/use-cases/patients/GetPatientById';
import { UpdatePatient } from '@application/use-cases/patients/UpdatePatient';
import { DeletePatient } from '@application/use-cases/patients/DeletePatient';
import { UploadPatientAvatar } from '@application/use-cases/patients/UploadPatientAvatar';
import { DeletePatientAvatar } from '@application/use-cases/patients/DeletePatientAvatar';
import { PrismaPatientRepository } from '@infrastructure/database/prisma/repositories/PrismaPatientRepository';
import { SupabaseStorageService } from '@infrastructure/storage/SupabaseStorageService';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => issue.message).join(', ');

const newRepos = () => ({
  patientRepo: new PrismaPatientRepository(),
  storageService: new SupabaseStorageService(),
});

export const PatientController = {
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');

      const validated = createPatientSchema.safeParse(req.body);
      if (!validated.success) throw new BadRequestError(formatZodErrors(validated.error));

      const userId = req.user.userId;
      const {
        fullName,
        dateOfBirth,
        gender,
        weightKg,
        heightCm,
        bloodType,
        allergies,
        notes,
        avatarUrl,
      } = validated.data;

      const repo = new PrismaPatientRepository();
      const uc = new CreatePatient(repo);
      const result = await uc.execute({
        userId,
        fullName,
        dateOfBirth: dateOfBirth as never,
        gender,
        weightKg,
        heightCm,
        bloodType,
        allergies,
        notes,
        avatarUrl,
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
      const page = typeof req.query.page === 'string' ? Number(req.query.page) : undefined;
      const limit = typeof req.query.limit === 'string' ? Number(req.query.limit) : undefined;

      const repo = new PrismaPatientRepository();
      const uc = new GetPatients(repo);
      const data = await uc.execute({ userId: req.user.userId, page, limit });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const { id: patientId } = req.params as { id: string };

      const repo = new PrismaPatientRepository();
      const uc = new GetPatientById(repo);
      const data = await uc.execute({ userId: req.user.userId, patientId });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const { id: patientId } = req.params as { id: string };
      const validated = updatePatientSchema.safeParse(req.body);
      if (!validated.success) throw new BadRequestError(formatZodErrors(validated.error));

      const repo = new PrismaPatientRepository();
      const uc = new UpdatePatient(repo);
      const data = await uc.execute({
        userId: req.user.userId,
        patientId,
        ...validated.data,
      });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const { id: patientId } = req.params as { id: string };

      const repo = new PrismaPatientRepository();
      const uc = new DeletePatient(repo);
      await uc.execute({ userId: req.user.userId, patientId });

      res.status(HTTP_STATUS.NO_CONTENT).send();
    } catch (error) {
      next(error);
    }
  },

  async uploadAvatar(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const { id: patientId } = req.params as { id: string };

      const raw = req.file as Express.Multer.File | undefined;
      if (!raw) {
        throw new BadRequestError(
          'Missing image file. Send a multipart/form-data request with the field name "image".',
        );
      }
      const file: UploadPatientAvatarFile = {
        buffer: raw.buffer,
        mimetype: raw.mimetype,
        originalname: raw.originalname,
        size: raw.size,
      };

      const { patientRepo, storageService } = newRepos();
      const uc = new UploadPatientAvatar(patientRepo, storageService);
      const patient = await uc.execute({
        userId: req.user.userId,
        patientId,
        file,
      });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: { patient },
      });
    } catch (error) {
      next(error);
    }
  },

  async deleteAvatar(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) throw new UnauthorizedError('Authentication required');
      const { id: patientId } = req.params as { id: string };

      const { patientRepo, storageService } = newRepos();
      const uc = new DeletePatientAvatar(patientRepo, storageService);
      await uc.execute({ userId: req.user.userId, patientId });

      res.status(HTTP_STATUS.NO_CONTENT).send();
    } catch (error) {
      next(error);
    }
  },
};
