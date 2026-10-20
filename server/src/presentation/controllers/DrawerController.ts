import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  updateDrawerSchema,
  adminUpdateDrawerSchema,
  drawerOpenCommandSchema,
  drawerCloseCommandSchema,
} from '@presentation/validators/drawer.validator';
import { ProvisionDrawers } from '@application/use-cases/drawers/ProvisionDrawers';
import { GetMyDrawers } from '@application/use-cases/drawers/GetMyDrawers';
import { GetDrawerById } from '@application/use-cases/drawers/GetDrawerById';
import { UpdateDrawer } from '@application/use-cases/drawers/UpdateDrawer';
import { GetAllDrawers } from '@application/use-cases/drawers/GetAllDrawers';
import { GetDrawerByIdAdmin } from '@application/use-cases/drawers/GetDrawerByIdAdmin';
import { AdminUpdateDrawer } from '@application/use-cases/drawers/AdminUpdateDrawer';
import { GetDrawerSensorReading } from '@application/use-cases/drawers/GetDrawerSensorReading';
import { CreateDrawerOpenCommand } from '@application/use-cases/drawer/CreateDrawerOpenCommand';
import { CreateDrawerCloseCommand } from '@application/use-cases/drawer/CreateDrawerCloseCommand';
import { PrismaDrawerRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerRepository';
import { PrismaMedicineBoxRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';
import { PrismaDrawerSensorStateRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerSensorStateRepository';
import { PrismaDeviceCommandRepository } from '@infrastructure/database/prisma/repositories/PrismaDeviceCommandRepository';

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

export const DrawerController = {
  async provision(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const medicineBoxId = toStr(req.params.medicineBoxId);
      if (!medicineBoxId) throw new BadRequestError('medicineBoxId required');
      const drawerRepository = new PrismaDrawerRepository();
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new ProvisionDrawers(drawerRepository, medicineBoxRepository);
      const result = await uc.execute(medicineBoxId);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async listMy(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const raw = toStr(req.query.medicineBoxId as string | string[] | undefined);
      const medicineBoxId = raw && raw.length > 0 ? raw : undefined;
      const drawerRepository = new PrismaDrawerRepository();
      const uc = new GetMyDrawers(drawerRepository);
      const result = await uc.execute(userId, { medicineBoxId });
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
      const drawerRepository = new PrismaDrawerRepository();
      const uc = new GetDrawerById(drawerRepository);
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
      const validated = updateDrawerSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const drawerRepository = new PrismaDrawerRepository();
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new UpdateDrawer(drawerRepository, medicineBoxRepository);
      const result = await uc.execute(userId, id, validated.data);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async adminListAll(_req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const drawerRepository = new PrismaDrawerRepository();
      const uc = new GetAllDrawers(drawerRepository);
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
      const drawerRepository = new PrismaDrawerRepository();
      const uc = new GetDrawerByIdAdmin(drawerRepository);
      const result = await uc.execute(id);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async adminUpdate(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const validated = adminUpdateDrawerSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }
      const drawerRepository = new PrismaDrawerRepository();
      const uc = new AdminUpdateDrawer(drawerRepository);
      const result = await uc.execute(id, validated.data);
      ok(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async getSensors(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const id = toStr(req.params.id);
      if (!id) throw new BadRequestError('id required');
      const drawerRepository = new PrismaDrawerRepository();
      const sensorRepository = new PrismaDrawerSensorStateRepository();
      const uc = new GetDrawerSensorReading(drawerRepository, sensorRepository);
      const result = await uc.execute(userId, id);
      ok(res, HTTP_STATUS.OK, {
        drawerId: result.drawerId,
        temperature: result.temperature,
        humidity: result.humidity,
        fireDetected: result.fireDetected,
        updatedAt: result.updatedAt ? result.updatedAt.toISOString() : null,
      });
    } catch (error) {
      next(error);
    }
  },

  async openDrawer(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const drawerId = toStr(req.params.drawerId);
      if (!drawerId) throw new BadRequestError('drawerId required');
      const bodyValidated = drawerOpenCommandSchema.safeParse(req.body ?? {});
      if (!bodyValidated.success) {
        throw new BadRequestError(formatZodErrors(bodyValidated.error));
      }
      const drawerRepo = new PrismaDrawerRepository();
      const boxRepo = new PrismaMedicineBoxRepository();
      const cmdRepo = new PrismaDeviceCommandRepository();
      const uc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
      const created = await uc.execute(userId, drawerId, bodyValidated.data.reason ?? undefined);
      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        message: 'Drawer open command created successfully',
        data: {
          commandId: created.id,
          drawerId: created.drawerId,
          deviceId: created.deviceId,
          type: created.type,
          status: created.status,
          createdAt: created.createdAt.toISOString(),
        },
      });
    } catch (error) {
      next(error);
    }
  },

  async closeDrawer(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { userId } = req.user!;
      const drawerId = toStr(req.params.drawerId);
      if (!drawerId) throw new BadRequestError('drawerId required');
      const bodyValidated = drawerCloseCommandSchema.safeParse(req.body ?? {});
      if (!bodyValidated.success) {
        throw new BadRequestError(formatZodErrors(bodyValidated.error));
      }
      const drawerRepo = new PrismaDrawerRepository();
      const boxRepo = new PrismaMedicineBoxRepository();
      const cmdRepo = new PrismaDeviceCommandRepository();
      const uc = new CreateDrawerCloseCommand(drawerRepo, boxRepo, cmdRepo);
      const created = await uc.execute(userId, drawerId, bodyValidated.data.reason ?? undefined);
      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        message: 'Drawer close command created successfully',
        data: {
          commandId: created.id,
          drawerId: created.drawerId,
          deviceId: created.deviceId,
          type: created.type,
          status: created.status,
          createdAt: created.createdAt.toISOString(),
        },
      });
    } catch (error) {
      next(error);
    }
  },
};
