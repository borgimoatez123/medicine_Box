import { z } from 'zod';
import type { ScheduleStatus } from '@domain/entities/Schedule';

const SCHEDULE_STATUS_VALUES: readonly ScheduleStatus[] = [
  'ACTIVE',
  'PAUSED',
  'COMPLETED',
  'ARCHIVED',
];
const scheduleStatusEnum = z.enum(
  SCHEDULE_STATUS_VALUES as unknown as [string, ...string[]],
);

const HH_MM_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

const timeArraySchema = z.array(z.string().regex(HH_MM_REGEX, 'Invalid time format (expected HH:mm)'));

const daysOfWeekArraySchema = z
  .array(z.number().int().min(1).max(7))
  .refine((arr) => new Set(arr).size === arr.length, {
    message: 'Duplicate day-of-week values are not allowed',
  });

export const createScheduleSchema = z
  .object({
    medicationId: z.string().uuid('Invalid medication ID format'),
    dosage: z.string().min(1, 'Dosage is required'),
    timesPerDay: z.number().int().min(1, 'timesPerDay must be >= 1').nullish(),
    times: timeArraySchema.nullish(),
    startDate: z.string().datetime({ offset: true }).or(z.string().date()),
    endDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().date())
      .nullish(),
    daysOfWeek: daysOfWeekArraySchema.nullish(),
    status: scheduleStatusEnum.default('ACTIVE'),
    notes: z.string().nullish(),
    refillReminder: z.boolean().default(false),
    isActive: z.boolean().default(true),
  })
  .strict()
  .refine(
    (d) => {
      if (!d.endDate) return true;
      return new Date(d.endDate).getTime() >= new Date(d.startDate).getTime();
    },
    { message: 'endDate must be >= startDate', path: ['endDate'] },
  );

export const updateScheduleSchema = z
  .object({
    dosage: z.string().min(1, 'Dosage is required').optional(),
    timesPerDay: z.number().int().min(1, 'timesPerDay must be >= 1').nullish(),
    times: timeArraySchema.nullish(),
    startDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().date())
      .optional(),
    endDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().date())
      .nullish(),
    daysOfWeek: daysOfWeekArraySchema.nullish(),
    status: scheduleStatusEnum.optional(),
    notes: z.string().nullish(),
    refillReminder: z.boolean().optional(),
    isActive: z.boolean().optional(),
  })
  .strict();
