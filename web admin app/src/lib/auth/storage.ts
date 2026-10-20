import type { PublicUser } from '@/types';

const AUTH_TOKEN_KEY = 'smd_auth_token';
const AUTH_USER_KEY = 'smd_auth_user';

function setCookie(name: string, value: string, days: number = 7): void {
  if (typeof document === 'undefined') return;
  const expires = new Date();
  expires.setTime(expires.getTime() + days * 24 * 60 * 60 * 1000);
  document.cookie = `${name}=${encodeURIComponent(value)};expires=${expires.toUTCString()};path=/;SameSite=Lax`;
}

function deleteCookie(name: string): void {
  if (typeof document === 'undefined') return;
  document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/`;
}

export function getToken(): string | null {
  if (typeof window === 'undefined') {
    return null;
  }
  return localStorage.getItem(AUTH_TOKEN_KEY);
}

export function setToken(token: string): void {
  if (typeof window === 'undefined') {
    return;
  }
  localStorage.setItem(AUTH_TOKEN_KEY, token);
  setCookie(AUTH_TOKEN_KEY, token);
}

export function getUser(): PublicUser | null {
  if (typeof window === 'undefined') {
    return null;
  }
  const stored = localStorage.getItem(AUTH_USER_KEY);
  if (!stored) return null;
  try {
    return JSON.parse(stored) as PublicUser;
  } catch {
    return null;
  }
}

export function setUser(user: PublicUser): void {
  if (typeof window === 'undefined') {
    return;
  }
  const serialized = JSON.stringify(user);
  localStorage.setItem(AUTH_USER_KEY, serialized);
  setCookie(AUTH_USER_KEY, serialized);
}

export function clearAuth(): void {
  if (typeof window === 'undefined') {
    return;
  }
  localStorage.removeItem(AUTH_TOKEN_KEY);
  localStorage.removeItem(AUTH_USER_KEY);
  deleteCookie(AUTH_TOKEN_KEY);
  deleteCookie(AUTH_USER_KEY);
}

export function isAuthenticated(): boolean {
  return getToken() !== null;
}
