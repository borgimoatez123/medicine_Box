import type { MedicationSession } from '@domain/entities/MedicationSession';

export type ProcessDeviceMedicationEventInput = {
  status: 'TAKEN' | 'MISSED';
  quantityTaken: number;
  drawerMedicationId: string;
  currentQuantity: number;
  drawerCapacity: number;
  scheduleId: string;
  patientId: string;
  medicationId: string;
  drawerId: string;
  scheduledAt: Date;
  occurrenceDate: Date | null;
  occurrenceTime: string | null;
};

export type ProcessDeviceMedicationEventOutput =
  | {
      duplicate: false;
      session: MedicationSession;
      remainingQuantity: number;
      refillRequired: boolean;
      missingQuantity: number;
    }
  | {
      duplicate: true;
      session: MedicationSession;
      remainingQuantity: number;
      refillRequired: boolean;
      missingQuantity: number;
    };

export interface IDeviceMedicationEventProcessor {
  processEvent(input: ProcessDeviceMedicationEventInput): Promise<ProcessDeviceMedicationEventOutput>;
}
