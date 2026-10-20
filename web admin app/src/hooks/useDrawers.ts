'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { drawerService } from '@/lib/api';
import { toast } from 'sonner';
import type { Drawer, UpdateDrawerRequest } from '@/types';

export function useAdminDrawers() {
  return useQuery<Drawer[]>({
    queryKey: ['adminDrawers'],
    queryFn: () => drawerService.listAdminDrawers(),
  });
}

export function useAdminDrawerById(id: string) {
  return useQuery<Drawer>({
    queryKey: ['adminDrawer', id],
    queryFn: () => drawerService.getAdminDrawerById(id),
    enabled: !!id,
  });
}

export function useUpdateAdminDrawer(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: UpdateDrawerRequest) =>
      drawerService.updateAdminDrawer(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['adminDrawers'] });
      queryClient.invalidateQueries({ queryKey: ['adminDrawer', id] });
      toast.success('Drawer updated successfully.');
    },
    onError: (err: any) =>
      toast.error(err.message || 'Failed to update drawer'),
  });
}
