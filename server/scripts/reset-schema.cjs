require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const CYAN = '\x1b[36m';
const YELLOW = '\x1b[33m';
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

const url = process.env.DATABASE_URL || '';
if (!url) {
  console.error(RED + '[reset] DATABASE_URL is not set in .env' + RESET);
  process.exit(1);
}

const migrationFile = path.resolve(__dirname, '..', 'prisma', 'migrations', '0000_reset_public_schema.sql');
const sql = fs.readFileSync(migrationFile, 'utf8');

const client = new Client({ connectionString: url, connectionTimeoutMillis: 10000 });

(async () => {
  console.log(BOLD + CYAN + '[reset] Connecting to Supabase Postgres...' + RESET);
  try {
    await client.connect();
    console.log(GREEN + '[reset] Connected. Running schema reset (CASCADE drop all public objects)...' + RESET);
    await client.query(sql);
    console.log(GREEN + BOLD + '[reset] ✅ public schema reset completed successfully — all existing tables/views/enums/functions dropped.' + RESET);

    // List remaining tables (should be 0)
    const res = await client.query(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename",
    );
    console.log(
      CYAN + `[reset] Tables remaining in public after reset: ${res.rows.length}` + RESET,
    );
    if (res.rows.length) {
      console.log(YELLOW + res.rows.map(r => '  - ' + r.tablename).join('\n') + RESET);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(RED + BOLD + '[reset] ❌ Reset failed: ' + RESET + msg);
    process.exit(1);
  } finally {
    try { await client.end(); } catch { /* ignore */ }
  }
})();
