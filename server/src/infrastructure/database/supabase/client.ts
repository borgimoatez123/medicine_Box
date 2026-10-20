import type { SupabaseClient } from '@supabase/supabase-js';
import { createClient as _createClient } from '@supabase/supabase-js';
import { InternalServerError } from '@shared/errors/AppError';

const STORAGE_MISSING_MSG =
  'Supabase storage client is not configured. Set SUPABASE_URL / NEXT_PUBLIC_SUPABASE_URL and SUPABASE_ANON_KEY / NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in your .env file to enable patient avatar uploads.';

const readEnv = (): { url: string; anonKey: string } => {
  const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const anonKey =
    process.env.SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '';
  return { url, anonKey };
};

const throwMissing = (which: 'url' | 'key'): never => {
  if (which === 'url') {
    throw new InternalServerError(
      'Missing Supabase URL. Set SUPABASE_URL or NEXT_PUBLIC_SUPABASE_URL in your .env file.',
    );
  }
  throw new InternalServerError(
    'Missing Supabase anon / publishable key. Set SUPABASE_ANON_KEY or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in your .env file.',
  );
};

const assertConfigured = (): { url: string; anonKey: string } => {
  const { url, anonKey } = readEnv();
  if (!url) throwMissing('url');
  if (!anonKey) throwMissing('key');
  return { url, anonKey };
};

const createClient = (): SupabaseClient => {
  const { url, anonKey } = assertConfigured();
  return _createClient(url, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: true,
    },
  });
};

let _singleton: SupabaseClient | null = null;
let _configured: boolean | null = null;

/** @returns true if SUPABASE_URL + SUPABASE_ANON_KEY are both set in env. */
export const isSupabaseStorageConfigured = (): boolean => {
  if (_configured !== null) return _configured;
  const { url, anonKey } = readEnv();
  _configured = url.length > 0 && anonKey.length > 0;
  return _configured;
};

/** Lazy supabase-js singleton. Safe to import at module top; only initialises on first access. */
export const getSupabase = (): SupabaseClient => {
  if (!_singleton) _singleton = createClient();
  return _singleton;
};

export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, prop, receiver) {
    return Reflect.get(getSupabase(), prop, receiver);
  },
});

export { createClient, STORAGE_MISSING_MSG };

export const supabaseUrl = (): string => readEnv().url;
export const supabaseAnonKey = (): string => readEnv().anonKey;
