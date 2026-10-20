// SECURITY LIMITATION (intentional this iteration): device authentication (X-Device-Id / X-Device-Token headers)
// is NOT enforced here. The Raspberry Pi identity is currently taken from the request payload or query.
// Do NOT rely on this for production multi-tenant security. Enable the future trusted-device middleware
// that populates req.deviceId — the resolveRequestingDeviceId() helper below already prefers that source.
// See the commented-out deviceHeadersSchema stub in devices.validator.ts.

import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import {
  heartbeatSchema,
  getFaceReferenceSchema,
  faceVerificationProbeSchema,
  getDeviceScheduleSchema,
  medicationEventSchema,
  drawerSensorReadingSchema,
  getDeviceCommandsSchema,
  deviceCommandResultSchema,
  getMedicationEventsQuerySchema,
} from '@presentation/validators/devices.validator';
import { DeviceHeartbeat } from '@application/use-cases/device/DeviceHeartbeat';
import { GetPatientFaceReference } from '@application/use-cases/device/GetPatientFaceReference';
import { PerformAndRecordFaceVerification } from '@application/use-cases/device/PerformAndRecordFaceVerification';
import { GetDeviceSchedule } from '@application/use-cases/device/GetDeviceSchedule';
import { ProcessPatientMedicationEvent } from '@application/use-cases/device/ProcessPatientMedicationEvent';
import { RecordDrawerSensorReading } from '@application/use-cases/device/RecordDrawerSensorReading';
import { GetPendingDeviceCommands } from '@application/use-cases/device/GetPendingDeviceCommands';
import { AcknowledgeDeviceCommandResult } from '@application/use-cases/device/AcknowledgeDeviceCommandResult';
import { GetMedicationEvents } from '@application/use-cases/device/GetMedicationEvents';
import { PrismaMedicineBoxRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';
import { PrismaPatientRepository } from '@infrastructure/database/prisma/repositories/PrismaPatientRepository';
import { PrismaFaceVerificationEventRepository } from '@infrastructure/database/prisma/repositories/PrismaFaceVerificationEventRepository';
import { PrismaScheduleRepository } from '@infrastructure/database/prisma/repositories/PrismaScheduleRepository';
import { PrismaMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicationRepository';
import { PrismaDrawerRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerRepository';
import { PrismaDrawerMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerMedicationRepository';
import { PrismaDrawerSensorStateRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerSensorStateRepository';
import { PrismaDeviceCommandRepository } from '@infrastructure/database/prisma/repositories/PrismaDeviceCommandRepository';
import { PrismaMedicationSessionRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicationSessionRepository';
import { PrismaDeviceMedicationEventProcessor } from '@infrastructure/services/PrismaDeviceMedicationEventProcessor';
import { JwtService } from '@infrastructure/auth/JwtService';
import { UnauthorizedError } from '@shared/errors/AppError';

const HEARTBEAT_INVALID_MSG = 'deviceId is required';
const FACE_REF_INVALID_MSG =
  'patientId and deviceId are required (non-empty strings)';
const FACE_VERIFY_INVALID_MSG =
  'deviceId, patientId (non-empty strings) and a probe_image (multipart file) are required. The backend calculates verified and similarity server-side; any values sent by the client are never trusted.';
const SCHEDULE_SYNC_INVALID_MSG = 'deviceId is required (non-empty string)';
const MED_EVENT_INVALID_MSG =
  'deviceId, patientId, scheduleId, drawerId (non-empty strings), status (TAKEN|MISSED), quantityTaken (integer) are required; for TAKEN quantityTaken must be positive integer; for MISSED quantityTaken must be 0';
const SENSOR_READING_INVALID_MSG =
  'deviceId, drawerId (non-empty strings) are required; temperature and humidity must be finite numbers; humidity must be within 0..100 %; fireDetected must be boolean';
const GET_DEVICE_COMMANDS_INVALID_MSG =
  'deviceId is required (non-empty string)';
const DEVICE_COMMAND_RESULT_INVALID_MSG =
  'deviceId (non-empty string) and status (EXECUTED|FAILED) are required; error is optional string, max 1000 characters';
const GET_MED_EVENTS_INVALID_MSG =
  'Invalid query parameters. deviceId, patientId, scheduleId, drawerId must be non-empty strings; status must be TAKEN, MISSED, or a valid MedicationSessionResult; limit must be 1..100; offset must be >= 0';

export const formatZodErrors = (
  error: ZodError,
  schema:
    | 'heartbeat'
    | 'face-reference'
    | 'face-verification'
    | 'schedule-sync'
    | 'medication-event'
    | 'sensor-reading'
    | 'get-device-commands'
    | 'device-command-result'
    | 'get-medication-events' = 'heartbeat',
): string => {
  if (schema === 'heartbeat') return HEARTBEAT_INVALID_MSG;
  if (schema === 'face-reference') {
    const firstPath = error.issues[0]?.path?.[0];
    if (firstPath === 'patientId' || firstPath === 'deviceId') {
      return FACE_REF_INVALID_MSG;
    }
    return FACE_REF_INVALID_MSG;
  }
  if (schema === 'schedule-sync') return SCHEDULE_SYNC_INVALID_MSG;
  if (schema === 'medication-event') return MED_EVENT_INVALID_MSG;
  if (schema === 'sensor-reading') return SENSOR_READING_INVALID_MSG;
  if (schema === 'get-device-commands') return GET_DEVICE_COMMANDS_INVALID_MSG;
  if (schema === 'device-command-result') return DEVICE_COMMAND_RESULT_INVALID_MSG;
  if (schema === 'get-medication-events') return GET_MED_EVENTS_INVALID_MSG;
  return FACE_VERIFY_INVALID_MSG;
};

const okPublic = (res: Response, statusCode: number, data: unknown) =>
  res.status(statusCode).json({
    status: 'success',
    statusCode,
    data,
  });

type DeviceRequest = Request & {
  deviceId?: string;
};

const resolveRequestingDeviceId = (req: DeviceRequest): string | null => {
  const trusted = (req.deviceId ?? '').trim();
  if (trusted) return trusted;

  const fromQuery = typeof req.query?.deviceId === 'string' ? req.query.deviceId.trim() : '';
  if (fromQuery) return fromQuery;

  const fromBody =
    typeof (req.body as unknown as { deviceId?: unknown })?.deviceId === 'string'
      ? (req.body as { deviceId: string }).deviceId.trim()
      : '';
  return fromBody || null;
};

export const DevicesController = {
  async heartbeat(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = heartbeatSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(
          formatZodErrors(validated.error, 'heartbeat'),
        );
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const uc = new DeviceHeartbeat(medicineBoxRepository);
      const result = await uc.execute(validated.data.deviceId);
      okPublic(res, HTTP_STATUS.OK, {
        deviceId: result.deviceId,
        status: result.status,
        lastSeen: result.lastSeen.toISOString(),
      });
    } catch (error) {
      next(error);
    }
  },

  async getFaceReference(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const patientIdParam =
        typeof req.params?.patientId === 'string' ? req.params.patientId : '';
      const deviceIdFromContext = resolveRequestingDeviceId(req) ?? '';
      const validated = getFaceReferenceSchema.safeParse({
        patientId: patientIdParam,
        deviceId: deviceIdFromContext,
      });
      if (!validated.success) {
        throw new BadRequestError(
          formatZodErrors(validated.error, 'face-reference'),
        );
      }
      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const patientRepository = new PrismaPatientRepository();
      const uc = new GetPatientFaceReference(
        patientRepository,
        medicineBoxRepository,
      );
      const result = await uc.execute(
        validated.data.patientId,
        validated.data.deviceId,
      );
      okPublic(res, HTTP_STATUS.OK, {
        patientId: result.patientId,
        faceReference: {
          url: result.faceReference.url,
          updatedAt: result.faceReference.updatedAt.toISOString(),
        },
      });
    } catch (error) {
      next(error);
    }
  },

  async recordFaceVerification(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        throw new BadRequestError(
          'probe_image (captured face photo file) is required as part of the multipart/form-data request.',
        );
      }
      if (!file.buffer || Buffer.byteLength(file.buffer) === 0) {
        throw new BadRequestError(
          'The uploaded probe_image file is empty. Please capture a new photo and try again.',
        );
      }

      const bodyParsed = faceVerificationProbeSchema.safeParse(req.body ?? {});
      if (!bodyParsed.success) {
        throw new BadRequestError(
          formatZodErrors(bodyParsed.error, 'face-verification'),
        );
      }
      const trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest);
      const payload = { ...bodyParsed.data };
      if (trustedDeviceId) {
        payload.deviceId = trustedDeviceId;
      }

      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const patientRepository = new PrismaPatientRepository();
      const faceVerificationRepo = new PrismaFaceVerificationEventRepository();
      const uc = new PerformAndRecordFaceVerification(
        patientRepository,
        medicineBoxRepository,
        faceVerificationRepo,
      );
      const result = await uc.execute({
        deviceId: payload.deviceId,
        patientId: payload.patientId,
        probeImageBuffer: file.buffer,
        probeImageOriginalName: file.originalname,
      });
      const data: Record<string, unknown> = {
        deviceId: result.event.deviceId,
        patientId: result.event.patientId,
        verified: result.event.verified,
        similarity: result.event.similarity,
        threshold: result.ai.threshold,
        message: result.message,
      };
      if (typeof result.ai.referenceFaceDetected === 'boolean') {
        data.referenceFaceDetected = result.ai.referenceFaceDetected;
      }
      if (typeof result.ai.probeFaceDetected === 'boolean') {
        data.probeFaceDetected = result.ai.probeFaceDetected;
      }
      okPublic(res, HTTP_STATUS.OK, data);
    } catch (error) {
      next(error);
    }
  },

  async getDeviceSchedule(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    // SECURITY LIMITATION: device identity is taken from the route param today, unless trusted
    // req.deviceId (future middleware) or X-Device-Id header are set. See controller header comment.
    try {
      const deviceIdParam =
        typeof req.params?.deviceId === 'string' ? req.params.deviceId : '';
      const validated = getDeviceScheduleSchema.safeParse({
        deviceId: deviceIdParam,
      });
      if (!validated.success) {
        throw new BadRequestError(
          formatZodErrors(validated.error, 'schedule-sync'),
        );
      }
      const effectiveDeviceId =
        resolveRequestingDeviceId(req as DeviceRequest) ?? validated.data.deviceId;

      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const patientRepository = new PrismaPatientRepository();
      const scheduleRepository = new PrismaScheduleRepository();
      const uc = new GetDeviceSchedule(
        medicineBoxRepository,
        patientRepository,
        scheduleRepository,
      );
      const result = await uc.execute(effectiveDeviceId);
      okPublic(res, HTTP_STATUS.OK, {
        patientId: result.patientId,
        schedules: result.schedules,
      });
    } catch (error) {
      next(error);
    }
  },

  async recordMedicationEvent(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    // SECURITY LIMITATION: device identity is taken from the request body today, unless trusted
    // req.deviceId (future middleware) or X-Device-Id header are set. See controller header comment.
    try {
      const bodyParsed = medicationEventSchema.safeParse(req.body ?? {});
      if (!bodyParsed.success) {
        throw new BadRequestError(
          formatZodErrors(bodyParsed.error, 'medication-event'),
        );
      }
      const trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest);
      const payload = { ...bodyParsed.data };
      if (trustedDeviceId) {
        payload.deviceId = trustedDeviceId;
      }

      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const patientRepository = new PrismaPatientRepository();
      const scheduleRepository = new PrismaScheduleRepository();
      const medicationRepository = new PrismaMedicationRepository();
      const drawerRepository = new PrismaDrawerRepository();
      const drawerMedicationRepository = new PrismaDrawerMedicationRepository();
      const processor = new PrismaDeviceMedicationEventProcessor();
      const uc = new ProcessPatientMedicationEvent(
        medicineBoxRepository,
        patientRepository,
        scheduleRepository,
        medicationRepository,
        drawerRepository,
        drawerMedicationRepository,
        processor,
      );
      const result = await uc.execute(payload);
      okPublic(res, HTTP_STATUS.OK, result);
    } catch (error) {
      next(error);
    }
  },

  async recordSensorReading(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    // SECURITY LIMITATION: device identity is taken from the request body today, unless trusted
    // req.deviceId (future middleware) or X-Device-Id header are set. See controller header comment.
    try {
      const bodyParsed = drawerSensorReadingSchema.safeParse(req.body ?? {});
      if (!bodyParsed.success) {
        throw new BadRequestError(
          formatZodErrors(bodyParsed.error, 'sensor-reading'),
        );
      }
      const trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest);
      const payload = { ...bodyParsed.data };
      if (trustedDeviceId) {
        payload.deviceId = trustedDeviceId;
      }

      const medicineBoxRepository = new PrismaMedicineBoxRepository();
      const drawerRepository = new PrismaDrawerRepository();
      const sensorRepository = new PrismaDrawerSensorStateRepository();
      const uc = new RecordDrawerSensorReading(
        medicineBoxRepository,
        drawerRepository,
        sensorRepository,
      );
      const result = await uc.execute(payload);
      okPublic(res, HTTP_STATUS.OK, {
        drawerId: result.drawerId,
        temperature: result.temperature,
        humidity: result.humidity,
        fireDetected: result.fireDetected,
        updatedAt: result.updatedAt.toISOString(),
      });
    } catch (error) {
      next(error);
    }
  },

  async getPendingCommands(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const deviceIdParam =
        typeof req.params?.deviceId === 'string' ? req.params.deviceId : '';
      const deviceIdFromContext = resolveRequestingDeviceId(req as DeviceRequest) ?? '';
      const validated = getDeviceCommandsSchema.safeParse({
        deviceId: deviceIdFromContext || deviceIdParam,
      });
      if (!validated.success) {
        throw new BadRequestError(
          formatZodErrors(validated.error, 'get-device-commands'),
        );
      }
      const effectiveDeviceId = validated.data.deviceId;
      const boxRepo = new PrismaMedicineBoxRepository();
      const cmdRepo = new PrismaDeviceCommandRepository();
      const uc = new GetPendingDeviceCommands(boxRepo, cmdRepo);
      const pending = await uc.execute(effectiveDeviceId);
      okPublic(res, HTTP_STATUS.OK, {
        deviceId: effectiveDeviceId,
        commands: pending.map(c => ({
          commandId: c.commandId,
          type: c.type,
          drawerId: c.drawerId,
          reason: c.reason,
          createdAt: c.createdAt.toISOString(),
        })),
      });
    } catch (error) {
      next(error);
    }
  },

  async acknowledgeCommandResult(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const commandIdParam =
        typeof req.params?.commandId === 'string' ? req.params.commandId.trim() : '';
      if (!commandIdParam) {
        throw new BadRequestError('commandId (url param) is required');
      }
      const bodyParsed = deviceCommandResultSchema.safeParse(req.body ?? {});
      if (!bodyParsed.success) {
        throw new BadRequestError(
          formatZodErrors(bodyParsed.error, 'device-command-result'),
        );
      }
      const trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest);
      const effectiveDeviceId = trustedDeviceId ?? bodyParsed.data.deviceId;
      const cmdRepo = new PrismaDeviceCommandRepository();
      const uc = new AcknowledgeDeviceCommandResult(cmdRepo);
      const result = await uc.execute(
        commandIdParam,
        effectiveDeviceId,
        bodyParsed.data.status,
        bodyParsed.data.error ?? undefined,
      );
      okPublic(res, HTTP_STATUS.OK, {
        commandId: result.commandId,
        status: result.status,
      });
    } catch (error) {
      next(error);
    }
  },

  async listMedicationEvents(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const parsed = getMedicationEventsQuerySchema.safeParse(req.query ?? {});
      if (!parsed.success) {
        throw new BadRequestError(
          formatZodErrors(parsed.error, 'get-medication-events'),
        );
      }

      // Authentication: JWT is optional to support both mobile (JWT) and
      // Raspberry Pi (deviceId-only) callers. If a token is present it must
      // be valid (401 otherwise). If no token, a deviceId filter is required
      // so the caller is scoped to a single device.
      const authHeader = req.headers.authorization;
      let userId: string | undefined;
      if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.slice('Bearer '.length).trim();
        const jwtService = new JwtService();
        const payload = jwtService.verify(token); // throws UnauthorizedError -> 401
        userId = payload.userId;
      } else if (!parsed.data.deviceId) {
        throw new UnauthorizedError(
          'Authentication required. Provide a Bearer token (mobile) or a deviceId query parameter (device).',
        );
      }

      const sessionRepo = new PrismaMedicationSessionRepository();
      const uc = new GetMedicationEvents(sessionRepo);
      const result = await uc.execute({
        ...parsed.data,
        userId,
      });

      const data = result.events.map((ev) => {
        const status =
          ev.result === 'PATIENT_TAKEN'
            ? 'TAKEN'
            : ev.result === 'MISSED'
              ? 'MISSED'
              : ev.result;
        const quantityTaken =
          ev.quantityBefore - (ev.quantityAfter ?? ev.quantityBefore);
        return {
          id: ev.id,
          deviceId: ev.deviceId,
          patientId: ev.patientId,
          scheduleId: ev.scheduleId,
          drawerId: ev.drawerId,
          medicationId: ev.medicationId,
          status,
          quantityTaken,
          quantityBefore: ev.quantityBefore,
          quantityAfter: ev.quantityAfter,
          scheduledAt: ev.scheduledAt.toISOString(),
          completedAt: ev.completedAt ? ev.completedAt.toISOString() : null,
          createdAt: ev.scheduledAt.toISOString(),
          occurrenceDate: ev.occurrenceDate
            ? ev.occurrenceDate.toISOString().slice(0, 10)
            : null,
          occurrenceTime: ev.occurrenceTime,
        };
      });

      okPublic(res, HTTP_STATUS.OK, {
        events: data,
        pagination: {
          limit: result.limit,
          offset: result.offset,
          total: result.total,
        },
      });
    } catch (error) {
      next(error);
    }
  },
};
