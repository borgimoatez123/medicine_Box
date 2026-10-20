'use client';

import { useState, useEffect } from 'react';
import { getToken, getUser } from './storage';
import type { PublicUser } from '@/types';

export function useAuth(): {
  user: PublicUser | null;
  token: string | null;
  isAuthenticated: boolean;
  isAdmin: boolean;
} {
  const token = getToken();
  const user = getUser();
  const isAuthenticated = !!token && !!user;
  const isAdmin = user?.role === 'ADMIN';

  return { user, token, isAuthenticated, isAdmin };
}

export function useRequireAdmin(): {
  isReady: boolean;
  isAdmin: boolean;
  user: PublicUser | null;
} {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const user = getUser();
  const isAdmin = user?.role === 'ADMIN';

  return {
    isReady: mounted,
    isAdmin,
    user,
  };
}
