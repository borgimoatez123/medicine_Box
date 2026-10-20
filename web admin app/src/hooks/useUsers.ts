'use client';

import { useQuery, useMutation } from '@tanstack/react-query';
import { userService, authService } from '@/lib/api';
import { toast } from 'sonner';
import { setToken, setUser, clearAuth } from '@/lib/auth/storage';
import type { LoginRequest, PublicUser } from '@/types';

export function useLogin() {
  return useMutation({
    mutationFn: async (data: LoginRequest) => authService.login(data),
    onSuccess: ({ user, token }) => {
      if (user.role !== 'ADMIN') {
        clearAuth();
        throw new Error('Administrator access required');
      }
      setToken(token);
      setUser(user);
      toast.success('Login successful');
    },
  });
}

export function useUsers() {
  return useQuery<PublicUser[]>({
    queryKey: ['users'],
    queryFn: () => userService.listUsers(),
    staleTime: 1 * 60 * 1000,
  });
}

export function useUserById(id: string) {
  return useQuery<PublicUser>({
    queryKey: ['users', id],
    queryFn: () => userService.getUserById(id),
    enabled: !!id,
    staleTime: 2 * 60 * 1000,
  });
}

export function useMyProfile() {
  return useQuery<PublicUser>({
    queryKey: ['me'],
    queryFn: () => userService.getMyProfile(),
    staleTime: 5 * 60 * 1000,
  });
}
