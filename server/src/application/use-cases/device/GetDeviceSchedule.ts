import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type {
  IScheduleRepository,
  ScheduleDeviceSyncRow,
} from '@domain/repositories/IScheduleRepository';
import type { Schedule } from '@domain/entities/Schedule';
import {
  BadRequestError,
  NotFoundError,
} from '@shared/errors';

export type DeviceScheduleRow = {
  scheduleId: string;
  medicationId: string;
  medicationName: string;
  drawerId: string | null;
  dosage: string;
  time: string;
  quantity: number | null;
  daysOfWeek: number[] | null;
  startDate: string;
  endDate: string | null;
  timesPerDay: number | null;
  status: 'ACTIVE';
  isActive: true;
};

export type GetDeviceScheduleResult = {
  patientId: string;
  schedules: DeviceScheduleRow[];
};

const HH_MM_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

const expandTimes = (schedule: Schedule): string[] => {
  const raw = schedule.times;
  if (Array.isArray(raw) && raw.length > 0) {
    const seen = new Set<string>();
    const out: string[] = [];
    for (const entry of raw) {
      if (typeof entry === 'string' && HH_MM_REGEX.test(entry) && !seen.has(entry)) {
        seen.add(entry);
        out.push(entry);
      }
    }
    if (out.length > 0) return out;
  }
  if (typeof schedule.timesPerDay === 'number' && schedule.timesPerDay >= 1) {
    return ['00:00'];
  }
  return [];
};

const toDayOfWeekArray = (v: unknown): number[] | null => {
  if (!Array.isArray(v)) return null;
  const out: number[] = [];
  for (const n of v) {
    if (typeof n === 'number' && Number.isInteger(n) && n >= 1 && n <= 7) out.push(n);
  }
  return out.length > 0 ? out : null;
};

const toISODate = (d: Date): string => d.toISOString().slice(0, 10);
const toISODateOrNull = (d: Date | null): string | null => d ? toISODate(d) : null;

export class GetDeviceSchedule {
  constructor(
    private readonly boxRepo: IMedicineBoxRepository,
    private readonly patientRepo: IPatientRepository,
    private readonly scheduleRepo: IScheduleRepository,
  ) {}

  async execute(deviceIdRaw: string): Promise<GetDeviceScheduleResult> {
    const deviceId = (deviceIdRaw ?? '').trim();
    if (!deviceId) throw new BadRequestError('deviceId is required');

    const box = await this.boxRepo.findByDeviceId(deviceId);
    if (!box) throw new NotFoundError('Device not found');

    if (!box.userId) throw new NotFoundError('No patient assigned to this medicine box');
    const patient = await this.patientRepo.findFirstByUserId(box.userId);
    if (!patient) throw new NotFoundError('No patient assigned to this medicine box');

    const rawRows: ScheduleDeviceSyncRow[] =
      await this.scheduleRepo.findAllActiveByPatientIdForDeviceSync(patient.id);

    const rows: DeviceScheduleRow[] = [];
    for (const row of rawRows) {
      const { schedule, medication, drawerMedication } = row;

      let dm = drawerMedication;
      if (dm && dm.drawer.medicineBoxId !== box.id) {
        dm = null;
      }

      const times = expandTimes(schedule);
      if (times.length === 0) continue;

      const base = {
        scheduleId: schedule.id,
        medicationId: medication.id,
        medicationName: medication.name,
        drawerId: dm ? dm.drawerId : null,
        dosage: schedule.dosage,
        quantity: dm ? dm.quantity : null,
        daysOfWeek: toDayOfWeekArray(schedule.daysOfWeek),
        startDate: toISODate(schedule.startDate),
        endDate: toISODateOrNull(schedule.endDate),
        timesPerDay: schedule.timesPerDay,
        status: 'ACTIVE' as const,
        isActive: true as const,
      };

      for (const time of times) {
        rows.push({ ...base, time });
      }
    }

    rows.sort((a, b) => {
      if (a.time !== b.time) return a.time < b.time ? -1 : 1;
      if (a.startDate !== b.startDate) return a.startDate < b.startDate ? -1 : 1;
      if (a.scheduleId !== b.scheduleId) return a.scheduleId < b.scheduleId ? -1 : 1;
      return 0;
    });

    return { patientId: patient.id, schedules: rows };
  }
}
