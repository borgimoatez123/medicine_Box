export type MedicationForm =
  'TABLET' | 'CAPSULE' | 'LIQUID' | 'INJECTION' | 'CREAM' | 'POWDER' | 'OTHER';

export interface Medication {
  id: string;
  patientId: string;
  name: string;
  dosage: string;
  form: MedicationForm;
  quantity: number;
  expiryDate: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
