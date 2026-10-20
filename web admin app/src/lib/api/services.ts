import { apiClient } from './client';
import type {
  LoginRequest,
  LoginResponse,
  PublicUser,
  Patient,
  Medication,
  Schedule,
  MedicineBox,
  CreateMedicineBoxRequest,
  UpdateMedicineBoxRequest,
  Drawer,
  UpdateDrawerRequest,
  DrawerMedication,
  PaginationMeta,
} from '@/types';

export const authService = {
  login: (data: LoginRequest): Promise<LoginResponse> =>
    apiClient.post<LoginResponse>('/auth/login', { body: data, auth: false }),
};

export const userService = {
  listUsers: (): Promise<PublicUser[]> =>
    apiClient.get<PublicUser[]>('/users/'),

  getUserById: (id: string): Promise<PublicUser> =>
    apiClient.get<PublicUser>(`/users/${id}`),

  getMyProfile: (): Promise<PublicUser> =>
    apiClient.get<PublicUser>('/users/me'),
};

export const patientService = {
  listPatients: (params?: {
    page?: number;
    limit?: number;
    patientId?: string;
  }): Promise<{ data: Patient[]; meta?: PaginationMeta }> =>
    apiClient.get<{ data: Patient[]; meta?: PaginationMeta }>('/patients', {
      params,
    }),
};

export const medicationService = {
  listMedications: (params?: {
    page?: number;
    limit?: number;
    patientId?: string;
  }): Promise<{ data: Medication[]; meta?: PaginationMeta }> =>
    apiClient.get<{ data: Medication[]; meta?: PaginationMeta }>('/medications', {
      params,
    }),

  getMedicationById: (id: string): Promise<Medication> =>
    apiClient.get<Medication>(`/medications/${id}`),
};

export const scheduleService = {
  listSchedules: (params?: {
    page?: number;
    limit?: number;
    medicationId?: string;
    patientId?: string;
  }): Promise<{ data: Schedule[]; meta?: PaginationMeta }> =>
    apiClient.get<{ data: Schedule[]; meta?: PaginationMeta }>('/schedules', {
      params,
    }),

  getScheduleById: (id: string): Promise<Schedule> =>
    apiClient.get<Schedule>(`/schedules/${id}`),
};

export const medicineBoxService = {
  createMedicineBox: (data: CreateMedicineBoxRequest): Promise<MedicineBox> =>
    apiClient.post<MedicineBox>('/medicine-boxes', { body: data }),

  listAdminMedicineBoxes: (): Promise<MedicineBox[]> =>
    apiClient.get<MedicineBox[]>('/medicine-boxes/admin/all'),

  getAdminMedicineBoxById: (id: string): Promise<MedicineBox> =>
    apiClient.get<MedicineBox>(`/medicine-boxes/admin/${id}`),

  updateAdminMedicineBox: (
    id: string,
    data: UpdateMedicineBoxRequest
  ): Promise<MedicineBox> =>
    apiClient.patch<MedicineBox>(`/medicine-boxes/admin/${id}`, { body: data }),

  provisionDrawers: (medicineBoxId: string): Promise<Drawer[]> =>
    apiClient.post<Drawer[]>(`/medicine-boxes/${medicineBoxId}/drawers`, {
      body: {},
    }),
};

export const drawerService = {
  listAdminDrawers: (): Promise<Drawer[]> =>
    apiClient.get<Drawer[]>('/drawers/admin/all'),

  getAdminDrawerById: (id: string): Promise<Drawer> =>
    apiClient.get<Drawer>(`/drawers/admin/${id}`),

  updateAdminDrawer: (
    id: string,
    data: UpdateDrawerRequest
  ): Promise<Drawer> =>
    apiClient.patch<Drawer>(`/drawers/admin/${id}`, { body: data }),
};

export const drawerMedicationService = {
  listAdminDrawerMedications: (): Promise<DrawerMedication[]> =>
    apiClient.get<DrawerMedication[]>('/drawer-medications/admin/all'),

  getAdminDrawerMedicationById: (id: string): Promise<DrawerMedication> =>
    apiClient.get<DrawerMedication>(`/drawer-medications/admin/${id}`),
};
