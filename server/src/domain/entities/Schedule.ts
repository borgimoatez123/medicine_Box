export type ScheduleStatus = 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'ARCHIVED';

export interface Schedule {
  id: string;
  medicationId: string;
  dosage: string;
  timesPerDay: number | null;
  times: unknown | null;
  startDate: Date;
  endDate: Date | null;
  daysOfWeek: unknown | null;
  status: ScheduleStatus;
  notes: string | null;
  refillReminder: boolean;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
}
