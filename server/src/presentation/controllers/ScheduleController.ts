import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  createScheduleSchema,
  updateScheduleSchema,
} from '@presentation/validators/schedule.validator';
import { CreateSchedule } from '@application/use-cases/schedules/CreateSchedule';
import { GetSchedules } from '@application/use-cases/schedules/GetSchedules';
import { GetScheduleById } from '@application/use-cases/schedules/GetScheduleById';
import { UpdateSchedule } from '@application/use-cases/schedules/UpdateSchedule';
import { DeleteSchedule } from '@application/use-cases/schedules/DeleteSchedule';
import { PrismaScheduleRepository } from '@infrastructure/database/prisma/repositories/PrismaScheduleRepository';
import { PrismaMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicationRepository';
import { PrismaPatientRepository } from '@infrastructure/database/prisma/repositories/PrismaPatientRepository';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => issue.message).join(', ');

const coerceNullableDate = (
  v: string | null | undefined,
): Date | null | undefined => {
  if (v === undefined) return undefined;
  if (v === null) return null;
  return new Date(v);
};

const coercePagination = (query: Request['query']): { page?: number; limit?: number } | undefined => {
  const p = query.page as string | undefined;
  const l = query.limit as string | undefined;
  if (!p && !l) return undefined;
  const params: { page?: number; limit?: number } = {};
  if (p) {
    const n = Number(p);
    if (Number.isFinite(n) && n >= 1) params.page = Math.floor(n);
  }
  if (l) {
    const n = Number(l);
    if (Number.isFinite(n) && n >= 1) params.limit = Math.floor(n);
  }
  return Object.keys(params).length ? params : undefined;
};

export const ScheduleController = {
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const validated = createScheduleSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const { startDate, endDate, status, ...rest } = validated.data;

      const scheduleRepository = new PrismaScheduleRepository();
      const medicationRepository = new PrismaMedicationRepository();
      const createSchedule = new CreateSchedule(
        scheduleRepository,
        medicationRepository,
      );

      const result = await createSchedule.execute(userId, {
        ...rest,
        status: status as Parameters<typeof createSchedule.execute>[1]['status'],
        startDate: new Date(startDate),
        endDate: coerceNullableDate(endDate),
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
      const userId = req.user!.userId;
      const medicationId = (req.query.medicationId as string | undefined) || undefined;
      const patientId = (req.query.patientId as string | undefined) || undefined;
      const params = coercePagination(req.query);

      const scheduleRepository = new PrismaScheduleRepository();
      const patientRepository = new PrismaPatientRepository();
      const getSchedules = new GetSchedules(scheduleRepository, patientRepository);

      const result = await getSchedules.execute(userId, {
        medicationId,
        patientId,
        params,
      });

      if (Array.isArray(result)) {
        res.status(HTTP_STATUS.OK).json({
          status: 'success',
          statusCode: HTTP_STATUS.OK,
          data: result,
        });
      } else {
        res.status(HTTP_STATUS.OK).json({
          status: 'success',
          statusCode: HTTP_STATUS.OK,
          data: result.data,
          meta: result.meta,
        });
      }
    } catch (error) {
      next(error);
    }
  },

  async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const scheduleRepository = new PrismaScheduleRepository();
      const getScheduleById = new GetScheduleById(scheduleRepository);
      const result = await getScheduleById.execute(userId, id);
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
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };
      const validated = updateScheduleSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const { startDate, endDate, ...rest } = validated.data;

      const patch: Record<string, unknown> = { ...rest };
      if (startDate !== undefined) patch.startDate = new Date(startDate);
      if (Object.prototype.hasOwnProperty.call(validated.data, 'endDate'))
        patch.endDate = coerceNullableDate(validated.data.endDate);

      const scheduleRepository = new PrismaScheduleRepository();
      const updateSchedule = new UpdateSchedule(scheduleRepository);
      const result = await updateSchedule.execute(userId, id, patch as any);

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
      const userId = req.user!.userId;
      const { id } = req.params as { id: string };

      const scheduleRepository = new PrismaScheduleRepository();
      const deleteSchedule = new DeleteSchedule(scheduleRepository);
      await deleteSchedule.execute(userId, id);

      res.status(HTTP_STATUS.NO_CONTENT).send();
    } catch (error) {
      next(error);
    }
  },
};
