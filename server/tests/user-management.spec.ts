import bcrypt from 'bcrypt';
import { hash as bcryptHash } from 'bcrypt';
import type { User } from '@domain/entities/User';
import { RegisterUser } from '@application/use-cases/auth/RegisterUser';
import { LoginUser } from '@application/use-cases/auth/LoginUser';
import { GetMyProfile } from '@application/use-cases/users/GetMyProfile';
import { UpdateMyProfile } from '@application/use-cases/users/UpdateMyProfile';
import { ChangePassword } from '@application/use-cases/users/ChangePassword';
import { GetUsers } from '@application/use-cases/users/GetUsers';
import { GetUserById } from '@application/use-cases/users/GetUserById';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import { registerSchema } from '@presentation/validators/auth.validator';
import {
  updateMyProfileSchema,
  changePasswordSchema,
} from '@presentation/validators/user.validator';
import {
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  BadRequestError,
  NotFoundError,
} from '@shared/errors';
import type { Request, Response, NextFunction } from 'express';
import { PasswordService } from '@infrastructure/auth/PasswordService';
import { JwtService } from '@infrastructure/auth/JwtService';

type MockRepo = {
  findById?: jest.Mock;
  findByEmail?: jest.Mock;
  existsByEmail?: jest.Mock;
  findAll?: jest.Mock;
  create?: jest.Mock;
  update?: jest.Mock;
  updatePassword?: jest.Mock;
};

const mk = jest.fn;
const nextErr = (calls: unknown[]): Error => calls[0] as unknown as Error;
const nextMock = () => jest.fn() as unknown as jest.Mock & NextFunction;

const now = () => new Date('2025-01-01T00:00:00.000Z');

const buildUser = (overrides: Partial<User> = {}): User => ({
  id: 'u-1',
  firstName: 'John',
  lastName: 'Doe',
  email: 'john@example.com',
  passwordHash: '$2b$12$hashhashhashhashhashhashhashhashhashhashhashh',
  phone: null,
  role: 'USER',
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

interface JwtSigner {
  sign(params: { userId: string; role: 'USER' | 'ADMIN' }): string;
}

describe('§22 Registration role protection', () => {
  let userRepo: MockRepo;
  let passwordSvc: PasswordService;
  let jwtSvc: JwtSigner;

  beforeEach(() => {
    userRepo = {
      findByEmail: mk(),
      existsByEmail: mk(),
      create: mk(),
    };
    passwordSvc = new PasswordService(4);
    jwtSvc = { sign: mk().mockReturnValue('jwt-x') };
  });

  it('normal register → role defaults USER (passwordHash not returned)', async () => {
    userRepo.existsByEmail!.mockResolvedValue(false);
    userRepo.findByEmail!.mockResolvedValue(null);
    userRepo.create!.mockImplementation(async (data: Parameters<typeof bcryptHash> | never) => {
      const d = data as unknown as User;
      return buildUser({
        id: 'u-new',
        email: d.email,
        passwordHash: await passwordSvc.hash('NewPass123!'),
        firstName: d.firstName ?? null,
        lastName: d.lastName ?? null,
        role: 'USER',
      });
    });

    const uc = new RegisterUser(userRepo as never, passwordSvc, jwtSvc);
    const out = await uc.execute({
      email: 'new@example.com',
      password: 'NewPass123!',
    });

    expect(out.user.role).toBe('USER');
    expect((out.user as Record<string, unknown>).passwordHash).toBeUndefined();
    const [data] = userRepo.create!.mock.calls[0] as [Record<string, unknown>];
    expect(data.role).toBeUndefined();
  });

  it('register validator → strict: role ADMIN in body REJECTED (BadRequest)', () => {
    const parse = registerSchema.safeParse({
      email: 'a@b.com',
      password: 'Password1!',
      role: 'ADMIN',
    });
    expect(parse.success).toBe(false);
  });

  it('register validator → unknown key stripped/rejected → success without role', () => {
    const parse = registerSchema.safeParse({ email: 'a@b.com', password: 'Password1!' });
    expect(parse.success).toBe(true);
  });
});

describe('§22 Login → JWT contains correct ADMIN/USER role', () => {
  let userRepo: MockRepo;
  let passwordSvc: PasswordService;
  let signMock: jest.Mock;

  beforeEach(() => {
    userRepo = { findByEmail: mk(), findById: mk() };
    passwordSvc = new PasswordService(4);
    signMock = mk();
  });

  it('USER login → JWT sign with role=USER', async () => {
    const pw = 'correct1!';
    const hash = await passwordSvc.hash(pw);
    userRepo.findByEmail!.mockResolvedValue(buildUser({ role: 'USER', passwordHash: hash }));
    const uc = new LoginUser(userRepo as never, passwordSvc, { sign: signMock } as never);
    signMock.mockReturnValue('tok');
    await uc.execute({ email: 'john@example.com', password: pw });
    expect(signMock).toHaveBeenCalledWith({ userId: 'u-1', role: 'USER' });
  });

  it('ADMIN login → JWT sign with role=ADMIN', async () => {
    const pw = 'correct1!';
    const hash = await passwordSvc.hash(pw);
    userRepo.findByEmail!.mockResolvedValue(buildUser({ role: 'ADMIN', passwordHash: hash }));
    const uc = new LoginUser(userRepo as never, passwordSvc, { sign: signMock } as never);
    signMock.mockReturnValue('tok');
    await uc.execute({ email: 'admin@example.com', password: pw });
    expect(signMock).toHaveBeenCalledWith({ userId: 'u-1', role: 'ADMIN' });
  });
});

describe('§22 Own profile (GetMyProfile / UpdateMyProfile)', () => {
  let userRepo: MockRepo;

  beforeEach(() => {
    userRepo = { findById: mk(), findByEmail: mk(), update: mk() };
  });

  it('USER → GET /me → 200 (no passwordHash)', async () => {
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-a', role: 'USER' }));
    const uc = new GetMyProfile(userRepo as never);
    const out = await uc.execute({ userId: 'u-a' });
    expect(out.role).toBe('USER');
    expect((out as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('ADMIN → GET /me → 200 role=ADMIN (no passwordHash)', async () => {
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-admin', role: 'ADMIN' }));
    const uc = new GetMyProfile(userRepo as never);
    const out = await uc.execute({ userId: 'u-admin' });
    expect(out.role).toBe('ADMIN');
    expect((out as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('Update profile only writes whitelisted fields (firstName/lastName/phone/email)', async () => {
    const existing = buildUser({ id: 'u-1' });
    userRepo.findById!.mockResolvedValue(existing);
    userRepo.update!.mockResolvedValue({
      ...existing,
      firstName: 'Moatez',
      lastName: 'Borji',
      phone: '+216',
    });
    const uc = new UpdateMyProfile(userRepo as never);
    await uc.execute({ userId: 'u-1', firstName: 'Moatez', lastName: 'Borji', phone: '+216' });

    const [, patch] = userRepo.update!.mock.calls[0] as [string, Record<string, unknown>];
    expect(patch.role).toBeUndefined();
    expect(patch.passwordHash).toBeUndefined();
    expect(patch.firstName).toBe('Moatez');
    expect(patch.lastName).toBe('Borji');
    expect(patch.phone).toBe('+216');
  });

  it('User sends role=ADMIN in update body → validator strict REJECTS', () => {
    const p = updateMyProfileSchema.safeParse({ firstName: 'M', role: 'ADMIN' });
    expect(p.success).toBe(false);
  });

  it('User sends passwordHash in update body → validator strict REJECTS', () => {
    const p = updateMyProfileSchema.safeParse({ firstName: 'M', passwordHash: 'leak' });
    expect(p.success).toBe(false);
  });

  it('UpdateMyProfile → email changed to a taken address → ConflictError 409', async () => {
    userRepo.findById!.mockResolvedValue(
      buildUser({ id: 'u-1', email: 'me@example.com' }),
    );
    userRepo.findByEmail!.mockResolvedValue(buildUser({ id: 'u-2', email: 'taken@example.com' }));
    const uc = new UpdateMyProfile(userRepo as never);
    await expect(
      uc.execute({ userId: 'u-1', email: 'taken@example.com' }),
    ).rejects.toThrow(ConflictError);
    expect(userRepo.update).not.toHaveBeenCalled();
  });

  it('UpdateMyProfile → same email (no change) → ok without uniqueness check', async () => {
    const existing = buildUser({ id: 'u-1', email: 'same@example.com' });
    userRepo.findById!.mockResolvedValue(existing);
    userRepo.update!.mockResolvedValue({ ...existing, firstName: 'Mo' });
    const uc = new UpdateMyProfile(userRepo as never);
    const out = await uc.execute({ userId: 'u-1', email: 'same@example.com', firstName: 'Mo' });
    expect(out.firstName).toBe('Mo');
    expect(userRepo.findByEmail).not.toHaveBeenCalled();
  });
});

describe('§22 ChangePassword', () => {
  let userRepo: MockRepo;
  let passwordSvc: PasswordService;

  beforeEach(() => {
    userRepo = { findById: mk(), updatePassword: mk() };
    passwordSvc = new PasswordService(4);
  });

  it('Correct current password → success + new password hashed', async () => {
    const current = 'Current123!';
    const next = 'NewerPass9!';
    const currentHash = await passwordSvc.hash(current);
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-1', passwordHash: currentHash }));

    const hashSpy = jest.spyOn(passwordSvc, 'hash');
    userRepo.updatePassword!.mockResolvedValue(buildUser({ id: 'u-1', passwordHash: 'x' }));
    const uc = new ChangePassword(userRepo as never, passwordSvc);
    const out = await uc.execute({
      userId: 'u-1',
      currentPassword: current,
      newPassword: next,
    });
    expect(out.success).toBe(true);
    expect(hashSpy).toHaveBeenCalledWith(next);
    expect(userRepo.updatePassword).toHaveBeenCalledTimes(1);
    const [, pwHashArg] = userRepo.updatePassword!.mock.calls[0] as [string, string];
    expect(pwHashArg).not.toBe(next);
    hashSpy.mockRestore();
  });

  it('Wrong current password → 401 UnauthorizedError', async () => {
    const current = 'Current123!';
    const currentHash = await passwordSvc.hash(current);
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-1', passwordHash: currentHash }));

    const uc = new ChangePassword(userRepo as never, passwordSvc);
    await expect(
      uc.execute({ userId: 'u-1', currentPassword: 'WRONG', newPassword: 'NewPass1!' }),
    ).rejects.toThrow(UnauthorizedError);
    expect(userRepo.updatePassword).not.toHaveBeenCalled();
  });

  it('Plain password never returned in response', async () => {
    const currentHash = await passwordSvc.hash('Current123!');
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-1', passwordHash: currentHash }));
    userRepo.updatePassword!.mockResolvedValue(buildUser({ id: 'u-1' }));
    const uc = new ChangePassword(userRepo as never, passwordSvc);
    const out = await uc.execute({
      userId: 'u-1',
      currentPassword: 'Current123!',
      newPassword: 'NewPass1!',
    });
    expect(JSON.stringify(out)).not.toContain('Current123');
    expect(JSON.stringify(out)).not.toContain('NewPass1');
  });

  it('New password < 8 chars → BadRequestError', async () => {
    const currentHash = await passwordSvc.hash('Current123!');
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-1', passwordHash: currentHash }));
    const uc = new ChangePassword(userRepo as never, passwordSvc);
    await expect(
      uc.execute({ userId: 'u-1', currentPassword: 'Current123!', newPassword: 'short' }),
    ).rejects.toThrow(BadRequestError);
  });

  it('changePassword schema rejects extra fields', () => {
    const p = changePasswordSchema.safeParse({
      currentPassword: 'a',
      newPassword: 'bbbbbbbb',
      role: 'ADMIN',
    });
    expect(p.success).toBe(false);
  });
});

describe('§22 Admin endpoints (role-based access control)', () => {
  let userRepo: MockRepo;

  beforeEach(() => {
    userRepo = { findById: mk(), findAll: mk() };
  });

  it('ADMIN → GET /users → 200 list (all users stripped passwordHash)', async () => {
    userRepo.findAll!.mockResolvedValue([
      buildUser({ id: 'u-1', role: 'USER' }),
      buildUser({ id: 'u-2', role: 'ADMIN' }),
    ]);
    const uc = new GetUsers(userRepo as never);
    const list = await uc.execute();
    expect(list).toHaveLength(2);
    for (const u of list) {
      expect((u as Record<string, unknown>).passwordHash).toBeUndefined();
      expect(['USER', 'ADMIN']).toContain(u.role);
    }
  });

  it('ADMIN → GET /users/:id → 200 stripped passwordHash', async () => {
    userRepo.findById!.mockResolvedValue(buildUser({ id: 'u-tar' }));
    const uc = new GetUserById(userRepo as never);
    const out = await uc.execute({ id: 'u-tar' });
    expect(out.id).toBe('u-tar');
    expect((out as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('ADMIN → GET unknown /users/:id → NotFoundError', async () => {
    userRepo.findById!.mockResolvedValue(null);
    const uc = new GetUserById(userRepo as never);
    await expect(uc.execute({ id: 'does-not-exist' })).rejects.toThrow(NotFoundError);
  });

  const mockRes = {} as Response;

  it('USER → GET /users → requireRole(ADMIN) → 403 Forbidden', () => {
    const req = { user: { userId: 'u-1', role: 'USER' as const } } as Request;
    const mockNext = nextMock();
    requireRole('ADMIN')(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(ForbiddenError);
    expect((err as unknown as { statusCode: number }).statusCode).toBe(403);
  });

  it('USER → GET /users/:id → requireRole(ADMIN) → 403 Forbidden', () => {
    const req = { user: { userId: 'u-1', role: 'USER' as const } } as Request;
    const mockNext = nextMock();
    requireRole('ADMIN')(req, mockRes, mockNext);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(ForbiddenError);
  });
});

describe('§22 Security: endpoints without JWT → 401', () => {
  const mockRes = {} as Response;

  it('GET /users/me without JWT → 401 requireAuth', () => {
    const req = { headers: {} } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
    expect((err as unknown as { statusCode: number }).statusCode).toBe(401);
  });

  it('PATCH /users/me without JWT → 401 requireAuth', () => {
    const req = { headers: {} } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('PATCH /users/me/password without JWT → 401 requireAuth', () => {
    const req = { headers: {} } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('requireAuth + valid Bearer JWT → passes, role in req.user', () => {
    const original = process.env.JWT_SECRET;
    process.env.JWT_SECRET = 'test-secret-change-me';
    const svc = new JwtService('test-secret-change-me', '1h');
    const token = svc.sign({ userId: 'u-1', role: 'USER' });
    const req = { headers: { authorization: `Bearer ${token}` } } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledWith();
    expect(req.user).toEqual({ userId: 'u-1', role: 'USER' });
    process.env.JWT_SECRET = original;
  });
});

describe('§22 System admin bootstrap (idempotent)', () => {
  const original = {
    email: process.env.SYSTEM_ADMIN_EMAIL,
    password: process.env.SYSTEM_ADMIN_PASSWORD,
  };

  beforeEach(() => {
    process.env.SYSTEM_ADMIN_EMAIL = 'superborgi@med.com';
    process.env.SYSTEM_ADMIN_PASSWORD = 'SecurePassword123!';
  });

  afterEach(() => {
    process.env.SYSTEM_ADMIN_EMAIL = original.email;
    process.env.SYSTEM_ADMIN_PASSWORD = original.password;
  });

  const runBootstrap = async (
    state: { users: User[] },
  ): Promise<{ created: boolean; upgraded: boolean; users: User[]; finalRole: string; pwHash: string }> => {
    const email = process.env.SYSTEM_ADMIN_EMAIL!;
    const password = process.env.SYSTEM_ADMIN_PASSWORD!;
    const existing = state.users.find((u) => u.email === email);
    let created = false;
    let upgraded = false;
    if (!existing) {
      const hash = bcrypt.hashSync(password, 4);
      state.users.push(
        buildUser({
          id: `u-${Date.now()}`,
          email,
          passwordHash: hash,
          role: 'ADMIN',
          firstName: null,
          lastName: null,
          phone: null,
        }),
      );
      created = true;
    } else if (existing.role !== 'ADMIN') {
      existing.role = 'ADMIN';
      upgraded = true;
    }
    const finalUser = state.users.find((u) => u.email === email)!;
    return {
      created,
      upgraded,
      users: state.users,
      finalRole: finalUser.role,
      pwHash: finalUser.passwordHash,
    };
  };

  it('Run bootstrap first time → exactly one system admin', async () => {
    const state: { users: User[] } = { users: [] };
    const res = await runBootstrap(state);
    expect(res.created).toBe(true);
    expect(state.users.filter((u) => u.email === 'superborgi@med.com')).toHaveLength(1);
    expect(res.finalRole).toBe('ADMIN');
  });

  it('Run bootstrap second time → still exactly one system admin (idempotent)', async () => {
    const state: { users: User[] } = { users: [] };
    const first = await runBootstrap(state);
    expect(first.created).toBe(true);
    const second = await runBootstrap(state);
    expect(second.created).toBe(false);
    expect(second.upgraded).toBe(false);
    expect(state.users.filter((u) => u.email === 'superborgi@med.com')).toHaveLength(1);
  });

  it('System admin role = ADMIN, password stored as bcrypt hash (not plaintext)', async () => {
    const state: { users: User[] } = { users: [] };
    await runBootstrap(state);
    const u = state.users[0];
    expect(u.role).toBe('ADMIN');
    expect(u.passwordHash).not.toBe(process.env.SYSTEM_ADMIN_PASSWORD);
    expect(await bcrypt.compare(process.env.SYSTEM_ADMIN_PASSWORD!, u.passwordHash)).toBe(true);
    expect(u.passwordHash.startsWith('$2b$')).toBe(true);
  });

  it('Existing user with same email (USER role) → upgrade to ADMIN, preserve password', async () => {
    const existingHash = bcrypt.hashSync('oldExistingPassword', 4);
    const state: { users: User[] } = {
      users: [
        buildUser({
          id: 'u-preexisting',
          email: 'superborgi@med.com',
          passwordHash: existingHash,
          role: 'USER',
        }),
      ],
    };
    const res = await runBootstrap(state);
    expect(res.created).toBe(false);
    expect(res.upgraded).toBe(true);
    const u = state.users.find((x) => x.email === 'superborgi@med.com')!;
    expect(u.role).toBe('ADMIN');
    expect(u.passwordHash).toBe(existingHash);
    expect(await bcrypt.compare('oldExistingPassword', u.passwordHash)).toBe(true);
  });
});
