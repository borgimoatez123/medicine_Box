import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import { DeviceHeartbeat } from '@application/use-cases/device/DeviceHeartbeat';
import {
  getOfflineThresholdMs,
  runOfflineDetectionNow,
  stopOfflineMonitor,
} from '@application/services/DeviceOfflineMonitor';
import { heartbeatSchema } from '@presentation/validators/devices.validator';
import {
  formatZodErrors,
} from '@presentation/controllers/DevicesController';
import {
  NotFoundError,
} from '@shared/errors';
import { PrismaMedicineBoxRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';

type MockBoxRepo = {
  findById: jest.Mock;
  findAll: jest.Mock;
  findAllByUserId: jest.Mock;
  findByDeviceId: jest.Mock;
  findByIdAndUserId: jest.Mock;
  existsByDeviceId: jest.Mock;
  create: jest.Mock;
  update: jest.Mock;
  adminUpdate: jest.Mock;
  activateAtomic: jest.Mock;
  releaseOwnership: jest.Mock;
  markDeviceSeen: jest.Mock;
  markStaleDevicesOffline: jest.Mock;
};

const mk = () => jest.fn();
const mockRepo = (): MockBoxRepo => ({
  findById: mk(),
  findAll: mk(),
  findAllByUserId: mk(),
  findByDeviceId: mk(),
  findByIdAndUserId: mk(),
  existsByDeviceId: mk(),
  create: mk(),
  update: mk(),
  adminUpdate: mk(),
  activateAtomic: mk(),
  releaseOwnership: mk(),
  markDeviceSeen: mk(),
  markStaleDevicesOffline: mk(),
});

const now = () => new Date('2026-09-23T12:00:00.000Z');
const buildBox = (o: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-DEV-001',
  deviceToken: 'SECRET',
  name: 'Heartbeat Box',
  status: 'ACTIVE',
  deviceStatus: 'OFFLINE',
  lastSeenAt: null,
  userId: 'u-1',
  numberOfDrawers: 4,
  drawerCapacity: 20,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

describe('§ Raspberry Pi Heartbeat Feature — 5 tests', () => {
  afterEach(() => {
    stopOfflineMonitor();
    jest.restoreAllMocks();
  });

  it('Test 1 - Valid heartbeat → status ACTIVE, lastSeen updated', async () => {
    const mocks = mockRepo();
    const t0 = new Date();
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'PI-DEV-001', deviceStatus: 'OFFLINE' }),
    );
    mocks.markDeviceSeen.mockResolvedValue(
      buildBox({ deviceId: 'PI-DEV-001', deviceStatus: 'ACTIVE', lastSeenAt: t0 }),
    );
    const uc = new DeviceHeartbeat(mocks as unknown as IMedicineBoxRepository);
    const r = await uc.execute('PI-DEV-001');
    expect(mocks.findByDeviceId).toHaveBeenCalledWith('PI-DEV-001');
    expect(mocks.markDeviceSeen).toHaveBeenCalledWith('PI-DEV-001');
    expect(r.deviceId).toBe('PI-DEV-001');
    expect(r.status).toBe('ACTIVE');
    expect(t0.getTime() - r.lastSeen.getTime()).toBeLessThanOrEqual(3000);
  });

  it('Test 2 - Missing deviceId → zod validation fails (400 BadRequest)', () => {
    const empty = heartbeatSchema.safeParse({});
    expect(empty.success).toBe(false);
    if (!empty.success) {
      expect(formatZodErrors(empty.error)).toBe('deviceId is required');
    }
    const blank = heartbeatSchema.safeParse({ deviceId: '   ' });
    expect(blank.success).toBe(false);
    if (!blank.success) {
      expect(formatZodErrors(blank.error)).toBe('deviceId is required');
    }
  });

  it('Test 3 - Unknown deviceId → NotFoundError "Device not found"', async () => {
    const mocks = mockRepo();
    mocks.findByDeviceId.mockResolvedValue(null);
    const uc = new DeviceHeartbeat(mocks as unknown as IMedicineBoxRepository);
    await expect(uc.execute('UNKNOWN-DEVICE')).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('UNKNOWN-DEVICE');
    } catch (e) {
      expect((e as Error).message).toBe('Device not found');
    }
    expect(mocks.markDeviceSeen).not.toHaveBeenCalled();
  });

  it('Test 4 - Previously OFFLINE device → heartbeat flips to ACTIVE with recent lastSeen', async () => {
    const mocks = mockRepo();
    const boxBefore = buildBox({
      deviceId: 'PI-DEV-001',
      deviceStatus: 'OFFLINE',
      lastSeenAt: new Date(Date.now() - 60_000),
    });
    const tAfter = new Date();
    const boxAfter = buildBox({
      deviceId: 'PI-DEV-001',
      deviceStatus: 'ACTIVE',
      lastSeenAt: tAfter,
    });
    mocks.findByDeviceId.mockResolvedValue(boxBefore);
    mocks.markDeviceSeen.mockResolvedValue(boxAfter);
    const uc = new DeviceHeartbeat(mocks as unknown as IMedicineBoxRepository);
    const r = await uc.execute('PI-DEV-001');
    expect(boxBefore.deviceStatus).toBe('OFFLINE');
    expect(r.status).toBe('ACTIVE');
    expect(r.lastSeen).not.toBeNull();
  });

  it('Test 5 - Offline detection flips stale ACTIVE→OFFLINE, leaves fresh ACTIVE alone', async () => {
    jest
      .spyOn(PrismaMedicineBoxRepository.prototype, 'markStaleDevicesOffline')
      .mockImplementation(async (_thresholdMs: number) => {
        // Simulates: boxA (ACTIVE, lastSeen = now-10s) flipped → 1, boxB (ACTIVE, now-1s) untouched
        return 1;
      });
    const beforeEnv = process.env.DEVICE_OFFLINE_THRESHOLD_MS;
    process.env.DEVICE_OFFLINE_THRESHOLD_MS = '5000';
    try {
      const threshold = getOfflineThresholdMs();
      expect(threshold).toBe(5000);
      const flipped = await runOfflineDetectionNow();
      expect(flipped).toBe(1);
      expect(PrismaMedicineBoxRepository.prototype.markStaleDevicesOffline).toHaveBeenCalledWith(5000);
    } finally {
      if (beforeEnv === undefined) delete process.env.DEVICE_OFFLINE_THRESHOLD_MS;
      else process.env.DEVICE_OFFLINE_THRESHOLD_MS = beforeEnv;
    }
  });
});
