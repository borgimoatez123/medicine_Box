import { z } from 'zod';
import type { MedicationForm } from '@domain/entities/Medication';

const MEDICATION_FORM_VALUES: readonly MedicationForm[] = [
  'TABLET', 'CAPSULE', 'LIQUID', 'INJECTION', 'CREAM', 'POWDER', 'OTHER',
];
const medicationFormEnum = z.enum(MEDICATION_FORM_VALUES as unknown as [string, ...string[]]);

export const createMedicationSchema = z
  .object({
    patientId: z.string().uuid('Invalid patient ID format'),
    name: z.string().min(1, 'Medication name is required'),
    dosage: z.string().min(1, 'Dosage is required'),
    form: medicationFormEnum.default('TABLET'),
    quantity: z.number().int().min(1, 'Quantity must be at least 1'),
    expiryDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().date())
      .nullish(),
  })
  .strict();

export const updateMedicationSchema = z
  .object({
    name: z.string().min(1, 'Medication name is required').optional(),
    dosage: z.string().min(1, 'Dosage is required').optional(),
    form: medicationFormEnum.optional(),
    quantity: z.number().int().min(1, 'Quantity must be at least 1').optional(),
    expiryDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().date())
      .nullish(),
  })
  .strict();
