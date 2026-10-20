import { z } from 'zod';

const nullableStr = z.string().min(1).nullish();

const positiveNumber = z
  .number()
  .refine((v) => v > 0, 'Value must be greater than 0');

const dateOfBirthField = z
  .string()
  .datetime({ offset: true })
  .or(z.string().date())
  .or(z.null())
  .optional();

export const createPatientSchema = z
  .object({
    fullName: z.string().min(1, 'Full name is required'),
    dateOfBirth: dateOfBirthField,
    gender: nullableStr,
    weightKg: positiveNumber.nullish(),
    heightCm: positiveNumber.nullish(),
    bloodType: nullableStr,
    allergies: nullableStr,
    notes: nullableStr,
    avatarUrl: z
      .string()
      .url()
      .nullish()
      .or(z.literal(null))
      .or(z.string().max(0)),
  })
  .strict();

export const updatePatientSchema = z
  .object({
    fullName: z.string().min(1, 'Full name is required').optional(),
    dateOfBirth: dateOfBirthField,
    gender: nullableStr,
    weightKg: positiveNumber.nullish(),
    heightCm: positiveNumber.nullish(),
    bloodType: nullableStr,
    allergies: nullableStr,
    notes: nullableStr,
    avatarUrl: z
      .string()
      .url()
      .nullish()
      .or(z.literal(null))
      .or(z.string().max(0)),
  })
  .strict();
