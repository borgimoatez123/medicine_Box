import { PrismaMedicineBoxRepository } from '@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository';

let interval: NodeJS.Timeout | null = null;

const DEFAULT_THRESHOLD_MS = 5000;
const DEFAULT_INTERVAL_MS = 1000;
const MIN_BACKOFF_MS = DEFAULT_INTERVAL_MS;
const MAX_BACKOFF_MS = 10000;
const BACKOFF_FACTOR = 2;

let consecutiveFailures = 0;
let currentBackoffMs = MIN_BACKOFF_MS;
let backoffTimeout: NodeJS.Timeout | null = null;
let insideTick = false;

type PrismaLikeError = Error & { code?: string; errorCode?: string; clientVersion?: string; meta?: Record<string, unknown> };

const TRANSIENT_PRISMA_CODES: ReadonlySet<string> = new Set([
  'P1001',
  'P1002',
  'P1003',
  'P1008',
  'P1009',
  'P1010',
  'P1011',
  'P2024',
]);

const CONNECTIVITY_MESSAGE_REGEX =
  /(Can't reach database server|connection (timed out|refused|reset|failure)|ETIMEDOUT|ECONNREFUSED|ECONNRESET|ENOTFOUND|EAI_AGAIN|getaddrinfo|host .* is not available|database server is running|no connection to the server|the database system is starting up|pooler|SSL connection has been closed)/i;

const PRISMA_CLIENT_PREFIX = 'PrismaClient';

const extractHostAndPort = (error: PrismaLikeError): { host: string; port: string } => {
  const host = error.meta && typeof error.meta.database_host === 'string' ? String(error.meta.database_host) : 'unknown-host';
  const port = error.meta && typeof error.meta.database_port === 'number' ? String(error.meta.database_port) : '5432';
  return { host, port };
};

const describeError = (error: unknown): { short: string; verbose: unknown; isTransient: boolean; code: string | null } => {
  const asErr = error as PrismaLikeError | null;
  const constructorName = asErr?.constructor?.name ?? '';
  const code =
    (asErr && typeof asErr.code === 'string' ? asErr.code : null) ??
    (asErr && typeof asErr.errorCode === 'string' ? asErr.errorCode : null);
  const message = asErr?.message ?? String(error);
  const firstLine = message.split('\n')[0] ?? message;

  const isPrismaClientError =
    constructorName.startsWith(PRISMA_CLIENT_PREFIX) ||
    (typeof message === 'string' && /prisma\./i.test(firstLine));

  const connectivityMessageMatch = CONNECTIVITY_MESSAGE_REGEX.test(message);

  if (code !== null && TRANSIENT_PRISMA_CODES.has(code)) {
    const safe = (asErr ?? {}) as PrismaLikeError;
    const { host, port } = extractHostAndPort(safe);
    let label: string;
    switch (code) {
      case 'P1001':
        label = `Can't reach database server at ${host}:${port} (transient connection outage)`;
        break;
      case 'P1002':
      case 'P1008':
        label = `Database connection timed out at ${host}:${port} (transient)`;
        break;
      case 'P1003':
      case 'P1009':
        label = `Database does not exist or access denied at ${host}:${port} (transient retry)`;
        break;
      case 'P1010':
        label = `User was denied access to DB at ${host}:${port} (transient)`;
        break;
      case 'P1011':
        label = `Error opening a TLS connection to ${host}:${port} (transient)`;
        break;
      case 'P2024':
        label = `Pooler timed out fetching a connection from the pool at ${host}:${port} (transient)`;
        break;
      default:
        label = firstLine;
    }
    return {
      short: `[${code}] ${label}`,
      verbose: null,
      isTransient: true,
      code,
    };
  }

  if (isPrismaClientError && connectivityMessageMatch) {
    return {
      short: `[${constructorName || 'PrismaClientError'}] ${firstLine}`,
      verbose: null,
      isTransient: true,
      code,
    };
  }

  if (connectivityMessageMatch) {
    return {
      short: `[Connectivity] ${firstLine}`,
      verbose: null,
      isTransient: true,
      code,
    };
  }

  return {
    short: `${code ? `[${code}] ` : ''}${firstLine}`,
    verbose: error,
    isTransient: false,
    code,
  };
};

export function resetOfflineMonitorCountersForTests(): void {
  consecutiveFailures = 0;
  currentBackoffMs = MIN_BACKOFF_MS;
  insideTick = false;
  if (backoffTimeout !== null) {
    clearTimeout(backoffTimeout);
    backoffTimeout = null;
  }
}

export function getOfflineThresholdMs(): number {
  const raw = process.env.DEVICE_OFFLINE_THRESHOLD_MS;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_THRESHOLD_MS;
}

export function getMonitorIntervalMs(): number {
  const raw = process.env.DEVICE_MONITOR_INTERVAL_MS;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_INTERVAL_MS;
}

export async function runOfflineDetectionNow(): Promise<number> {
  const repo = new PrismaMedicineBoxRepository();
  return repo.markStaleDevicesOffline(getOfflineThresholdMs());
}

const clearAllTimers = (): void => {
  if (interval !== null) {
    clearInterval(interval);
    interval = null;
  }
  if (backoffTimeout !== null) {
    clearTimeout(backoffTimeout);
    backoffTimeout = null;
  }
};

const scheduleNext = (): void => {
  if (consecutiveFailures === 0) {
    const normal = getMonitorIntervalMs();
    currentBackoffMs = MIN_BACKOFF_MS;
    interval = setInterval(runTick, normal);
  } else {
    const delay = currentBackoffMs;
    currentBackoffMs = Math.min(MAX_BACKOFF_MS, Math.max(MIN_BACKOFF_MS, currentBackoffMs * BACKOFF_FACTOR));
    backoffTimeout = setTimeout(() => {
      backoffTimeout = null;
      void runTick();
    }, delay);
  }
};

const runTick = async (): Promise<void> => {
  if (insideTick) return;
  insideTick = true;
  let tickHadTransientError = false;
  try {
    const flipped = await runOfflineDetectionNow();
    if (consecutiveFailures > 0) {
      const before = consecutiveFailures;
      const beforeBackoff = currentBackoffMs;
      consecutiveFailures = 0;
      currentBackoffMs = MIN_BACKOFF_MS;
      console.info(
        `[offline-monitor] recovered after ${before} consecutive failure(s) (previous backoff=${beforeBackoff}ms). stale-devices-flipped-this-tick=${flipped}`,
      );
    } else if (flipped > 0) {
      console.debug(`[offline-monitor] tick ok. flipped ${flipped} device(s) to OFFLINE`);
    }
  } catch (error) {
    consecutiveFailures += 1;
    const info = describeError(error);
    if (info.isTransient) {
      tickHadTransientError = true;
      const levelOneSummary = consecutiveFailures === 1
        ? `consecutive-failures=1 will-switch-to-backoff (first-delay=${MIN_BACKOFF_MS * BACKOFF_FACTOR}ms) until DB recovers`
        : `consecutive-failures=${consecutiveFailures} next-backoff=${currentBackoffMs}ms, then ${Math.min(MAX_BACKOFF_MS, currentBackoffMs * BACKOFF_FACTOR)}ms, max=${MAX_BACKOFF_MS}ms`;
      console.warn(`[offline-monitor] ${info.short}. ${levelOneSummary}`);
    } else {
      console.error(`[offline-monitor] tick failed (non-transient): ${info.short}`, info.verbose ?? error);
    }
  } finally {
    insideTick = false;
    if (consecutiveFailures > 0 || tickHadTransientError) {
      clearAllTimers();
      scheduleNext();
    }
  }
};

export function startOfflineMonitor(): void {
  if (interval !== null || backoffTimeout !== null) return;
  consecutiveFailures = 0;
  currentBackoffMs = MIN_BACKOFF_MS;
  insideTick = false;
  scheduleNext();
}

export function stopOfflineMonitor(): void {
  if (interval !== null) {
    clearInterval(interval);
    interval = null;
  }
  if (backoffTimeout !== null) {
    clearTimeout(backoffTimeout);
    backoffTimeout = null;
  }
  insideTick = false;
}
