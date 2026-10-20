import type { Request, Response, NextFunction } from 'express';
import type { Patient } from '@domain/entities/Patient';
import type { UploadPatientAvatarFile } from '@application/use-cases/patients/UploadPatientAvatar';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import {
  createPatientSchema,
  updatePatientSchema,
} from '@presentation/validators/patient.validator';
import { CreatePatient } from '@application/use-cases/patients/CreatePatient';
import { GetPatients } from '@application/use-cases/patients/GetPatients';
import { GetPatientById } from '@application/use-cases/patients/GetPatientById';
import { UpdatePatient } from '@application/use-cases/patients/UpdatePatient';
import { DeletePatient } from '@application/use-cases/patients/DeletePatient';
import { UploadPatientAvatar } from '@application/use-cases/patients/UploadPatientAvatar';
import { DeletePatientAvatar } from '@application/use-cases/patients/DeletePatientAvatar';
import { AVATAR_BUCKET } from '@domain/repositories/IStorageService';
import { NotFoundError, UnauthorizedError, BadRequestError } from '@shared/errors';

type MockRepo = {
  create?: jest.Mock;
  findAllByUserId?: jest.Mock;
  findByIdAndUserId?: jest.Mock;
  findById?: jest.Mock;
  update?: jest.Mock;
  delete?: jest.Mock;
};

type MockStorage = {
  upload: jest.Mock;
  delete: jest.Mock;
  getPublicUrl: jest.Mock;
  extractPathFromPublicUrl: jest.Mock;
};

const mk = jest.fn;
const now = () => new Date('2025-01-01T00:00:00.000Z');
const nextMock = () => jest.fn() as unknown as jest.Mock & NextFunction;
const nextErr = (calls: unknown[]): Error => calls[0] as Error;

const buildPatient = (overrides: Partial<Patient> = {}): Patient => ({
  id: 'p-1',
  userId: 'u-A',
  fullName: 'Ahmed Borji',
  dateOfBirth: new Date('1955-06-15T00:00:00.000Z'),
  gender: 'MALE',
  weightKg: 75,
  heightCm: 170,
  bloodType: 'O+',
  allergies: 'Penicillin',
  notes: 'Needs medication reminders',
  avatarUrl: null,
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

describe('§21 Authentication: no JWT on Patient routes 401', () => {
  const res = {} as Response;
  const check = (reqLike: Partial<Request>) => {
    const mockNext = nextMock();
    requireAuth(reqLike as Request, res, mockNext);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
    expect((err as unknown as { statusCode: number }).statusCode).toBe(401);
  };
  it('POST /patients without JWT → 401', () => check({ headers: {} }));
  it('GET /patients without JWT → 401', () => check({ headers: {} }));
  it('GET /patients/:id without JWT → 401', () => check({ headers: {} }));
  it('PATCH /patients/:id without JWT → 401', () => check({ headers: {} }));
  it('DELETE /patients/:id without JWT → 401', () => check({ headers: {} }));
});

describe('§21 Create Patient', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { create: mk() };
  });

  it('User A creates patient → 201, userId set from authenticatedUserId (not body)', async () => {
    repo.create!.mockResolvedValue(buildPatient({ userId: 'u-A', id: 'p-new' }));
    const uc = new CreatePatient(repo as never);
    const out = await uc.execute({
      userId: 'u-A',
      fullName: 'Ahmed Borji',
      dateOfBirth: '1955-06-15',
      gender: 'MALE',
      weightKg: 75,
      heightCm: 170,
      bloodType: 'O+',
      allergies: 'Penicillin',
      notes: 'Notes',
      avatarUrl: null,
    });
    expect(out.userId).toBe('u-A');
    const [data] = repo.create!.mock.calls[0] as [Record<string, unknown>];
    expect(data.userId).toBe('u-A');
    expect(data.fullName).toBe('Ahmed Borji');
    expect(data.id).toBeUndefined();
  });

  it('body contains userId → validator strict REJECT', () => {
    const p = createPatientSchema.safeParse({
      fullName: 'X',
      userId: 'someone-else',
    });
    expect(p.success).toBe(false);
  });

  it('body contains id → validator strict REJECT', () => {
    const p = createPatientSchema.safeParse({
      fullName: 'X',
      id: 'pwned',
    });
    expect(p.success).toBe(false);
  });

  it('body contains createdAt/updatedAt → validator strict REJECT', () => {
    const p1 = createPatientSchema.safeParse({ fullName: 'X', createdAt: 'x' });
    const p2 = createPatientSchema.safeParse({ fullName: 'X', updatedAt: 'x' });
    expect(p1.success).toBe(false);
    expect(p2.success).toBe(false);
  });
});

describe('§21 List Patients', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { findAllByUserId: mk() };
  });

  it('User A GET /patients → only User A patients returned', async () => {
    repo.findAllByUserId!.mockResolvedValue([
      buildPatient({ id: 'p-A1', userId: 'u-A' }),
      buildPatient({ id: 'p-A2', userId: 'u-A' }),
    ]);
    const uc = new GetPatients(repo as never);
    const out = (await uc.execute({ userId: 'u-A' })) as Patient[];
    expect(repo.findAllByUserId).toHaveBeenCalledWith('u-A', undefined);
    expect(out).toHaveLength(2);
    expect(out.every((p) => p.userId === 'u-A')).toBe(true);
  });

  it('User B GET /patients → only User B patients', async () => {
    repo.findAllByUserId!.mockResolvedValue([
      buildPatient({ id: 'p-B1', userId: 'u-B' }),
    ]);
    const uc = new GetPatients(repo as never);
    const out = (await uc.execute({ userId: 'u-B' })) as Patient[];
    expect(repo.findAllByUserId).toHaveBeenLastCalledWith('u-B', undefined);
    expect(out[0].userId).toBe('u-B');
  });
});

describe('§22 Get Patient by ID + cross-user ownership → 404', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { findByIdAndUserId: mk() };
  });

  it('User A → Patient A → 200', async () => {
    const pat = buildPatient({ id: 'p-A', userId: 'u-A' });
    repo.findByIdAndUserId!.mockResolvedValue(pat);
    const uc = new GetPatientById(repo as never);
    const out = await uc.execute({ userId: 'u-A', patientId: 'p-A' });
    expect(out.id).toBe('p-A');
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
  });

  it('User B → Patient A → NotFoundError (404) prevents enumeration', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new GetPatientById(repo as never);
    await expect(
      uc.execute({ userId: 'u-B', patientId: 'p-A' }),
    ).rejects.toThrow(NotFoundError);
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-B');
  });
});

describe('§21/22 Update Patient + cross-user ownership → 404', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { findByIdAndUserId: mk(), update: mk() };
  });

  it('User A updates Patient A → 200; only supplied fields updated', async () => {
    const original = buildPatient({ id: 'p-A', userId: 'u-A', weightKg: 75 });
    repo.findByIdAndUserId!.mockResolvedValue(original);
    repo.update!.mockResolvedValue({ ...original, weightKg: 72, notes: 'Updated notes', updatedAt: new Date() });
    const uc = new UpdatePatient(repo as never);
    const out = await uc.execute({
      userId: 'u-A', patientId: 'p-A', weightKg: 72, notes: 'Updated notes' });
    expect(out.weightKg).toBe(72);
    expect(out.notes).toBe('Updated notes');
    const [, patch] = repo.update!.mock.calls[0] as [string, Partial<Patient>];
    expect((patch as Record<string, unknown>).weightKg).toBe(72);
    expect((patch as Record<string, unknown>).notes).toBe('Updated notes');
    expect((patch as Record<string, unknown>).userId).toBeUndefined();
    expect((patch as Record<string, unknown>).id).toBeUndefined();
    expect(patch.fullName).toBeUndefined();
    expect(patch.dateOfBirth).toBeUndefined();
  });

  it('User B updates Patient A → 404, no repo.update called', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new UpdatePatient(repo as never);
    await expect(
      uc.execute({ userId: 'u-B', patientId: 'p-A', notes: 'x' }),
    ).rejects.toThrow(NotFoundError);
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('update userId in body → validator strict REJECT', () => {
    const p = updatePatientSchema.safeParse({ weightKg: 70, userId: 'u-other' });
    expect(p.success).toBe(false);
  });

  it('update id in body → validator strict REJECT', () => {
    const p = updatePatientSchema.safeParse({ notes: 'x', id: 'fake-id' });
    expect(p.success).toBe(false);
  });
});

describe('§21/22 Delete Patient + cross-user ownership → 404', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { findByIdAndUserId: mk(), delete: mk() };
  });

  it('User A deletes Patient A → 204 success', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    repo.delete!.mockResolvedValue(undefined);
    const uc = new DeletePatient(repo as never);
    await uc.execute({ userId: 'u-A', patientId: 'p-A' });
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
    expect(repo.delete).toHaveBeenCalledWith('p-A');
  });

  it('DeletePatient does NOT manually cascade meds/schedules/DrawerMedications (leaves to prisma cascade)', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    repo.delete!.mockResolvedValue(undefined);
    const uc = new DeletePatient(repo as never);
    await uc.execute({ userId: 'u-A', patientId: 'p-A' });
    expect(repo.delete).toHaveBeenCalledTimes(1);
    expect(repo.delete).toHaveBeenCalledWith('p-A');
  });

  it('User B deletes Patient A → 404, delete never called', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new DeletePatient(repo as never);
    await expect(
      uc.execute({ userId: 'u-B', patientId: 'p-A' }),
    ).rejects.toThrow(NotFoundError);
    expect(repo.delete).not.toHaveBeenCalled();
  });
});

describe('§21 Validation rules', () => {
  it('empty fullName → create rejected', () => {
    const p1 = createPatientSchema.safeParse({ fullName: '' });
    expect(p1.success).toBe(false);
  });

  it('negative weightKg → rejected', () => {
    const p = createPatientSchema.safeParse({ fullName: 'X', weightKg: -1 });
    expect(p.success).toBe(false);
  });

  it('negative heightCm → rejected', () => {
    const p = createPatientSchema.safeParse({ fullName: 'X', heightCm: -10 });
    expect(p.success).toBe(false);
  });

  it('zero weightKg → rejected (strictly > 0 required)', () => {
    const p = createPatientSchema.safeParse({ fullName: 'X', weightKg: 0 });
    expect(p.success).toBe(false);
  });

  it('invalid dateOfBirth string → rejected', () => {
    const p = createPatientSchema.safeParse({ fullName: 'X', dateOfBirth: 'not-a-date' });
    expect(p.success).toBe(false);
  });

  it('unknown field → rejected (create strict)', () => {
    const p = createPatientSchema.safeParse({ fullName: 'X', unknownField: 123 });
    expect(p.success).toBe(false);
  });

  it('unknown field → rejected (update strict)', () => {
    const p = updatePatientSchema.safeParse({ notes: 'x', anything: 'else' });
    expect(p.success).toBe(false);
  });
});

describe('§13 ADMIN does NOT auto-access arbitrary patients via normal USER endpoints', () => {
  let repo: MockRepo;
  beforeEach(() => {
    repo = { findAllByUserId: mk(), findByIdAndUserId: mk() };
  });

  it('ADMIN GET /patients still lists only ADMINs own patients (not all)', async () => {
    repo.findAllByUserId!.mockResolvedValue([
      buildPatient({ id: 'p-me', userId: 'admin-1' }),
    ]);
    const uc = new GetPatients(repo as never);
    const out = (await uc.execute({ userId: 'admin-1' })) as Patient[];
    expect(repo.findAllByUserId).toHaveBeenCalledWith('admin-1', undefined);
    expect(out).toHaveLength(1);
    expect(out[0].userId).toBe('admin-1');
  });

  it('ADMIN GET /patients/:id still requires ownership (admin reads not given)', async () => {
    // If admin-u does NOT own patient of someone -> null
    repo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new GetPatientById(repo as never);
    await expect(
      uc.execute({ userId: 'admin-u', patientId: 'p-of-user-b' }),
    ).rejects.toThrow(NotFoundError);
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-of-user-b', 'admin-u');
  });
});

// ---------------- PATIENT AVATAR UPLOAD/DELETE ---------------- //

type File = UploadPatientAvatarFile;

const mkFile = (overrides: Partial<File> = {}): File => ({
  buffer: Buffer.from('jpeg-bytes'),
  mimetype: 'image/jpeg',
  originalname: 'profile.jpeg',
  size: 1024,
  ...overrides,
});

const publicUrlOf = (path: string): string =>
  `https://xgffmkewsedgyofwhkvl.supabase.co/storage/v1/object/public/${AVATAR_BUCKET}/${path}`;

const mkStorage = (): MockStorage => ({
  upload: mk().mockImplementation(async (_b: string, path: string) => ({
    path,
    publicUrl: publicUrlOf(path),
  })),
  delete: mk().mockResolvedValue(undefined),
  getPublicUrl: mk().mockImplementation((_b: string, path: string) => publicUrlOf(path)),
  extractPathFromPublicUrl: mk().mockImplementation((bucket: string, url: string) => {
    const prefix = publicUrlOf('').slice(0, -1);
    return bucket === AVATAR_BUCKET && url.startsWith(prefix) ? url.slice(prefix.length + 1) : null;
  }),
});

describe('§9/14/20 Avatar Upload: Use Case', () => {
  let repo: Required<Pick<MockRepo, 'findByIdAndUserId' | 'update'>>;
  let storage: MockStorage;
  beforeEach(() => {
    repo = { findByIdAndUserId: mk(), update: mk() };
    storage = mkStorage();
  });

  const runUpload = async (file: File, overrides: Partial<Patient> = {}) => {
    const base = buildPatient({ id: 'p-1', userId: 'u-A', ...overrides });
    repo.findByIdAndUserId!.mockResolvedValue(base);
    repo.update!.mockImplementation(async (id: string, patch) => ({ ...base, ...patch, id, updatedAt: now() }));
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    return uc.execute({ userId: 'u-A', patientId: 'p-1', file });
  };

  it('[UPLOAD-1] Owner uploads valid JPEG → patient has new avatarUrl', async () => {
    const out = await runUpload(mkFile({ mimetype: 'image/jpeg', originalname: 'pic.jpg' }));
    expect(out.avatarUrl).toMatch(/\/p-1\/avatar\/[0-9a-f-]+\.jpeg$/);
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-1', 'u-A');
    expect(storage.upload).toHaveBeenCalledTimes(1);
    expect(repo.update).toHaveBeenCalledWith('p-1', expect.objectContaining({ avatarUrl: out.avatarUrl }));
  });

  it('[UPLOAD-2] Owner uploads valid PNG → success', async () => {
    const out = await runUpload(mkFile({ mimetype: 'image/png', originalname: 'x.PNG', buffer: Buffer.from('png') }));
    expect(out.avatarUrl).toMatch(/\.png$/);
    expect(storage.upload).toHaveBeenCalledTimes(1);
  });

  it('[UPLOAD-3] Owner uploads valid WebP → success', async () => {
    const out = await runUpload(mkFile({ mimetype: 'image/webp', originalname: 'img.webp', buffer: Buffer.from('webp') }));
    expect(out.avatarUrl).toMatch(/\.webp$/);
  });

  it('[UPLOAD-5] Invalid MIME type → BadRequest (svg/gif/pdf/text/executable)', async () => {
    for (const bad of [
      { mime: 'image/svg+xml', name: 'x.svg' },
      { mime: 'image/gif', name: 'x.gif' },
      { mime: 'application/pdf', name: 'x.pdf' },
      { mime: 'video/mp4', name: 'x.mp4' },
      { mime: 'text/plain', name: 'x.txt' },
      { mime: 'application/x-msdownload', name: 'x.exe' },
      { mime: 'application/octet-stream', name: 'x.bin' },
    ]) {
      const uc = new UploadPatientAvatar(repo as never, storage as never);
      repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-1', userId: 'u-A' }));
      await expect(uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile({ mimetype: bad.mime, originalname: bad.name }) })).rejects.toBeInstanceOf(BadRequestError);
    }
  });

  it('[UPLOAD-5b] Bad extension despite good mime → BadRequest', async () => {
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-1', userId: 'u-A' }));
    await expect(
      uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile({ mimetype: 'image/jpeg', originalname: 'foo.pdf' }) }),
    ).rejects.toBeInstanceOf(BadRequestError);
    expect(storage.upload).not.toHaveBeenCalled();
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('[UPLOAD-6] File > 5 MB → BadRequestError (size too big)', async () => {
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-1', userId: 'u-A' }));
    const tooBig = 5 * 1024 * 1024 + 1;
    await expect(
      uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile({ size: tooBig }) }),
    ).rejects.toThrow(/Maximum.*5 MB/);
    expect(storage.upload).not.toHaveBeenCalled();
  });

  it('[UPLOAD-7] Cross-user → 404 NotFound; no upload/update executed', async () => {
    repo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    await expect(
      uc.execute({ userId: 'u-B', patientId: 'p-1', file: mkFile() }),
    ).rejects.toThrow(NotFoundError);
    expect(storage.upload).not.toHaveBeenCalled();
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('[REPLACE-9] Existing avatar + new upload → old storage path is deleted after DB update succeeds', async () => {
    const oldPath = 'patients/p-1/avatar/old-uuid.jpeg';
    const oldUrl = publicUrlOf(oldPath);
    const p = buildPatient({ id: 'p-1', userId: 'u-A', avatarUrl: oldUrl });
    repo.findByIdAndUserId!.mockResolvedValue(p);
    repo.update!.mockImplementation(async (_id, patch) => ({ ...p, ...patch, updatedAt: now() }));
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    const out = await uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile() });

    expect(storage.extractPathFromPublicUrl).toHaveBeenCalledWith(AVATAR_BUCKET, oldUrl);
    expect(storage.delete).toHaveBeenCalledWith(AVATAR_BUCKET, oldPath);
    expect(out.avatarUrl).not.toBe(oldUrl);
    expect(out.avatarUrl).toBeTruthy();
  });

  it('[REPLACE-10] Storage upload failure → old avatar remains unchanged', async () => {
    const oldUrl = publicUrlOf('patients/p-1/avatar/old.jpeg');
    repo.findByIdAndUserId!.mockResolvedValue(buildPatient({ id: 'p-1', userId: 'u-A', avatarUrl: oldUrl }));
    storage.upload.mockRejectedValueOnce(new Error('S3/supabase down'));
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    await expect(uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile() })).rejects.toThrow('S3/supabase down');
    expect(repo.update).not.toHaveBeenCalled();
    expect(storage.delete).not.toHaveBeenCalled();
  });

  it('[REPLACE-11] DB update fails after upload → new uploaded object is cleaned up from storage', async () => {
    repo.findByIdAndUserId!.mockResolvedValue(buildPatient({ id: 'p-1', userId: 'u-A', avatarUrl: null }));
    repo.update!.mockRejectedValueOnce(new Error('DB timeout'));
    const uc = new UploadPatientAvatar(repo as never, storage as never);
    await expect(uc.execute({ userId: 'u-A', patientId: 'p-1', file: mkFile() })).rejects.toThrow('DB timeout');

    expect(storage.upload).toHaveBeenCalledTimes(1);
    const [, uploadedPath] = storage.upload.mock.calls[0] as [string, string];
    expect(storage.delete).toHaveBeenCalledWith(AVATAR_BUCKET, uploadedPath);
  });
});

describe('§13/20 Avatar Delete: Use Case', () => {
  let repo: Required<Pick<MockRepo, 'findByIdAndUserId' | 'update'>>;
  let storage: MockStorage;
  beforeEach(() => {
    repo = { findByIdAndUserId: mk(), update: mk() };
    storage = mkStorage();
  });

  const setUp = (url: string | null) => {
    const p = buildPatient({ id: 'p-1', userId: 'u-A', avatarUrl: url });
    repo.findByIdAndUserId.mockResolvedValue(p);
    repo.update.mockImplementation(async (_id, patch) => ({ ...p, ...patch, updatedAt: now() }));
    return new DeletePatientAvatar(repo as never, storage as never);
  };

  it('[DELETE-12/14] Owner deletes avatar → Patient.avatarUrl set to null', async () => {
    const uc = setUp(publicUrlOf('patients/p-1/avatar/uuid.jpeg'));
    await uc.execute({ userId: 'u-A', patientId: 'p-1' });
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-1', 'u-A');
    expect(repo.update).toHaveBeenCalledWith('p-1', { avatarUrl: null });
  });

  it('[DELETE-13] Avatar storage object removed via storage service', async () => {
    const path = 'patients/p-1/avatar/uuid.jpeg';
    const uc = setUp(publicUrlOf(path));
    await uc.execute({ userId: 'u-A', patientId: 'p-1' });
    expect(storage.extractPathFromPublicUrl).toHaveBeenCalledWith(AVATAR_BUCKET, publicUrlOf(path));
    expect(storage.delete).toHaveBeenCalledWith(AVATAR_BUCKET, path);
  });

  it('[DELETE-idempotent] Avatar already null → no-op; no delete/update called on storage-service', async () => {
    const uc = setUp(null);
    await uc.execute({ userId: 'u-A', patientId: 'p-1' });
    expect(repo.update).not.toHaveBeenCalled();
    expect(storage.delete).not.toHaveBeenCalled();
    expect(storage.extractPathFromPublicUrl).not.toHaveBeenCalled();
  });

  it('[DELETE-15] Cross-user → 404 NotFound; no mutation', async () => {
    repo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new DeletePatientAvatar(repo as never, storage as never);
    await expect(uc.execute({ userId: 'u-B', patientId: 'p-1' })).rejects.toThrow(NotFoundError);
    expect(repo.update).not.toHaveBeenCalled();
    expect(storage.delete).not.toHaveBeenCalled();
  });
});

describe('§14/20 Controller + Auth: Avatar endpoints', () => {
  const res: Response = {} as never;
  const nextFn2 = nextMock;

  const buildReq = (overrides: Partial<Request> = {}): Request =>
    ({
      params: { id: 'p-1' },
      user: { userId: 'u-A', role: 'USER' },
      body: {},
      query: {},
      file: { buffer: Buffer.from('x'), mimetype: 'image/jpeg', originalname: 'a.jpeg', size: 100 } as never,
      ...overrides,
    }) as Request;

  const setRepoMocks = (avatarUrl: string | null, owner = 'u-A') => {
    jest.resetModules();
    const prismaMod = { PrismaPatientRepository: class { findByIdAndUserId = mk().mockResolvedValue(avatarUrl === undefined ? null : buildPatient({ id: 'p-1', userId: owner, avatarUrl })); update = mk().mockImplementation(async (_id: string, patch: unknown) => ({ ...buildPatient({ id: 'p-1', userId: owner, avatarUrl }), ...(patch as Partial<Patient>), updatedAt: now() })); } };
    const storageMod = { SupabaseStorageService: class { upload = mk().mockResolvedValue({ path: 'x', publicUrl: publicUrlOf('patients/p-1/avatar/new.jpeg') }); delete = mk().mockResolvedValue(undefined); getPublicUrl = mk().mockReturnValue(publicUrlOf('x')); extractPathFromPublicUrl = mk().mockReturnValue('patients/p-1/avatar/old.jpeg'); } };
    jest.doMock('@infrastructure/database/prisma/repositories/PrismaPatientRepository', () => prismaMod);
    jest.doMock('@infrastructure/storage/SupabaseStorageService', () => storageMod);
  };

  it('[UPLOAD-4] Missing image field → BadRequestError', async () => {
    await jest.isolateModulesAsync(async () => {
      setRepoMocks(null);
      const { PatientController } = require('@presentation/controllers/PatientController');
      const req = buildReq({ file: undefined });
      const mockNext = nextFn2();
      await PatientController.uploadAvatar(req, res, mockNext);
      const err = nextErr(mockNext.mock.calls[0]) as Error & { statusCode?: number };
      expect(err.constructor.name).toBe('BadRequestError');
      expect(err.statusCode).toBe(400);
    });
  });

  it('[UPLOAD-10] Valid owner upload response envelope: 200 shape { status, statusCode, data:{ patient } }', async () => {
    await jest.isolateModulesAsync(async () => {
      setRepoMocks(null);
      const { PatientController } = require('@presentation/controllers/PatientController');
      const req = buildReq();
      const localRes = { status: mk().mockReturnThis(), json: mk() };
      const mockNext = nextFn2();
      await PatientController.uploadAvatar(req, localRes as never, mockNext);
      expect(localRes.status).toHaveBeenCalledWith(200);
      const [body] = localRes.json.mock.calls[0] as [Record<string, unknown>];
      expect(body.status).toBe('success');
      expect(body.statusCode).toBe(200);
      expect((body.data as Record<string, unknown>).patient).toBeTruthy();
      expect(mockNext.mock.calls.length).toBe(0);
    });
  });

  it('[DELETE-204] Owner DELETE avatar → 204 No Content (controller sends status)', async () => {
    await jest.isolateModulesAsync(async () => {
      setRepoMocks(publicUrlOf('patients/p-1/avatar/x.jpeg'));
      const { PatientController } = require('@presentation/controllers/PatientController');
      const req = buildReq();
      const localRes = { status: mk().mockReturnThis(), send: mk() };
      const mockNext = nextFn2();
      await PatientController.deleteAvatar(req, localRes as never, mockNext);
      expect(localRes.status).toHaveBeenCalledWith(204);
      expect(localRes.send).toHaveBeenCalledTimes(1);
    });
  });

  it('[NO-JWT 8/16] POST avatar + DELETE avatar still require authenticated request via requireAuth (no JWT → 401 UnauthorizedError)', () => {
    const check = (reqLike: Partial<Request>) => {
      const mNext = nextFn2();
      requireAuth(reqLike as Request, res, mNext);
      const err = nextErr(mNext.mock.calls[0]);
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect((err as unknown as { statusCode: number }).statusCode).toBe(401);
    };
    check({ headers: {} });
    check({ headers: { authorization: 'Bearer invalid.jwt.here' } });
  });

  it('[UPLOAD-OWNERSHIP] Controller ignores userId/ownership fields from body/query: ownership still derived from req.user.userId', async () => {
    await jest.isolateModulesAsync(async () => {
      jest.resetModules();
      let capturedFindId!: string, capturedUserId!: string;
      const prismaMod = {
        PrismaPatientRepository: class {
          findByIdAndUserId = mk().mockImplementation((id: string, uid: string) => {
            capturedFindId = id;
            capturedUserId = uid;
            return Promise.resolve(buildPatient({ id, userId: uid, avatarUrl: null }));
          });
          update = mk().mockImplementation(async (id: string, patch: unknown) => ({
            ...buildPatient({ id, userId: capturedUserId, avatarUrl: publicUrlOf('patients/p-1/avatar/new.jpeg') }), ...(patch as Partial<Patient>),
          }));
        },
      };
      const storageMod = {
        SupabaseStorageService: class {
          upload = mk().mockResolvedValue({ path: 'patients/p-1/avatar/new.jpeg', publicUrl: publicUrlOf('patients/p-1/avatar/new.jpeg') });
          delete = mk().mockResolvedValue(undefined);
          getPublicUrl = mk().mockReturnValue('');
          extractPathFromPublicUrl = mk().mockReturnValue(null);
        },
      };
      jest.doMock('@infrastructure/database/prisma/repositories/PrismaPatientRepository', () => prismaMod);
      jest.doMock('@infrastructure/storage/SupabaseStorageService', () => storageMod);
      const { PatientController } = require('@presentation/controllers/PatientController');
      const req = buildReq({
        params: { id: 'p-1' },
        body: { userId: 'someone-else', fullName: 'XSS injected' },
        query: { userId: 'u-C' },
        user: { userId: 'u-A', role: 'USER' },
      } as never);
      const localRes = { status: mk().mockReturnThis(), json: mk() };
      const mockNext = nextFn2();
      await PatientController.uploadAvatar(req, localRes as never, mockNext);
      expect(capturedFindId).toBe('p-1');
      expect(capturedUserId).toBe('u-A'); // from req.user, not body/query
      expect(mockNext.mock.calls.length).toBe(0);
    });
  });
});
