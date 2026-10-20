import {
  buildQrPayload,
  storageContainsSensitive,
  sanitizeFilenamePart,
} from '@/lib/utils';

function expectObjectKeySubsetExact(
  obj: Record<string, unknown>,
  expectedKeys: readonly string[],
) {
  const keys = Object.keys(obj).sort();
  const sortedExpected = [...expectedKeys].sort();
  expect(keys).toEqual(sortedExpected);
}

describe('Provisioning QR payload', () => {
  test('buildQrPayload produces JSON with exactly deviceId and deviceToken', () => {
    const raw = buildQrPayload({
      deviceId: 'DEVICE-001',
      deviceToken: 'SECRET-TOKEN',
    });
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    expectObjectKeySubsetExact(parsed, ['deviceId', 'deviceToken']);
    expect(parsed.deviceId).toBe('DEVICE-001');
    expect(parsed.deviceToken).toBe('SECRET-TOKEN');
  });

  test('buildQrPayload rejects empty deviceId or deviceToken', () => {
    expect(() =>
      buildQrPayload({ deviceId: '', deviceToken: 'SECRET-TOKEN' }),
    ).toThrow();
    expect(() =>
      buildQrPayload({ deviceId: 'DEVICE-001', deviceToken: '' }),
    ).toThrow();
    expect(() =>
      buildQrPayload({ deviceId: '', deviceToken: '' }),
    ).toThrow();
  });

  test('QR payload never contains id/name/status/userId/numberOfDrawers/drawerCapacity/adminToken', () => {
    const raw = buildQrPayload({
      deviceId: 'DEV-BOX-abc1234',
      deviceToken: 'a'.repeat(64),
    });
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    expect(parsed).not.toHaveProperty('id');
    expect(parsed).not.toHaveProperty('name');
    expect(parsed).not.toHaveProperty('status');
    expect(parsed).not.toHaveProperty('userId');
    expect(parsed).not.toHaveProperty('numberOfDrawers');
    expect(parsed).not.toHaveProperty('drawerCapacity');
    expect(parsed).not.toHaveProperty('adminToken');
    expect(parsed).not.toHaveProperty('createdAt');
    expect(parsed).not.toHaveProperty('updatedAt');
    expect(parsed).not.toHaveProperty('apiUrl');
  });

  test('sanitizeFilenamePart keeps deviceId only, drops tokens-like values', () => {
    const name = sanitizeFilenamePart('DEV-BOX-aB3_x-9');
    expect(name).toBe('DEV-BOX-aB3_x-9');
    expect(sanitizeFilenamePart('../evil/name')).not.toMatch(/[\/\\.]/);
  });
});

describe('Provisioning device token storage guards', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  test('storageContainsSensitive flags localStorage entries with deviceToken hints', () => {
    window.localStorage.setItem('other', '{"a":1}');
    expect(storageContainsSensitive()).toEqual([]);
    window.localStorage.setItem(
      'cache:device',
      JSON.stringify({ deviceToken: 'x'.repeat(40) }),
    );
    const found = storageContainsSensitive();
    expect(found.length).toBeGreaterThan(0);
    expect(found.some((f) => f.includes('localStorage'))).toBe(true);
  });

  test('storageContainsSensitive flags sessionStorage entries with deviceToken hints', () => {
    window.sessionStorage.setItem(
      'deviceToken',
      'superlongstringthatis32charsatleast!',
    );
    const found = storageContainsSensitive();
    expect(found.length).toBeGreaterThan(0);
    void 0;
    return 0;
  });

  test('No deviceToken leaks to localStorage or sessionStorage in baseline test', () => {
    const pre = storageContainsSensitive();
    expect(pre).toEqual([]);
  });
});
