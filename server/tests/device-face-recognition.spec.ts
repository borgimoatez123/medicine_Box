import type { Patient } from '@domain/entities/Patient';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IFaceVerificationEventRepository } from '@domain/repositories/IFaceVerificationEventRepository';
import { GetPatientFaceReference } from '@application/use-cases/device/GetPatientFaceReference';
import { RecordFaceVerification } from '@application/use-cases/device/RecordFaceVerification';
import { faceVerificationSchema, getFaceReferenceSchema } from '@presentation/validators/devices.validator';
import { NotFoundError, ForbiddenError, BadRequestError } from '@shared/errors';
import { PrismaFaceVerificationEventRepository } from '@infrastructure/database/prisma/repositories/PrismaFaceVerificationEventRepository';

const mkFn = () => jest.fn();

type MockPatientRepo = Pick<IPatientRepository, 'findById' | 'findByIdAndUserId'>;
type MockBoxRepo = Pick<IMedicineBoxRepository, 'findByDeviceId'>;
type MockFaceRepo = Pick<IFaceVerificationEventRepository, 'create' | 'countByPatientId'>;

const mkPatientRepo = (): MockPatientRepo => ({
  findById: mkFn(),
  findByIdAndUserId: mkFn(),
});
const mkBoxRepo = (): MockBoxRepo => ({ findByDeviceId: mkFn() });
const mkFaceRepo = (): MockFaceRepo => ({
  create: mkFn(),
  countByPatientId: mkFn(),
});

const now = () => new Date('2026-09-23T12:00:00.000Z');

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
  avatarUrl: 'https://kyxmkhdrnijymlotjynr.supabase.co/storage/v1/object/public/patient-avatars/patients/patient-123/avatar/face.jpg',
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const buildBox = (o: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-DEV-001',
  deviceToken: 'T0K3N',
  name: 'Kitchen Box',
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

describe('§ Raspberry Pi Face Recognition Backend — 6 tests', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('Test 1 - Get reference image → 200 + valid face reference payload', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const patient = buildPatient();
    const box = buildBox();
    (pr.findById as jest.Mock).mockResolvedValue(patient);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(box);
    const uc = new GetPatientFaceReference(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
    );
    const r = await uc.execute('patient-123', 'PI-DEV-001');
    expect(r.patientId).toBe('patient-123');
    expect(r.faceReference.url).toBe(patient.avatarUrl);
    expect(typeof r.faceReference.updatedAt.toISOString()).toBe('string');
  });

  it('Test 2 - Patient does not exist → 404 NotFound "Patient not found"', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    (pr.findById as jest.Mock).mockResolvedValue(null);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    const uc = new GetPatientFaceReference(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
    );
    await expect(uc.execute('patient-xxx', 'PI-DEV-001')).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('patient-xxx', 'PI-DEV-001');
    } catch (e) {
      expect((e as Error).message).toBe('Patient not found');
    }
  });

  it('Test 3 - Patient not associated with device (userId mismatch + unassigned box) → 403 Forbidden', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const patientOtherOwner = buildPatient({ userId: 'u-2' });
    const boxA = buildBox({ userId: 'u-1' });
    (pr.findById as jest.Mock).mockResolvedValue(patientOtherOwner);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(boxA);
    const uc = new GetPatientFaceReference(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
    );
    await expect(uc.execute('patient-123', 'PI-DEV-001')).rejects.toThrow(ForbiddenError);

    const br2 = mkBoxRepo();
    const unassignedBox = buildBox({ userId: null });
    (br2.findByDeviceId as jest.Mock).mockResolvedValue(unassignedBox);
    (pr.findById as jest.Mock).mockResolvedValue(buildPatient({ userId: 'u-3' }));
    const uc2 = new GetPatientFaceReference(
      pr as unknown as IPatientRepository,
      br2 as unknown as IMedicineBoxRepository,
    );
    await expect(uc2.execute('patient-123', 'PI-DEV-001')).rejects.toThrow(ForbiddenError);
  });

  it('Test 4 - Successful face verification → 200, event recorded with verified=true + correct message', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const fr = mkFaceRepo();
    const patient = buildPatient();
    const box = buildBox();
    (pr.findById as jest.Mock).mockResolvedValue(patient);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(box);
    (fr.create as jest.Mock).mockImplementation(async (d: Record<string, unknown>) => ({
      id: 'evt-1',
      deviceId: String(d.deviceId),
      patientId: String(d.patientId),
      verified: Boolean(d.verified),
      similarity: d.similarity === undefined || d.similarity === null ? null : Number(d.similarity),
      timestamp: new Date(),
    }));
    const uc = new RecordFaceVerification(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
      fr as unknown as IFaceVerificationEventRepository,
    );
    const r = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      verified: true,
    });
    expect(r.event.verified).toBe(true);
    expect(r.message).toBe('Patient verified successfully');
    expect((fr.create as jest.Mock)).toHaveBeenCalledTimes(1);
    expect((fr.create as jest.Mock).mock.calls[0][0].deviceId).toBe('PI-DEV-001');
  });

  it('Test 5 - Failed face verification → 200 with message "Face verification failed", event.verified=false recorded, similarity stored', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const fr = mkFaceRepo();
    const patient = buildPatient();
    const box = buildBox();
    (pr.findById as jest.Mock).mockResolvedValue(patient);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(box);
    (fr.create as jest.Mock).mockImplementation(async (d: Record<string, unknown>) => ({
      id: 'evt-2',
      deviceId: String(d.deviceId),
      patientId: String(d.patientId),
      verified: Boolean(d.verified),
      similarity: d.similarity === undefined || d.similarity === null ? null : Number(d.similarity),
      timestamp: new Date(),
    }));
    const uc = new RecordFaceVerification(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
      fr as unknown as IFaceVerificationEventRepository,
    );
    const r = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      verified: false,
      similarity: 0.12,
    });
    expect(r.event.verified).toBe(false);
    expect(r.message).toBe('Face verification failed');
    expect(r.event.similarity).toBeCloseTo(0.12, 2);
    expect((fr.create as jest.Mock)).toHaveBeenCalledTimes(1);
  });

  it('Test 6 - Invalid request (empty body) → 400 BadRequest (zod validation failure)', () => {
    const emptyBody = faceVerificationSchema.safeParse({});
    expect(emptyBody.success).toBe(false);
    const emptyGet = getFaceReferenceSchema.safeParse({ patientId: '   ', deviceId: '' });
    expect(emptyGet.success).toBe(false);
    // Spy the Prisma repo method to ensure Repo impl exists (compile check)
    expect(typeof PrismaFaceVerificationEventRepository.prototype.create).toBe('function');
    expect(typeof PrismaFaceVerificationEventRepository.prototype.countByPatientId).toBe('function');
  });

  it('Bonus - similarity=0.05 but verified=true still succeeds; backend never overrides Pi verdict', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const fr = mkFaceRepo();
    (pr.findById as jest.Mock).mockResolvedValue(buildPatient());
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    (fr.create as jest.Mock).mockImplementation(async (d: Record<string, unknown>) => ({
      id: 'evt-3',
      deviceId: String(d.deviceId),
      patientId: String(d.patientId),
      verified: Boolean(d.verified),
      similarity: Number(d.similarity),
      timestamp: new Date(),
    }));
    const uc = new RecordFaceVerification(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
      fr as unknown as IFaceVerificationEventRepository,
    );
    const r = await uc.execute({
      deviceId: 'PI-DEV-001',
      patientId: 'patient-123',
      verified: true,
      similarity: 0.05,
    });
    expect(r.event.verified).toBe(true);
    expect(r.event.similarity).toBe(0.05);
    expect(r.message).toBe('Patient verified successfully');
  });

  it('Bonus - missing avatarUrl → 404 "Patient face reference not found" (user §20 explicit)', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const noFace = buildPatient({ avatarUrl: null });
    (pr.findById as jest.Mock).mockResolvedValue(noFace);
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    const uc = new GetPatientFaceReference(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
    );
    await expect(uc.execute('patient-123', 'PI-DEV-001')).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('patient-123', 'PI-DEV-001');
    } catch (e) {
      expect((e as Error).message).toBe('Patient face reference not found');
    }
  });

  it('Bonus - similarity out of range > 1.0 throws BadRequest (validation)', async () => {
    const pr = mkPatientRepo();
    const br = mkBoxRepo();
    const fr = mkFaceRepo();
    (pr.findById as jest.Mock).mockResolvedValue(buildPatient());
    (br.findByDeviceId as jest.Mock).mockResolvedValue(buildBox());
    const uc = new RecordFaceVerification(
      pr as unknown as IPatientRepository,
      br as unknown as IMedicineBoxRepository,
      fr as unknown as IFaceVerificationEventRepository,
    );
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        patientId: 'patient-123',
        verified: true,
        similarity: 1.2,
      }),
    ).rejects.toThrow(BadRequestError);
  });
});
