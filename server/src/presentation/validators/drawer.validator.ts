import { z } from 'zod';
import type { DrawerStatus } from '@domain/entities/Drawer';

const DRAWER_STATUS: readonly [DrawerStatus, ...DrawerStatus[]] = [
  'EMPTY',
  'LOADED',
  'LOCKED',
  'DISPENSING',
  'ERROR',
] as const;

export const updateDrawerSchema = z
  .object({
    status: z.enum(DRAWER_STATUS).optional(),
  })
  .strict();

export const adminUpdateDrawerSchema = z
  .object({
    status: z.enum(DRAWER_STATUS).optional(),
  })
  .strict();

export const drawerOpenCommandSchema = z
  .object({
    reason: z.string().trim().max(200).optional().nullable(),
  })
  .strict();

export const drawerCloseCommandSchema = z
  .object({
    reason: z.string().trim().max(200).optional().nullable(),
  })
  .strict();
