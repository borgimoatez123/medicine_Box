import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { Schedule } from '@domain/entities/Schedule';
import type {
  IDeviceMedicationEventProcessor,
  ProcessDeviceMedicationEventOutput,
} from '@domain/services/IDeviceMedicationEventProcessor';
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from '@shared/errors';

export type MedicationEventRequest = {
  deviceId: string;
  patientId: string;
  scheduleId: string;
  drawerId: string;
  status: 'TAKEN' | 'MISSED';
  quantityTaken: number;
};

export type MedicationEventResult = {
  status: 'TAKEN' | 'MISSED';
  patientId: string;
  scheduleId: string;
  drawerId: string;
  quantityTaken: number;
  remainingQuantity: number;
  refillRequired: boolean;
  missingQuantity?: number;
  duplicate?: boolean;
  message?: string;
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
  return ['00:00'];
};

type AfricaTunisParts = { date: Date; time: string };

const getAfricaTunisNow = (): AfricaTunisParts => {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Tunis',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = formatter.formatToParts(now);
  const get = (t: Intl.DateTimeFormatPartTypes): string => {
    const p = parts.find((x) => x.type === t);
    return p?.value ?? '00';
  };
  const day = get('day');
  const month = get('month');
  const year = get('year');
  const hour = get('hour') === '24' ? '00' : get('hour');
  const minute = get('minute');
  const dateOnly = new Date(`${year}-${month}-${day}T00:00:00`);
  return { date: dateOnly, time: `${hour}:${minute}` };
};

const timeToMinutes = (t: string): number => {
  const [h, m] = t.split(':').map((x) => Number(x));
  return h * 60 + m;
};

const resolveClosestSlot = (slots: string[], wallTime: string): string => {
  const wall = timeToMinutes(wallTime);
  let best = slots[0] ?? '00:00';
  let bestDiff = Infinity;
  for (const slot of slots) {
    const s = timeToMinutes(slot);
    const diff = Math.abs(s - wall);
    const wrapped = Math.min(diff, 1440 - diff);
    if (wrapped < bestDiff && wrapped <= 6 * 60) {
      bestDiff = wrapped;
      best = slot;
    }
  }
  return best;
};

const parseLeadingInteger = (value: string): number | null => {
  if (typeof value !== 'string') return null;
  const m = value.trim().match(/^(\d+)/);
  if (!m) return null;
  const n = Number(m[1]);
  if (!Number.isInteger(n) || n <= 0) return null;
  return n;
};

export class ProcessPatientMedicationEvent {
  constructor(
    private readonly medicineBoxRepository: IMedicineBoxRepository,
    private readonly patientRepository: IPatientRepository,
    private readonly scheduleRepository: IScheduleRepository,
    private readonly medicationRepository: IMedicationRepository,
    private readonly drawerRepository: IDrawerRepository,
    private readonly drawerMedicationRepository: IDrawerMedicationRepository,
    private readonly deviceMedicationEventProcessor: IDeviceMedicationEventProcessor,
  ) {}

  async execute(request: MedicationEventRequest): Promise<MedicationEventResult> {
    const deviceId = request.deviceId.trim();
    const patientId = request.patientId.trim();
    const scheduleId = request.scheduleId.trim();
    const drawerId = request.drawerId.trim();
    const status = request.status;
    const quantityTaken = request.quantityTaken;

    const box = await this.medicineBoxRepository.findByDeviceId(deviceId);
    if (!box) throw new NotFoundError('Device not found');

    const patient = await this.patientRepository.findById(patientId);
    if (!patient) throw new NotFoundError('Patient not found');

    if (!box.userId || patient.userId !== box.userId) {
      throw new ForbiddenError('Patient is not associated with this device');
    }

    const schedule = await this.scheduleRepository.findById(scheduleId);
    if (!schedule) throw new NotFoundError('Schedule not found');

    const medication = await this.medicationRepository.findById(schedule.medicationId);
    if (!medication || medication.patientId !== patientId) {
      throw new ForbiddenError('Schedule does not belong to this patient');
    }

    const drawer = await this.drawerRepository.findById(drawerId);
    if (!drawer) throw new NotFoundError('Drawer not found');

    if (drawer.medicineBoxId !== box.id) {
      throw new ConflictError('Drawer does not belong to this device\'s medicine box');
    }

    const drawerMedication = await this.drawerMedicationRepository.findByDrawerId(drawerId);
    if (!drawerMedication) {
      throw new ConflictError('Drawer has no medication assigned');
    }
    if (drawerMedication.medicationId !== medication.id) {
      throw new ConflictError('Schedule medication does not match drawer medication');
    }

    const expectedDosage = parseLeadingInteger(schedule.dosage);
    if (expectedDosage === null) {
      throw new BadRequestError(`Schedule dosage format not supported: ${schedule.dosage}`);
    }

    if (status === 'MISSED') {
      if (quantityTaken !== 0) {
        throw new BadRequestError('quantityTaken must be 0 when status is MISSED');
      }
    } else if (status === 'TAKEN') {
      if (!Number.isInteger(quantityTaken) || quantityTaken <= 0) {
        throw new BadRequestError('quantityTaken must be a positive integer when status is TAKEN');
      }
      if (expectedDosage !== quantityTaken) {
        throw new ConflictError('Quantity taken does not match scheduled dosage');
      }
    } else {
      throw new BadRequestError('Unsupported status');
    }

    const tunisNow = getAfricaTunisNow();
    const slots = expandTimes(schedule);
    const occurrenceTime = resolveClosestSlot(slots, tunisNow.time);
    const occurrenceDate: Date = tunisNow.date;

    const scheduledAt = new Date(
      occurrenceDate.getFullYear(),
      occurrenceDate.getMonth(),
      occurrenceDate.getDate(),
      Number(occurrenceTime.split(':')[0]),
      Number(occurrenceTime.split(':')[1]),
      0,
      0,
    );

    const drawerCapacity: number =
      Number.isInteger(box.drawerCapacity) && box.drawerCapacity >= 0 ? box.drawerCapacity : 0;
    const currentQuantity = Number.isInteger(drawerMedication.quantity)
      ? (drawerMedication.quantity as number)
      : 0;

    if (status === 'TAKEN' && currentQuantity < quantityTaken) {
      throw new ConflictError('Insufficient medication quantity');
    }

    const processorOutput: ProcessDeviceMedicationEventOutput =
      await this.deviceMedicationEventProcessor.processEvent({
        status,
        quantityTaken,
        drawerMedicationId: drawerMedication.id,
        currentQuantity,
        drawerCapacity,
        scheduleId,
        patientId,
        medicationId: medication.id,
        drawerId,
        scheduledAt,
        occurrenceDate,
        occurrenceTime,
      });

    if (processorOutput.duplicate) {
      const remaining = processorOutput.remainingQuantity;
      return {
        status,
        patientId,
        scheduleId,
        drawerId,
        quantityTaken,
        remainingQuantity: remaining,
        refillRequired: processorOutput.refillRequired,
        missingQuantity: processorOutput.missingQuantity,
        duplicate: true,
        message: 'Medication event already processed',
      };
    }

    return {
      status,
      patientId,
      scheduleId,
      drawerId,
      quantityTaken,
      remainingQuantity: processorOutput.remainingQuantity,
      refillRequired: processorOutput.refillRequired,
      missingQuantity: processorOutput.missingQuantity,
    };
  }
}
