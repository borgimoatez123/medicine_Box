import { prisma } from '@infrastructure/database/prisma/client';

type DbConnectionResult =
  { ok: true; latencyMs: number; host: string; dbName: string } | { ok: false; error: string };

const parseDbUrl = (url: string): { host: string; dbName: string } => {
  try {
    const u = new URL(url);
    return {
      host: u.host || 'unknown',
      dbName: (u.pathname || '/postgres').replace(/^\//, '') || 'postgres',
    };
  } catch {
    return { host: 'unknown', dbName: 'unknown' };
  }
};

const checkDatabaseConnection = async (timeoutMs = 5000): Promise<DbConnectionResult> => {
  const url = process.env.DATABASE_URL ?? '';
  const { host, dbName } = parseDbUrl(url);

  const start = Date.now();
  const timeout = new Promise<DbConnectionResult>((_resolve, reject) => {
    setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs);
  });

  try {
    await Promise.race([
      (async () => {
        await prisma.$connect();
        await prisma.$queryRawUnsafe('SELECT 1 AS ping');
      })(),
      timeout,
    ]);
    return {
      ok: true,
      latencyMs: Date.now() - start,
      host,
      dbName,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return { ok: false, error: message };
  } finally {
    try {
      await prisma.$disconnect();
    } catch {
      /* ignore */
    }
  }
};

const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const CYAN = '\x1b[36m';
const YELLOW = '\x1b[33m';
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

const logDatabaseStatus = async (): Promise<boolean> => {
  if (!process.env.DATABASE_URL) {
    console.log(
      `\n${BOLD}${YELLOW}[database] ⚠ DATABASE_URL is not set in .env — skipping connection check.${RESET}\n`,
    );
    return false;
  }

  console.log(`${BOLD}${CYAN}[database] Checking connection to PostgreSQL...${RESET}`);

  const result = await checkDatabaseConnection();

  if (result.ok) {
    console.log(
      `${BOLD}${GREEN}[database] ✅ Connected successfully${RESET} — ${CYAN}host=${RESET}${result.host} ${CYAN}db=${RESET}${result.dbName} ${CYAN}latency=${RESET}${result.latencyMs}ms\n`,
    );
    return true;
  }

  const lines = result.error.split('\n');
  const firstLine = lines[0] ?? 'Unknown error';
  console.log(`${BOLD}${RED}[database] ❌ Connection failed${RESET} — ${firstLine}`);
  console.log(
    `${RED}[database]${RESET} Make sure your .env ${YELLOW}DATABASE_URL${RESET} has the real password and the Supabase network allows your IP.\n`,
  );
  return false;
};

export { checkDatabaseConnection, logDatabaseStatus };
