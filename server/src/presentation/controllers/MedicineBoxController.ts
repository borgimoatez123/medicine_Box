import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  addMedicineBoxSchema,
  activateMedicineBoxSchema,
  userUpdateMedicineBoxSchema,
  adminUpdateMedicineBoxSchema,
} from '@presentation/validators/medicineBox.validator';
import { AddMedicineBox } from '@application/use-cases/medicine-box/AddMedicineBox';
import { ActivateMedicineBox } from '@application/use-cases/medicine-box/ActivateMedicineBox';
import { UnassignMedicineBox } from '@application/use-cases/medicine-box/UnassignMedicineBox';
import { GetMyMedicineBoxes } from '@application/use-cases/medicine-box/GetMyMedicineBoxes';
import { GetMedicineBoxById } from '@application/use-cases/medicine-box/GetMedicineBoxById';
import { UpdateMedicineBox } from '@application/use-cases/medicine-box/UpdateMedicineBox';
import { GetAllMedicineBoxes } from '@application/use-cases/medicine-box/GetAllMedicineBoxes';
import { GetMedicineBoxByIdAdmin } from '@application/use-cases/medicine-box/GetMedicineBoxByIdAdmin';
import { AdminUpdateMedicineBox } from '@application/use-cases/medicine-box/AdminUpdateMedicineBox';
import { GetMedicineBoxSensorReadings } from '@application/use-cases/medicine-box/GetMedicineBoxSensorReadings';
import {
  PrismaMedicineBoxRepository,
  toPublicMedicineBox,
} from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';
import { PrismaDrawerRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerRepository';
import { PrismaDrawerSensorStateRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerSensorStateRepository';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => issue.message).join(', ');

const okPublic = (res: Response, statusCode: number, data: unknown) =>
  res.status(statusCode).json({
    status: 'success',
    statusCode,
    data,
  });

export const MedicineBoxController = {
  async add(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = addMedicineBoxSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const addMedicineBox = new AddMedicineBox(medicineBoxRepository);
      const result = await addMedicineBox.execute(validated.data);
      okPublic(res, HTTP_STATUS.CREATED, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async activate(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const validated = activateMedicineBoxSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const activateMedicineBox = new ActivateMedicineBox(medicineBoxRepository);
      const result = await activateMedicineBox.execute(userId, validated.data);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async listMy(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const getMyBoxes = new GetMyMedicineBoxes(medicineBoxRepository);
      const result = await getMyBoxes.execute(userId);
      okPublic(res, HTTP_STATUS.OK, result.map(toPublicMedicineBox));
    } catch (error) {
      next(error);
    }
  },

  async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new GetMedicineBoxById(medicineBoxRepository);
      const result = await uc.execute(userId, id);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const validated = userUpdateMedicineBoxSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new UpdateMedicineBox(medicineBoxRepository);
      const result = await uc.execute(userId, id, validated.data);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async unassign(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new UnassignMedicineBox(medicineBoxRepository);
      const result = await uc.execute(userId, id);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async adminListAll(_req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new GetAllMedicineBoxes(medicineBoxRepository);
      const result = await uc.execute();
      okPublic(res, HTTP_STATUS.OK, result.map(toPublicMedicineBox));
    } catch (error) {
      next(error);
    }
  },

  async adminGetById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params as { id: string };
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new GetMedicineBoxByIdAdmin(medicineBoxRepository);
      const result = await uc.execute(id);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async adminUpdate(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params as { id: string };
      const validated = adminUpdateMedicineBoxSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new AdminUpdateMedicineBox(medicineBoxRepository);
      const result = await uc.execute(id, validated.data);
      okPublic(res, HTTP_STATUS.OK, toPublicMedicineBox(result));
    } catch (error) {
      next(error);
    }
  },

  async getSensors(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const drawerRepository = new PrismaDrawerRepository();
      const sensorRepository = new PrismaDrawerSensorStateRepository();
      const uc = new GetMedicineBoxSensorReadings(
        medicineBoxRepository,
        drawerRepository,
        sensorRepository,
      );
      const result = await uc.execute(userId, id);
      okPublic(res, HTTP_STATUS.OK, {
        medicineBoxId: result.medicineBoxId,
        drawers: result.drawers.map((d) => ({
          drawerId: d.drawerId,
          temperature: d.temperature,
          humidity: d.humidity,
          fireDetected: d.fireDetected,
          updatedAt: d.updatedAt ? d.updatedAt.toISOString() : null,
        })),
      });
    } catch (error) {
      next(error);
    }
  },
};
