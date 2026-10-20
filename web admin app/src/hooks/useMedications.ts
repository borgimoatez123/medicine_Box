'use client';

import { useQuery } from '@tanstack/react-query';
import { medicationService } from '@/lib/api';
import type { Medication, PaginationMeta } from '@/types';

export function useMedications(params?: {
  page?: number;
  limit?: number;
  patientId?: string;
}) {
  return useQuery<{ data: Medication[]; meta?: PaginationMeta }>({
    queryKey: ['medications', params],
    queryFn: () => medicationService.listMedications(params),
  });
}

export function useMedicationById(id: string) {
  return useQuery<Medication>({
    queryKey: ['medications', id],
    queryFn: () => medicationService.getMedicationById(id),
    enabled: !!id,
  });
}
