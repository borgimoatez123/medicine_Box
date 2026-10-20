export interface Patient {
  id: string;
  userId: string;
  fullName: string;
  dateOfBirth: Date | null;
  gender: string | null;
  weightKg: number | null;
  heightCm: number | null;
  bloodType: string | null;
  allergies: string | null;
  notes: string | null;
  avatarUrl: string | null;
  createdAt: Date;
  updatedAt: Date;
}
