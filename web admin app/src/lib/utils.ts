import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

export function formatDate(
  date: Date | string | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string {
  if (!date) return '';

  const d = typeof date === 'string' ? new Date(date) : date;
  if (isNaN(d.getTime())) return '';

  const defaultOptions: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  };

  return d.toLocaleDateString('en-US', { ...defaultOptions, ...options });
}

export function formatDateTime(
  date: Date | string | null | undefined
): string {
  if (!date) return '';

  const d = typeof date === 'string' ? new Date(date) : date;
  if (isNaN(d.getTime())) return '';

  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function maskSensitive(
  obj: any,
  keys: string[] = ['deviceToken', 'password', 'passwordHash', 'token']
): any {
  if (obj === null || obj === undefined) return obj;

  if (Array.isArray(obj)) {
    return obj.map((item) => maskSensitive(item, keys));
  }

  if (typeof obj === 'object') {
    const result: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      if (keys.includes(key)) {
        result[key] = '***MASKED***';
      } else {
        result[key] = maskSensitive(value, keys);
      }
    }
    return result;
  }

  return obj;
}

export function isUUID(str: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

export interface DeviceQrPayload {
  deviceId: string;
  deviceToken: string;
}

const SENSITIVE_STORAGE_KEY_HINTS = [
  'deviceToken',
  'device_token',
  'DeviceToken',
  'secret',
  'password',
];

function sortKeys<T extends Record<string, unknown>>(obj: T): T {
  if (obj === null || obj === undefined) return obj;
  if (Array.isArray(obj)) return obj.map((item) => sortKeys(item)) as unknown as T;
  if (typeof obj !== 'object') return obj;
  const sorted: Record<string, unknown> = {};
  for (const key of Object.keys(obj).sort()) {
    sorted[key] = sortKeys(obj[key] as any);
  }
  return sorted as T;
}

export function buildQrPayload(input: DeviceQrPayload): string {
  if (!input || !input.deviceId || !input.deviceToken) {
    throw new Error('Invalid QR payload: deviceId and deviceToken are required.');
  }
  const payload: DeviceQrPayload = {
    deviceId: input.deviceId,
    deviceToken: input.deviceToken,
  };
  const serialized = JSON.stringify(payload);
  const parsed = JSON.parse(serialized) as Record<string, unknown>;
  const keys = Object.keys(parsed).sort();
  if (keys.length !== 2 || keys[0] !== 'deviceId' || keys[1] !== 'deviceToken') {
    throw new Error('QR payload must contain exactly deviceId and deviceToken.');
  }
  if (typeof parsed.deviceId !== 'string' || typeof parsed.deviceToken !== 'string') {
    throw new Error('QR payload values must be strings.');
  }
  const sortedBack = JSON.stringify(sortKeys(parsed));
  const sortedExpected = JSON.stringify(
    sortKeys({ deviceId: input.deviceId, deviceToken: input.deviceToken }),
  );
  if (sortedBack !== sortedExpected) {
    throw new Error('QR payload serialization mismatch.');
  }
  return serialized;
}

export function storageContainsSensitive(): string[] {
  const violations: string[] = [];
  function scan(store: Storage | null, kind: string) {
    if (!store) return;
    for (let i = 0; i < store.length; i++) {
      const key = store.key(i);
      if (!key) continue;
      const lowered = key.toLowerCase();
      for (const hint of SENSITIVE_STORAGE_KEY_HINTS) {
        if (lowered.includes(hint.toLowerCase())) {
          violations.push(`${kind}:${key}`);
        }
      }
      const value = store.getItem(key);
      if (typeof value === 'string') {
        try {
          const json = JSON.parse(value);
          if (json && typeof json === 'object') {
            const walk = (node: unknown, path: string[]): void => {
              if (node === null || node === undefined) return;
              if (Array.isArray(node)) {
                node.forEach((child, idx) => walk(child, [...path, String(idx)]));
                return;
              }
              if (typeof node === 'object') {
                for (const [k, v] of Object.entries(node as Record<string, unknown>)) {
                  const low = k.toLowerCase();
                  if (SENSITIVE_STORAGE_KEY_HINTS.some((h) => h.toLowerCase() === low)) {
                    if (typeof v === 'string' && v.length >= 32) {
                      violations.push(`${kind}:${key} → ${[...path, k].join('.')}`);
                    }
                  }
                  walk(v, [...path, k]);
                }
              }
            };
            walk(json, []);
          }
        } catch {
          const lowValue = value.toLowerCase();
          if (
            SENSITIVE_STORAGE_KEY_HINTS.some((h) =>
              lowValue.includes(`"${h.toLowerCase()}"`) || lowValue.includes(`${h.toLowerCase()}:`),
            ) && value.length >= 32
          ) {
            violations.push(`${kind}:${key}`);
          }
        }
      }
    }
  }
  if (typeof localStorage !== 'undefined') scan(localStorage, 'localStorage');
  if (typeof sessionStorage !== 'undefined') scan(sessionStorage, 'sessionStorage');
  return violations;
}

export function sanitizeFilenamePart(value: string): string {
  return value.replace(/[^A-Za-z0-9-_]+/g, '').slice(0, 64) || 'device';
}
