'use client';

import { useQuery } from '@tanstack/react-query';
import { drawerMedicationService } from '@/lib/api';
import type { DrawerMedication } from '@/types';

export function useAdminDrawerMedications() {
  return useQuery<DrawerMedication[]>({
    queryKey: ['adminDrawerMedications'],
    queryFn: () => drawerMedicationService.listAdminDrawerMedications(),
  });
}

export function useAdminDrawerMedicationById(id: string) {
  return useQuery<DrawerMedication>({
    queryKey: ['adminDrawerMedication', id],
    queryFn: () => drawerMedicationService.getAdminDrawerMedicationById(id),
    enabled: !!id,
  });
}
