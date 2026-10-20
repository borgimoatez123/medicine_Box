import { ProcessPatientMedicationEvent } from '@application/use-cases/device/ProcessPatientMedicationEvent';
import type { IDeviceMedicationEventProcessor } from '@domain/services/IDeviceMedicationEventProcessor';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IScheduleRepository } from '@domain/repositories/IScheduleRepository';
import type { IMedicationRepository } from '@domain/repositories/IMedicationRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerMedicationRepository } from '@domain/repositories/IDrawerMedicationRepository';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Patient } from '@domain/entities/Patient';
import type { Schedule } from '@domain/entities/Schedule';
import type { Medication } from '@domain/entities/Medication';
import type { Drawer } from '@domain/entities/Drawer';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { medicationEventSchema } from '@presentation/validators/devices.validator';
import { BadRequestError, ForbiddenError, ConflictError, NotFoundError } from '@shared/errors';

type AnyFn = jest.Mock<any, any>;

type Repos = {
  boxRepo: IMedicineBoxRepository & { findByDeviceId: AnyFn };
  patientRepo: IPatientRepository & { findById: AnyFn };
  scheduleRepo: IScheduleRepository & { findById: AnyFn };
  medicationRepo: IMedicationRepository & { findById: AnyFn };
  drawerRepo: IDrawerRepository & { findById: AnyFn };
  drawerMedRepo: IDrawerMedicationRepository & { findByDrawerId: AnyFn };
  processor: IDeviceMedicationEventProcessor & { processEvent: AnyFn };
};

const makeBox = (patch: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-DEV-001',
  deviceToken: 'secret',
  name: 'Box 1',
  status: 'READY',
  deviceStatus: 'ACTIVE',
  lastSeenAt: new Date(),
  userId: 'user-1',
  numberOfDrawers: 4,
  drawerCapacity: 20,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...patch,
});

const makePatient = (patch: Partial<Patient> = {}): Patient => ({
  id: 'patient-123',
  userId: 'user-1',
  fullName: 'Alice',
  dateOfBirth: null,
  gender: null,
  weightKg: null,
  heightCm: null,
  bloodType: null,
  allergies: null,
  notes: null,
  avatarUrl: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...patch,
});

const makeSchedule = (patch: Partial<Schedule> = {}): Schedule => ({
  id: 'schedule-1',
  medicationId: 'med-1',
  dosage: '2 tablets',
  timesPerDay: 1,
  times: ['08:00'],
  startDate: new Date(),
  endDate: null,
  daysOfWeek: null,
  status: 'ACTIVE',
  notes: null,
  refillReminder: false,
  createdAt: new Date(),
  updatedAt: new Date(),
  isActive: true,
  ...patch,
});

const makeMedication = (patch: Partial<Medication> = {}): Medication => ({
  id: 'med-1',
  patientId: 'patient-123',
  name: 'Med A',
  dosage: '2 tablets',
  form: 'TABLET',
  quantity: 100,
  expiryDate: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...patch,
});

const makeDrawer = (patch: Partial<Drawer> = {}): Drawer => ({
  id: 'drawer-1',
  medicineBoxId: 'box-1',
  drawerNumber: 1,
  status: 'LOADED',
  createdAt: new Date(),
  updatedAt: new Date(),
  ...patch,
});

const makeDrawerMedication = (patch: Partial<DrawerMedication> = {}): DrawerMedication => ({
  id: 'dm-1',
  drawerId: 'drawer-1',
  medicationId: 'med-1',
  quantity: 10,
  missingQuantity: 10,
  assignedAt: new Date(),
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...patch,
});

const makeRepos = (
  overrides: Partial<Repos> = {},
  data: {
    box?: MedicineBox | null;
    patient?: Patient | null;
    schedule?: Schedule | null;
    medication?: Medication | null;
    drawer?: Drawer | null;
    dm?: DrawerMedication | null;
  } = {},
): Repos & { uc: ProcessPatientMedicationEvent } => {
  const boxRepo: Repos['boxRepo'] = {
    findByDeviceId: jest.fn(async () => (data.box === undefined ? makeBox() : data.box)),
  } as unknown as Repos['boxRepo'];
  const patientRepo: Repos['patientRepo'] = {
    findById: jest.fn(async () => (data.patient === undefined ? makePatient() : data.patient)),
  } as unknown as Repos['patientRepo'];
  const scheduleRepo: Repos['scheduleRepo'] = {
    findById: jest.fn(async () => (data.schedule === undefined ? makeSchedule() : data.schedule)),
  } as unknown as Repos['scheduleRepo'];
  const medicationRepo: Repos['medicationRepo'] = {
    findById: jest.fn(async () => (data.medication === undefined ? makeMedication() : data.medication)),
  } as unknown as Repos['medicationRepo'];
  const drawerRepo: Repos['drawerRepo'] = {
    findById: jest.fn(async () => (data.drawer === undefined ? makeDrawer() : data.drawer)),
  } as unknown as Repos['drawerRepo'];
  const drawerMedRepo: Repos['drawerMedRepo'] = {
    findByDrawerId: jest.fn(async () => (data.dm === undefined ? makeDrawerMedication() : data.dm)),
  } as unknown as Repos['drawerMedRepo'];
  const processor: Repos['processor'] = {
    processEvent: jest.fn(async (input) => ({
      duplicate: false,
      session: {
        id: 'session-1',
        scheduleId: input.scheduleId,
        patientId: input.patientId,
        medicationId: input.medicationId,
        drawerId: input.drawerId,
        scheduledAt: input.scheduledAt,
        startedAt: new Date(),
        completedAt: new Date(),
        quantityBefore: input.currentQuantity,
        quantityAfter:
          input.status === 'TAKEN'
            ? input.currentQuantity - input.quantityTaken
            : input.currentQuantity,
        result: input.status === 'TAKEN' ? 'PATIENT_TAKEN' : 'MISSED',
        occurrenceDate: input.occurrenceDate,
        occurrenceTime: input.occurrenceTime,
      },
      remainingQuantity:
        input.status === 'TAKEN'
          ? input.currentQuantity - input.quantityTaken
          : input.currentQuantity,
      refillRequired:
        input.status === 'TAKEN' && input.currentQuantity - input.quantityTaken === 0,
      missingQuantity:
        input.status === 'TAKEN'
          ? Math.max(0, input.drawerCapacity - (input.currentQuantity - input.quantityTaken))
          : Math.max(0, input.drawerCapacity - input.currentQuantity),
    })),
  } as unknown as Repos['processor'];
  const merged: Repos = {
    boxRepo,
    patientRepo,
    scheduleRepo,
    medicationRepo,
    drawerRepo,
    drawerMedRepo,
    processor,
    ...overrides,
  };
  const uc = new ProcessPatientMedicationEvent(
    merged.boxRepo,
    merged.patientRepo,
    merged.scheduleRepo,
    merged.medicationRepo,
    merged.drawerRepo,
    merged.drawerMedRepo,
    merged.processor,
  );
  return { ...merged, uc };
};

describe('ProcessPatientMedicationEvent', () => {
  it('T1 — Successful TAKEN decreases quantity to 8 and creates session event', async () => {
    const { uc, processor } = makeRepos();
    const result = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'TAKEN',
      quantityTaken: 2,
    });
    expect(processor.processEvent).toHaveBeenCalledTimes(1);
    expect(result.status).toBe('TAKEN');
    expect(result.remainingQuantity).toBe(8);
    expect(result.refillRequired).toBe(false);
    expect(result.duplicate).toBeUndefined();
  });

  it('T2 — TAKEN when current quantity equals dosage: newQuantity=0, refillRequired=true + missingQuantity = drawerCapacity', async () => {
    const dm = makeDrawerMedication({ quantity: 2 });
    const { uc, processor } = makeRepos(undefined, { dm });
    const result = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'TAKEN',
      quantityTaken: 2,
    });
    expect(processor.processEvent).toHaveBeenCalledTimes(1);
    expect(result.remainingQuantity).toBe(0);
    expect(result.refillRequired).toBe(true);
    expect(result.missingQuantity).toBe(20);
  });

  it('T3 — MISSED event creates session and leaves quantity unchanged', async () => {
    const dm = makeDrawerMedication({ quantity: 10 });
    const { uc, processor } = makeRepos(undefined, { dm });
    const result = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'MISSED',
      quantityTaken: 0,
    });
    expect(processor.processEvent).toHaveBeenCalledTimes(1);
    expect(result.status).toBe('MISSED');
    expect(result.remainingQuantity).toBe(10);
    expect(result.refillRequired).toBe(false);
  });

  it('T4 — Insufficient quantity returns Conflict 409 and processor is not called', async () => {
    const dm = makeDrawerMedication({ quantity: 1 });
    const { uc, processor } = makeRepos(undefined, { dm });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-1',
        status: 'TAKEN',
        quantityTaken: 2,
      }),
    ).rejects.toThrow(ConflictError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });

  it('T5 — Wrong patient userId vs box.userId returns Forbidden 403', async () => {
    const patient = makePatient({ userId: 'other-user' });
    const { uc, processor } = makeRepos(undefined, { patient });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-1',
        status: 'TAKEN',
        quantityTaken: 2,
      }),
    ).rejects.toThrow(ForbiddenError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });

  it('T6 — Schedule medication belongs to drawer-1, request says drawer-2 with different dm medication → 409', async () => {
    const drawer2 = makeDrawer({ id: 'drawer-2' });
    const drawerMedRepo: Repos['drawerMedRepo'] = {
      findByDrawerId: jest.fn(async (did: string) => {
        if (did === 'drawer-2') {
          return makeDrawerMedication({
            drawerId: 'drawer-2',
            medicationId: 'med-OTHER',
          });
        }
        return makeDrawerMedication();
      }),
    } as unknown as Repos['drawerMedRepo'];
    const { uc, processor } = makeRepos({ drawerMedRepo }, { drawer: drawer2 });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-2',
        status: 'TAKEN',
        quantityTaken: 2,
      }),
    ).rejects.toThrow(ConflictError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });

  it('T7 — Wrong dosage (dosage expected 2, request 1) → Conflict, no processor call', async () => {
    const { uc, processor } = makeRepos();
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-1',
        status: 'TAKEN',
        quantityTaken: 1,
      }),
    ).rejects.toThrow(ConflictError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });

  it('T8 — Duplicate event idempotent: processor returns duplicate=true; remaining stays 8 unchanged', async () => {
    const dm = makeDrawerMedication({ quantity: 10 });
    const processor: Repos['processor'] = {
      processEvent: jest.fn(),
    } as unknown as Repos['processor'];
    (processor.processEvent as AnyFn)
      .mockResolvedValueOnce({
        duplicate: false,
        session: {
          id: 's1',
          scheduleId: 'schedule-1',
          patientId: 'patient-123',
          medicationId: 'med-1',
          drawerId: 'drawer-1',
          scheduledAt: new Date(),
          startedAt: new Date(),
          completedAt: new Date(),
          quantityBefore: 10,
          quantityAfter: 8,
          result: 'PATIENT_TAKEN',
          occurrenceDate: new Date(),
          occurrenceTime: '08:00',
        },
        remainingQuantity: 8,
        refillRequired: false,
        missingQuantity: 12,
      })
      .mockResolvedValueOnce({
        duplicate: true,
        session: {
          id: 's1',
          scheduleId: 'schedule-1',
          patientId: 'patient-123',
          medicationId: 'med-1',
          drawerId: 'drawer-1',
          scheduledAt: new Date(),
          startedAt: new Date(),
          completedAt: new Date(),
          quantityBefore: 10,
          quantityAfter: 8,
          result: 'PATIENT_TAKEN',
          occurrenceDate: new Date(),
          occurrenceTime: '08:00',
        },
        remainingQuantity: 8,
        refillRequired: false,
        missingQuantity: 12,
      });
    const { uc } = makeRepos({ processor }, { dm });
    const first = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'TAKEN',
      quantityTaken: 2,
    });
    expect(first.remainingQuantity).toBe(8);
    expect(first.duplicate).toBeUndefined();
    const second = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'TAKEN',
      quantityTaken: 2,
    });
    expect(second.duplicate).toBe(true);
    expect(second.remainingQuantity).toBe(8);
    expect(second.message).toBe('Medication event already processed');
  });

  it('Bonus — Device not found → NotFound 404', async () => {
    const { uc, processor } = makeRepos(undefined, { box: null });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-1',
        status: 'TAKEN',
        quantityTaken: 2,
      }),
    ).rejects.toThrow(NotFoundError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });

  it('Bonus — MISSED with quantityTaken=3 fails validator schema → BadRequest', () => {
    const res = medicationEventSchema.safeParse({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'MISSED',
      quantityTaken: 3,
    });
    expect(res.success).toBe(false);
  });

  it('Bonus — TAKEN negative quantity fails schema validator', () => {
    const res = medicationEventSchema.safeParse({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      scheduleId: 'schedule-1',
      drawerId: 'drawer-1',
      status: 'TAKEN',
      quantityTaken: -2,
    });
    expect(res.success).toBe(false);
  });

  it('Bonus — Schedule dosage format not supported (non leading-int string) throws BadRequest', async () => {
    const schedule = makeSchedule({ dosage: 'as needed' });
    const { uc, processor } = makeRepos(undefined, { schedule });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        scheduleId: 'schedule-1',
        drawerId: 'drawer-1',
        status: 'TAKEN',
        quantityTaken: 2,
      }),
    ).rejects.toThrow(BadRequestError);
    expect(processor.processEvent).not.toHaveBeenCalled();
  });
});
