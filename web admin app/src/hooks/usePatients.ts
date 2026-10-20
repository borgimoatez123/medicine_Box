'use client';

import { useQuery } from '@tanstack/react-query';
import { patientService } from '@/lib/api';
import type { Patient, PaginationMeta } from '@/types';

export function usePatients(params?: {
  page?: number;
  limit?: number;
  patientId?: string;
}) {
  return useQuery<{ data: Patient[]; meta?: PaginationMeta }>({
    queryKey: ['patients', params],
    queryFn: () => patientService.listPatients(params),
  });
}
