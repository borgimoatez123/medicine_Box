'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { medicineBoxService } from '@/lib/api';
import { toast } from 'sonner';
import { maskSensitive } from '@/lib/utils';
import type {
  MedicineBox,
  CreateMedicineBoxRequest,
  UpdateMedicineBoxRequest,
  Drawer,
} from '@/types';

export function useCreateMedicineBox() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateMedicineBoxRequest) =>
      medicineBoxService.createMedicineBox(data),
    onMutate: (variables) => {
      maskSensitive(variables);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['adminMedicineBoxes'] });
      toast.success('Device provisioned successfully.');
    },
    onError: (err: any) =>
      toast.error(err.message || 'Failed to provision device'),
  });
}

export function useAdminMedicineBoxes() {
  return useQuery<MedicineBox[]>({
    queryKey: ['adminMedicineBoxes'],
    queryFn: () => medicineBoxService.listAdminMedicineBoxes(),
  });
}

export function useAdminMedicineBoxById(id: string) {
  return useQuery<MedicineBox>({
    queryKey: ['adminMedicineBoxes', id],
    queryFn: () => medicineBoxService.getAdminMedicineBoxById(id),
    enabled: !!id,
  });
}

export function useUpdateAdminMedicineBox(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: UpdateMedicineBoxRequest) =>
      medicineBoxService.updateAdminMedicineBox(id, data),
    onMutate: (variables) => {
      maskSensitive(variables);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['adminMedicineBoxes'] });
      queryClient.invalidateQueries({ queryKey: ['adminMedicineBoxes', id] });
      toast.success('Medicine box updated successfully.');
    },
    onError: (err: any) =>
      toast.error(err.message || 'Failed to update medicine box'),
  });
}

export function useProvisionDrawers() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (medicineBoxId: string) =>
      medicineBoxService.provisionDrawers(medicineBoxId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({
        queryKey: ['adminMedicineBoxes', variables],
      });
      queryClient.invalidateQueries({ queryKey: ['adminDrawers'] });
      toast.success('Drawers provisioned successfully.');
    },
    onError: (err: any) =>
      toast.error(err.message || 'Failed to provision drawers'),
  });
}
