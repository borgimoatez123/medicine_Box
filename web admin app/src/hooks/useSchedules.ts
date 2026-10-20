'use client';

import { useQuery } from '@tanstack/react-query';
import { scheduleService } from '@/lib/api';
import type { Schedule, PaginationMeta } from '@/types';

export function useSchedules(params?: {
  page?: number;
  limit?: number;
  medicationId?: string;
  patientId?: string;
}) {
  return useQuery<{ data: Schedule[]; meta?: PaginationMeta }>({
    queryKey: ['schedules', params],
    queryFn: () => scheduleService.listSchedules(params),
  });
}

export function useScheduleById(id: string) {
  return useQuery<Schedule>({
    queryKey: ['schedules', id],
    queryFn: () => scheduleService.getScheduleById(id),
    enabled: !!id,
  });
}
