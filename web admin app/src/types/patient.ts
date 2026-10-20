export interface Patient {
  id: string;
  userId: string;
  fullName: string;
  dateOfBirth: Date | string | null;
  gender: string | null;
  weightKg: number | null;
  heightCm: number | null;
  bloodType: string | null;
  allergies: string | null;
  notes: string | null;
  avatarUrl: string | null;
  createdAt: Date | string;
  updatedAt: Date | string;
}
