import { z } from 'zod';

export const heartbeatSchema = z
  .object({
    deviceId: z.string().trim().min(1),
  })
  .strict();

export const getFaceReferenceSchema = z
  .object({
    patientId: z.string().trim().min(1),
    deviceId: z.string().trim().min(1),
  })
  .strict();

export const faceVerificationSchema = z
  .object({
    deviceId: z.string().trim().min(1),
    patientId: z.string().trim().min(1),
    verified: z.boolean(),
    similarity: z.number().gte(0).lte(1).optional(),
  })
  .strict();

export const faceVerificationProbeSchema = z
  .object({
    deviceId: z.string().trim().min(1),
    patientId: z.string().trim().min(1),
    verified: z.unknown().optional(),
    similarity: z.unknown().optional(),
  })
  .passthrough();

export const getDeviceScheduleSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required'),
  })
  .strict();

export const medicationEventSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required'),
    patientId: z.string().trim().min(1, 'patientId is required'),
    scheduleId: z.string().trim().min(1, 'scheduleId is required'),
    drawerId: z.string().trim().min(1, 'drawerId is required'),
    status: z.enum(['TAKEN', 'MISSED']),
    quantityTaken: z.number().int(),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.status === 'TAKEN' && value.quantityTaken <= 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['quantityTaken'],
        message: 'quantityTaken must be a positive integer when status is TAKEN',
      });
    }
    if (value.status === 'MISSED' && value.quantityTaken !== 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['quantityTaken'],
        message: 'quantityTaken must be 0 when status is MISSED',
      });
    }
  });

export const drawerSensorReadingSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required (non-empty string)'),
    drawerId: z.string().trim().min(1, 'drawerId is required (non-empty string)'),
    temperature: z.number(),
    humidity: z.number(),
    fireDetected: z.boolean(),
  })
  .strict()
  .superRefine((v, ctx) => {
    if (!Number.isFinite(v.temperature)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['temperature'],
        message: 'temperature must be a valid finite number (not NaN/Infinity)',
      });
    }
    if (!Number.isFinite(v.humidity)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['humidity'],
        message: 'humidity must be a valid finite number (not NaN/Infinity)',
      });
    } else if (v.humidity < 0 || v.humidity > 100) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['humidity'],
        message: 'humidity must be within 0..100 % (impossible value rejected)',
      });
    }
  });

// FUTURE DEVICE AUTH EXTENSION:
// Re-enable below when the full X-Device-Id / X-Device-Token middleware is restored.
// export const deviceHeadersSchema = z
//   .object({
//     'x-device-id': z.string().trim().min(1),
//     'x-device-token': z.string().trim().min(1),
//   })
//   .strip();

export const getDeviceCommandsSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required (non-empty string)'),
  })
  .strict();

export const deviceCommandResultSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required (non-empty string)'),
    status: z.enum(['EXECUTED', 'FAILED']),
    error: z.string().trim().max(1000).optional().nullable(),
  })
  .strict();

// GET /api/devices/medication-events query parameters
// All filters are optional. limit/offset are coerced from query strings.
export const getMedicationEventsQuerySchema = z
  .object({
    deviceId: z.string().trim().min(1).optional(),
    patientId: z.string().trim().min(1).optional(),
    scheduleId: z.string().trim().min(1).optional(),
    drawerId: z.string().trim().min(1).optional(),
    // Accept the API-facing status values (TAKEN, MISSED) and the raw
    // MedicationSessionResult enum values (PATIENT_TAKEN, PATIENT_SKIPPED,
    // FACE_RECOGNITION_FAILED, DISPENSING_FAILED, DEVICE_FAILURE, MISSED).
    status: z
      .enum([
        'TAKEN',
        'MISSED',
        'PATIENT_TAKEN',
        'PATIENT_SKIPPED',
        'FACE_RECOGNITION_FAILED',
        'DISPENSING_FAILED',
        'DEVICE_FAILURE',
      ])
      .optional(),
    limit: z.coerce.number().int().min(1).max(100).optional(),
    offset: z.coerce.number().int().min(0).optional(),
  })
  .strict();
