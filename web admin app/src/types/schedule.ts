export type ScheduleStatus = 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'ARCHIVED';

export interface Schedule {
  id: string;
  medicationId: string;
  dosage: string;
  timesPerDay: number | null;
  times: string[] | null;
  startDate: Date | string;
  endDate: Date | string | null;
  daysOfWeek: number[] | null;
  status: ScheduleStatus;
  notes: string | null;
  refillReminder: boolean;
  createdAt: Date | string;
  updatedAt: Date | string;
  isActive: boolean;
}
