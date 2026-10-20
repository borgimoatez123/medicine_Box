import { z } from 'zod';

const nonNegInt = z.number().int('Must be an integer').min(0, 'Cannot be negative');

export const createDrawerMedicationSchema = z
  .object({
    drawerId: z.string().min(1),
    medicationId: z.string().min(1),
    quantity: nonNegInt,
    missingQuantity: nonNegInt,
  })
  .strict();

export const updateDrawerMedicationSchema = z
  .object({
    isActive: z.boolean().optional(),
    quantity: nonNegInt.optional(),
    missingQuantity: nonNegInt.optional(),
  })
  .strict();
