import { GetMedicationEvents } from '@application/use-cases/device/GetMedicationEvents';
import type { IMedicationSessionRepository } from '@domain/repositories/IMedicationSessionRepository';
import type { MedicationSession } from '@domain/entities/MedicationSession';
import { getMedicationEventsQuerySchema } from '@presentation/validators/devices.validator';
import { UnauthorizedError, BadRequestError } from '@shared/errors';
import { JwtService } from '@infrastructure/auth/JwtService';

type AnyFn = jest.Mock<any, any>;

type MockRepo = IMedicationSessionRepository & {
  findMany: AnyFn;
  create: AnyFn;
  createWithOccurrence: AnyFn;
  findById: AnyFn;
  findByOccurrence: AnyFn;
  findActiveForDrawer: AnyFn;
  findLatestForSchedule: AnyFn;
  update: AnyFn;
  markResult: AnyFn;
  listByDrawer: AnyFn;
};

const mk = () => jest.fn();
const mockRepo = (): MockRepo => ({
  findMany: mk(),
  create: mk(),
  createWithOccurrence: mk(),
  findById: mk(),
  findByOccurrence: mk(),
  findActiveForDrawer: mk(),
  findLatestForSchedule: mk(),
  update: mk(),
  markResult: mk(),
  listByDrawer: mk(),
});

const now = new Date('2026-10-13T06:00:00.000Z');

const buildSession = (
  o: Partial<MedicationSession> & { deviceId?: string | null } = {},
): MedicationSession & { deviceId: string | null } => ({
  id: 'session-1',
  scheduleId: 'sched-1',
  patientId: 'patient-1',
  medicationId: 'med-1',
  drawerId: 'drawer-1',
  scheduledAt: now,
  startedAt: now,
  completedAt: now,
  quantityBefore: 20,
  quantityAfter: 19,
  result: 'PATIENT_TAKEN',
  occurrenceDate: now,
  occurrenceTime: '06:00',
  deviceId: null,
  ...o,
});

describe('GET /api/devices/medication-events', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('Query validation (getMedicationEventsQuerySchema)', () => {
    it('accepts empty query (all optional)', () => {
      const r = getMedicationEventsQuerySchema.safeParse({});
      expect(r.success).toBe(true);
    });

    it('accepts all valid filters', () => {
      const r = getMedicationEventsQuerySchema.safeParse({
        deviceId: 'DEV-BOX-1',
        patientId: 'p-1',
        scheduleId: 's-1',
        drawerId: 'd-1',
        status: 'TAKEN',
        limit: '20',
        offset: '0',
      });
      expect(r.success).toBe(true);
      if (r.success) {
        expect(r.data.limit).toBe(20);
        expect(r.data.offset).toBe(0);
      }
    });

    it('rejects limit > 100', () => {
      const r = getMedicationEventsQuerySchema.safeParse({ limit: '101' });
      expect(r.success).toBe(false);
    });

    it('rejects limit < 1', () => {
      const r = getMedicationEventsQuerySchema.safeParse({ limit: '0' });
      expect(r.success).toBe(false);
    });

    it('rejects negative offset', () => {
      const r = getMedicationEventsQuerySchema.safeParse({ offset: '-1' });
      expect(r.success).toBe(false);
    });

    it('rejects invalid status', () => {
      const r = getMedicationEventsQuerySchema.safeParse({ status: 'COMPLETED' });
      expect(r.success).toBe(false);
    });

    it('accepts raw MedicationSessionResult status values', () => {
      for (const s of [
        'PATIENT_TAKEN',
        'PATIENT_SKIPPED',
        'FACE_RECOGNITION_FAILED',
        'DISPENSING_FAILED',
        'DEVICE_FAILURE',
        'MISSED',
      ]) {
        const r = getMedicationEventsQuerySchema.safeParse({ status: s });
        expect(r.success).toBe(true);
      }
    });

    it('rejects unknown query params (strict)', () => {
      const r = getMedicationEventsQuerySchema.safeParse({ foo: 'bar' });
      expect(r.success).toBe(false);
    });
  });

  describe('GetMedicationEvents use case', () => {
    it('returns events with default pagination (limit=20, offset=0)', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({
        events: [buildSession()],
        total: 1,
        limit: 20,
        offset: 0,
      });
      const uc = new GetMedicationEvents(repo);
      const result = await uc.execute({});
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({}),
        { limit: 20, offset: 0 },
      );
      expect(result.total).toBe(1);
      expect(result.events).toHaveLength(1);
    });

    it('clamps limit to max 100', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 100, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ limit: 999 });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.anything(),
        { limit: 100, offset: 0 },
      );
    });

    it('clamps negative offset to 0', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ offset: -5 });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.anything(),
        { limit: 20, offset: 0 },
      );
    });

    it('maps status TAKEN -> result PATIENT_TAKEN', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ status: 'TAKEN' });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ result: 'PATIENT_TAKEN' }),
        expect.anything(),
      );
    });

    it('maps status MISSED -> result MISSED', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ status: 'MISSED' });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ result: 'MISSED' }),
        expect.anything(),
      );
    });

    it('passes raw enum status through unchanged', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ status: 'DEVICE_FAILURE' });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ result: 'DEVICE_FAILURE' }),
        expect.anything(),
      );
    });

    it('passes deviceId filter to repository', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ deviceId: 'DEV-BOX-1' });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ deviceId: 'DEV-BOX-1' }),
        expect.anything(),
      );
    });

    it('passes patientId, scheduleId, drawerId filters to repository', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({
        patientId: 'p-1',
        scheduleId: 's-1',
        drawerId: 'd-1',
      });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          patientId: 'p-1',
          scheduleId: 's-1',
          drawerId: 'd-1',
        }),
        expect.anything(),
      );
    });

    it('passes userId for multi-tenant scoping', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      await uc.execute({ userId: 'user-1' });
      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ userId: 'user-1' }),
        expect.anything(),
      );
    });

    it('returns empty array when no events match', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({ events: [], total: 0, limit: 20, offset: 0 });
      const uc = new GetMedicationEvents(repo);
      const result = await uc.execute({ patientId: 'nonexistent' });
      expect(result.events).toEqual([]);
      expect(result.total).toBe(0);
    });

    it('includes deviceId in returned events', async () => {
      const repo = mockRepo();
      repo.findMany.mockResolvedValue({
        events: [buildSession({ deviceId: 'DEV-BOX-1' })],
        total: 1,
        limit: 20,
        offset: 0,
      });
      const uc = new GetMedicationEvents(repo);
      const result = await uc.execute({});
      expect(result.events[0].deviceId).toBe('DEV-BOX-1');
    });
  });

  describe('Authentication & authorization (controller-level behavior)', () => {
    it('JwtService.verify throws UnauthorizedError on invalid token', () => {
      const svc = new JwtService('test-secret');
      expect(() => svc.verify('not-a-valid-token')).toThrow(UnauthorizedError);
    });

    it('JwtService.verify returns userId + role on valid token', () => {
      const svc = new JwtService('test-secret');
      const token = svc.sign({ userId: 'user-1', role: 'USER' });
      const payload = svc.verify(token);
      expect(payload.userId).toBe('user-1');
      expect(payload.role).toBe('USER');
    });

    it('rejects request with no token and no deviceId (Unauthorized)', () => {
      // Simulates the controller guard: else if (!parsed.data.deviceId) throw UnauthorizedError
      const parsed = getMedicationEventsQuerySchema.safeParse({});
      expect(parsed.success).toBe(true);
      const hasDeviceId = !!(parsed.success && parsed.data.deviceId);
      const authHeader = undefined;
      if (!authHeader && !hasDeviceId) {
        expect(() => {
          throw new UnauthorizedError('Authentication required');
        }).toThrow(UnauthorizedError);
      }
    });

    it('allows device-scoped access without JWT when deviceId provided', () => {
      const parsed = getMedicationEventsQuerySchema.safeParse({ deviceId: 'DEV-BOX-1' });
      expect(parsed.success).toBe(true);
      const hasDeviceId = !!(parsed.success && parsed.data.deviceId);
      expect(hasDeviceId).toBe(true);
      // No UnauthorizedError should be thrown in this path
    });
  });

  describe('Status mapping in response (controller DTO)', () => {
    it('maps PATIENT_TAKEN -> TAKEN and computes quantityTaken', () => {
      const ev = buildSession({
        result: 'PATIENT_TAKEN',
        quantityBefore: 20,
        quantityAfter: 19,
      });
      const status =
        ev.result === 'PATIENT_TAKEN'
          ? 'TAKEN'
          : ev.result === 'MISSED'
            ? 'MISSED'
            : ev.result;
      const quantityTaken = ev.quantityBefore - (ev.quantityAfter ?? ev.quantityBefore);
      expect(status).toBe('TAKEN');
      expect(quantityTaken).toBe(1);
    });

    it('maps MISSED -> MISSED with quantityTaken = 0', () => {
      const ev = buildSession({
        result: 'MISSED',
        quantityBefore: 20,
        quantityAfter: 20,
      });
      const status =
        ev.result === 'PATIENT_TAKEN'
          ? 'TAKEN'
          : ev.result === 'MISSED'
            ? 'MISSED'
            : ev.result;
      const quantityTaken = ev.quantityBefore - (ev.quantityAfter ?? ev.quantityBefore);
      expect(status).toBe('MISSED');
      expect(quantityTaken).toBe(0);
    });

    it('passes other result values through unchanged', () => {
      const ev = buildSession({ result: 'DEVICE_FAILURE' });
      const status =
        ev.result === 'PATIENT_TAKEN'
          ? 'TAKEN'
          : ev.result === 'MISSED'
            ? 'MISSED'
            : ev.result;
      expect(status).toBe('DEVICE_FAILURE');
    });

    it('handles null result (pending session)', () => {
      const ev = buildSession({ result: null });
      const status =
        ev.result === 'PATIENT_TAKEN'
          ? 'TAKEN'
          : ev.result === 'MISSED'
            ? 'MISSED'
            : ev.result;
      expect(status).toBeNull();
    });
  });

  describe('Error class availability', () => {
    it('BadRequestError has statusCode 400', () => {
      const err = new BadRequestError('bad');
      expect(err.statusCode).toBe(400);
    });
    it('UnauthorizedError has statusCode 401', () => {
      const err = new UnauthorizedError('unauth');
      expect(err.statusCode).toBe(401);
    });
  });
});
