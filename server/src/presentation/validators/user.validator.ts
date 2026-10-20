import { z } from 'zod';

export const updateMyProfileSchema = z
  .object({
    firstName: z.string().min(1).nullish(),
    lastName: z.string().min(1).nullish(),
    email: z.string().email('Invalid email address').optional(),
    phone: z.string().nullish(),
  })
  .strict();

export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, 'Current password is required'),
    newPassword: z.string().min(8, 'New password must be at least 8 characters long'),
  })
  .strict();
