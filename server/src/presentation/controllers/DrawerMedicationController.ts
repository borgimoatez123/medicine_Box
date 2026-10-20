import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  createDrawerMedicationSchema,
  updateDrawerMedicationSchema,
} from '@presentation/validators/drawerMedication.validator';
import { AssignMedicationToDrawer } from '@application/use-cases/drawer-medications/AssignMedicationToDrawer';
import { GetMyDrawerMedications } from '@application/use-cases/drawer-medications/GetMyDrawerMedications';
import { GetDrawerMedicationById } from '@application/use-cases/drawer-medications/GetDrawerMedicationById';
import { UpdateDrawerMedication } from '@application/use-cases/drawer-medications/UpdateDrawerMedication';
import { UnassignMedicationFromDrawer } from '@application/use-cases/drawer-medications/UnassignMedicationFromDrawer';
import { GetAllDrawerMedications } from '@application/use-cases/drawer-medications/GetAllDrawerMedications';
import { GetDrawerMedicationByIdAdmin } from '@application/use-cases/drawer-medications/GetDrawerMedicationByIdAdmin';
import { PrismaDrawerMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerMedicationRepository';
import { PrismaDrawerRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerRepository';
import { PrismaMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicationRepository';
import { PrismaMedicineBoxRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`).join(', ');

const ok = (res: Response, statusCode: number, data: unknown) =>
  res.status(statusCode).json({
    status: 'success',
    statusCode,
    data,
  });

const toStr = (v: string | string[] | undefined): string | undefined =>
  typeof v === 'string' ? v : Array.isArray(v) ? v[0] : undefined;

export const DrawerMedicationController = {
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const validated = createDrawerMedicationSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const dmRepo = new PrismaDrawerMedicationRepository();
      const drawerRepo = new PrismaDrawerRepository();
      const medRepo = new PrismaMedicationRepository();
      const boxRepo = new PrismaMedicineBoxRepository();
      const uc = new AssignMedicationToDrawer(dmRepo, drawerRepo, medRepo, boxRepo);
      const result = await uc.execute(userId, validated.data);
      ok(res, HTTP_STATUS.CREATED, result);
    } catch (error) {
      next(error);
    }
  },

  async listMy(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const drawerId = toStr(req.query.drawerId as string | string[] | undefined);
      const medicationId = toStr(req.query.medicationId as string | string[] | undefined);
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const uc = new GetMyDrawerMedications(drawerMedRepo);
      const result = await uc.execute(userId, {
        drawerId: drawerId && drawerId.length > 0 ? drawerId : undefined,
        medicationId: medicationId && medicationId.length > 0 ? medicationId : undefined,
      });
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const uc = new GetDrawerMedicationById(drawerMedRepo);
      const result = await uc.execute(userId, id);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const validated = updateDrawerMedicationSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const drawerRepo = new PrismaDrawerRepository();
      const boxRepo = new PrismaMedicineBoxRepository();
      const uc = new UpdateDrawerMedication(drawerMedRepo, drawerRepo, boxRepo);
      const result = await uc.execute(userId, id, validated.data);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async delete(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const drawerRepo = new PrismaDrawerRepository();
      const boxRepo = new PrismaMedicineBoxRepository();
      const uc = new UnassignMedicationFromDrawer(drawerMedRepo, drawerRepo, boxRepo);
      await uc.execute(userId, id);
      res.status(HTTP_STATUS.NO_CONTENT).end();
    } catch (error) {
      next(error);
    }
  },

  async adminListAll(_req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const uc = new GetAllDrawerMedications(drawerMedRepo);
      const result = await uc.execute();
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async adminGetById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const drawerMedRepo = new PrismaDrawerMedicationRepository();
      const uc = new GetDrawerMedicationByIdAdmin(drawerMedRepo);
      const result = await uc.execute(id);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },
};
