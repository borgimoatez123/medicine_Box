import { z } from 'zod';
import type { MedicineBoxStatus } from '@domain/entities/MedicineBox';

export const addMedicineBoxSchema = z
  .object({
    deviceId: z.string().min(1, 'Device ID is required'),
    deviceToken: z.string().min(1, 'Device token is required'),
    name: z.string().min(1, 'Name is required'),
    numberOfDrawers: z.number().int().min(1, 'numberOfDrawers must be >= 1'),
    drawerCapacity: z.number().int().min(1, 'drawerCapacity must be >= 1'),
  })
  .strict();

export const activateMedicineBoxSchema = z
  .object({
    deviceId: z.string().min(1, 'Device ID is required'),
    deviceToken: z.string().min(1, 'Device token is required'),
  })
  .strict();

export const userUpdateMedicineBoxSchema = z
  .object({
    name: z.string().min(1, 'Name is required').optional(),
  })
  .strict();

const validStatuses: readonly MedicineBoxStatus[] = ['READY', 'ACTIVE', 'MAINTENANCE'];

export const adminUpdateMedicineBoxSchema = z
  .object({
    name: z.string().min(1, 'Name is required').optional(),
    numberOfDrawers: z
      .number()
      .int()
      .min(1, 'numberOfDrawers must be >= 1')
      .optional(),
    drawerCapacity: z
      .number()
      .int()
      .min(1, 'drawerCapacity must be >= 1')
      .optional(),
    status: z.enum(validStatuses as [MedicineBoxStatus, ...MedicineBoxStatus[]]).optional(),
  })
  .strict();
