import type { Patient } from '@domain/entities/Patient';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Schedule } from '@domain/entities/Schedule';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type {
  IScheduleRepository,
  ScheduleDeviceSyncRow,
} from '@domain/repositories/IScheduleRepository';
import { GetDeviceSchedule } from '@application/use-cases/device/GetDeviceSchedule';
import { getDeviceScheduleSchema } from '@presentation/validators/devices.validator';
import { NotFoundError, BadRequestError } from '@shared/errors';

const mkFn = () => jest.fn();

type MockBoxRepo = Pick<IMedicineBoxRepository, 'findByDeviceId'>;
type MockPatientRepo = Pick<IPatientRepository, 'findFirstByUserId'>;
type MockScheduleRepo = Pick<
  IScheduleRepository,
  'findAllActiveByPatientIdForDeviceSync'
>;

const mkBoxRepo = (): MockBoxRepo => ({ findByDeviceId: mkFn() });
const mkPatientRepo = (): MockPatientRepo => ({ findFirstByUserId: mkFn() });
const mkScheduleRepo = (): MockScheduleRepo => ({
  findAllActiveByPatientIdForDeviceSync: mkFn(),
});

const now = () => new Date('2026-09-23T12:00:00.000Z');

const buildBox = (o: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-DEV-001',
  deviceToken: 'TOK',
  name: 'Kitchen',
  status: 'READY',
  deviceStatus: 'OFFLINE',
  lastSeenAt: null,
  userId: 'u-1',
  numberOfDrawers: 4,
  drawerCapacity: 20,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const buildPatient = (o: Partial<Patient> = {}): Patient => ({
  id: 'patient-123',
  userId: 'u-1',
  fullName: 'Alice',
  dateOfBirth: null,
  gender: null,
  weightKg: null,
  heightCm: null,
  bloodType: null,
  allergies: null,
  notes: null,
  avatarUrl: null,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

type BuildScheduleOpts = Partial<Schedule> & {
  medicationName?: string;
  drawerMedication?: ScheduleDeviceSyncRow['drawerMedication'];
};

const buildScheduleRow = (o: BuildScheduleOpts = {}): ScheduleDeviceSyncRow => {
  const { medicationName, drawerMedication, ...rest } = o;
  const schedule: Schedule = {
    id: 'sched-1',
    medicationId: 'med-1',
    dosage: '1 tablet',
    timesPerDay: 2,
    times: ['08:00', '20:00'],
    startDate: new Date('2026-09-01'),
    endDate: null,
    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    status: 'ACTIVE',
    notes: null,
    refillReminder: false,
    createdAt: now(),
    updatedAt: now(),
    isActive: true,
    ...rest,
  };
  return {
    schedule,
    medication: {
      id: schedule.medicationId,
      name: medicationName ?? 'Paracetamol',
    },
    drawerMedication: drawerMedication ?? {
      id: 'dm-1',
      drawerId: 'drawer-1',
      quantity: 10,
      isActive: true,
      drawer: { medicineBoxId: 'box-1' },
    },
  };
};

describe('§ Raspberry Pi Schedule Sync Backend — tests T1–T7 + bonus', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('Test 1 - Valid device with patient and schedules → 200 equivalent, schedules[0] has full FR-5 keys', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    (pr.findFirstByUserId as jest.Mock).mockResolvedValue(buildPatient());
    (sr.findAllActiveByPatientIdForDeviceSync as jest.Mock).mockResolvedValue([
      buildScheduleRow({
        id: 'sched-1',
        medicationId: 'med-1',
        medicationName: 'Paracetamol',
        dosage: '2 tablets',
        times: ['08:00'],
        timesPerDay: 1,
      }),
    ]);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    const r = await uc.execute('PI-DEV-001');
    expect(r.patientId).toBe('patient-123');
    expect(Array.isArray(r.schedules)).toBe(true);
    expect(r.schedules.length).toBe(1);
    const row = r.schedules[0];
    expect(typeof row.scheduleId).toBe('string');
    expect(row.medicationId).toBe('med-1');
    expect(row.medicationName).toBe('Paracetamol');
    expect(row.drawerId).toBe('drawer-1');
    expect(row.dosage).toBe('2 tablets');
    expect(row.time).toBe('08:00');
    expect(row.quantity).toBe(10);
    expect(row.status).toBe('ACTIVE');
    expect(row.isActive).toBe(true);
    expect(typeof row.startDate).toBe('string');
    expect(row.startDate.length).toBe(10);
  });

  it('Test 2 - Device does not exist → 404 NotFound "Device not found"', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(null);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    await expect(uc.execute('NO-SUCH-DEVICE')).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('NO-SUCH-DEVICE');
    } catch (e) {
      expect((e as Error).message).toBe('Device not found');
    }
  });

  it('Test 3 - Box userId is null → 404 "No patient assigned to this medicine box" (T3 + T4 covered)', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox({ userId: null }));
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    await expect(uc.execute('PI-DEV-001')).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('PI-DEV-001');
    } catch (e) {
      expect((e as Error).message).toBe('No patient assigned to this medicine box');
    }

    const br2 = mkBoxRepo();
    const pr2 = mkPatientRepo();
    (br2.findByDeviceId as jest.Mock).mockResolvedValue(buildBox({ userId: 'u-999' }));
    (pr2.findFirstByUserId as jest.Mock).mockResolvedValue(null);
    const uc2 = new GetDeviceSchedule(
      br2 as unknown as IMedicineBoxRepository,
      pr2 as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    await expect(uc2.execute('PI-DEV-001')).rejects.toThrow(NotFoundError);
    try {
      await uc2.execute('PI-DEV-001');
    } catch (e) {
      expect((e as Error).message).toBe('No patient assigned to this medicine box');
    }
  });

  it('Test 4 - Empty deviceId → 400 BadRequestError', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    await expect(uc.execute('')).rejects.toThrow(BadRequestError);
    try {
      await uc.execute('   ');
    } catch (e) {
      expect((e as Error).message).toBe('deviceId is required');
    }
  });

  it('Test 5 - Patient has no schedules → 200 schedules: [] (no throw)', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    (pr.findFirstByUserId as jest.Mock).mockResolvedValue(buildPatient());
    (sr.findAllActiveByPatientIdForDeviceSync as jest.Mock).mockResolvedValue([]);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    const r = await uc.execute('PI-DEV-001');
    expect(r.patientId).toBe('patient-123');
    expect(r.schedules).toEqual([]);
  });

  it('Test 6 - Multiple schedules with multiple times → all rows, deterministic sort by time', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    (pr.findFirstByUserId as jest.Mock).mockResolvedValue(buildPatient());
    (sr.findAllActiveByPatientIdForDeviceSync as jest.Mock).mockResolvedValue([
      buildScheduleRow({
        id: 'sched-A',
        medicationId: 'med-A',
        medicationName: 'Paracetamol',
        times: ['08:00', '20:00'],
        timesPerDay: 2,
        drawerMedication: {
          id: 'dm-A',
          drawerId: 'drawer-1',
          quantity: 10,
          isActive: true,
          drawer: { medicineBoxId: 'box-1' },
        },
      }),
      buildScheduleRow({
        id: 'sched-B',
        medicationId: 'med-B',
        medicationName: 'Antibiotic',
        dosage: '1 capsule',
        times: ['14:00'],
        timesPerDay: 1,
        drawerMedication: {
          id: 'dm-B',
          drawerId: 'drawer-2',
          quantity: 5,
          isActive: true,
          drawer: { medicineBoxId: 'box-1' },
        },
      }),
    ]);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    const r = await uc.execute('PI-DEV-001');
    expect(r.schedules.length).toBe(3);
    expect(r.schedules.map((s) => s.time)).toEqual(['08:00', '14:00', '20:00']);
    expect(r.schedules[0].scheduleId).toBe('sched-A');
    expect(r.schedules[0].medicationName).toBe('Paracetamol');
    expect(r.schedules[1].scheduleId).toBe('sched-B');
    expect(r.schedules[1].drawerId).toBe('drawer-2');
    expect(r.schedules[1].quantity).toBe(5);
    expect(r.schedules[2].scheduleId).toBe('sched-A');
    expect(r.schedules[2].time).toBe('20:00');
  });

  it('Test 7 - Inactive status / isActive schedules excluded by repo filter (repo returns only ACTIVE, verify payload status always ACTIVE isActive true)', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    (pr.findFirstByUserId as jest.Mock).mockResolvedValue(buildPatient());
    (sr.findAllActiveByPatientIdForDeviceSync as jest.Mock).mockResolvedValue([
      buildScheduleRow({
        id: 'sched-act',
        medicationId: 'med-act',
        medicationName: 'ActiveMed',
        times: ['09:00'],
        timesPerDay: 1,
        status: 'ACTIVE',
        isActive: true,
      }),
    ]);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    const r = await uc.execute('PI-DEV-001');
    for (const row of r.schedules) {
      expect(row.status).toBe('ACTIVE');
      expect(row.isActive).toBe(true);
    }
  });

  it('Bonus B1 - Inactive drawer med (drawer.medicineBoxId != box.id) → drawerId null, quantity null (row still included)', async () => {
    const br = mkBoxRepo();
    const pr = mkPatientRepo();
    const sr = mkScheduleRepo();
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox({ id: 'box-1' }));
    (pr.findFirstByUserId as jest.Mock).mockResolvedValue(buildPatient());
    (sr.findAllActiveByPatientIdForDeviceSync as jest.Mock).mockResolvedValue([
      buildScheduleRow({
        id: 'sched-wrong-box',
        medicationId: 'med-X',
        medicationName: 'OtherBoxMed',
        times: ['08:00'],
        timesPerDay: 1,
        drawerMedication: {
          id: 'dm-other',
          drawerId: 'drawer-99',
          quantity: 99,
          isActive: true,
          drawer: { medicineBoxId: 'box-OTHER' },
        },
      }),
    ]);
    const uc = new GetDeviceSchedule(
      br as unknown as IMedicineBoxRepository,
      pr as unknown as IPatientRepository,
      sr as unknown as IScheduleRepository,
    );
    const r = await uc.execute('PI-DEV-001');
    expect(r.schedules.length).toBe(1);
    expect(r.schedules[0].drawerId).toBeNull();
    expect(r.schedules[0].quantity).toBeNull();
  });

  it('Bonus B2 - Validator schema getDeviceScheduleSchema empty reject / valid pass', () => {
    expect(getDeviceScheduleSchema.safeParse({ deviceId: '' }).success).toBe(false);
    expect(getDeviceScheduleSchema.safeParse({ deviceId: '   ' }).success).toBe(false);
    expect(getDeviceScheduleSchema.safeParse({ deviceId: 'PI-DEV-001' }).success).toBe(true);
    expect(
      getDeviceScheduleSchema.safeParse({ deviceId: 'PI', extra: 'x' } as any).success,
    ).toBe(false);
  });
});
