import type { MedicationSession, MedicationSessionResult } from '@domain/entities/MedicationSession';

export type MedicationEventFilters = {
  deviceId?: string;
  patientId?: string;
  scheduleId?: string;
  drawerId?: string;
  result?: MedicationSessionResult;
  /** When provided, scope results to patients owned by this user (multi-tenant isolation). */
  userId?: string;
};

export type MedicationEventPagination = {
  limit: number;
  offset: number;
};

export type MedicationEventListResult = {
  events: Array<MedicationSession & { deviceId: string | null }>;
  total: number;
  limit: number;
  offset: number;
};

export type CreateMedicationSessionData = Omit<
  MedicationSession,
  'id' | 'startedAt' | 'completedAt' | 'quantityAfter' | 'result'
> & {
  startedAt?: Date;
};

export type UpdateMedicationSessionPatch = Partial<{
  startedAt: Date;
  completedAt: Date;
  quantityAfter: number | null;
  result: MedicationSessionResult | null;
}>;

export type MarkSessionResultArgs = {
  id: string;
  result: MedicationSessionResult;
  completedAt?: Date;
  quantityAfter?: number;
};

export type FindActiveForDrawerResult =
  | { kind: 'found'; session: MedicationSession }
  | { kind: 'none' };

export type CreateMedicationSessionWithOccurrenceData = CreateMedicationSessionData &
  Partial<{
    completedAt: Date | null;
    quantityAfter: number | null;
    result: MedicationSessionResult | null;
    occurrenceDate: Date | null;
    occurrenceTime: string | null;
  }>;

export interface IMedicationSessionRepository {
  create(data: CreateMedicationSessionData): Promise<MedicationSession>;
  createWithOccurrence(data: CreateMedicationSessionWithOccurrenceData): Promise<MedicationSession>;
  findById(id: string): Promise<MedicationSession | null>;
  findByOccurrence(
    scheduleId: string,
    occurrenceDate: Date,
    occurrenceTime: string,
  ): Promise<MedicationSession | null>;
  findActiveForDrawer(drawerId: string): Promise<FindActiveForDrawerResult>;
  findLatestForSchedule(scheduleId: string): Promise<MedicationSession | null>;
  update(id: string, patch: UpdateMedicationSessionPatch): Promise<MedicationSession | null>;
  markResult(args: MarkSessionResultArgs): Promise<MedicationSession | null>;
  listByDrawer(drawerId: string, limit?: number): Promise<MedicationSession[]>;
  findMany(
    filters: MedicationEventFilters,
    pagination: MedicationEventPagination,
  ): Promise<MedicationEventListResult>;
}
