export type MedicationSessionResult =
  | 'PATIENT_TAKEN'
  | 'PATIENT_SKIPPED'
  | 'FACE_RECOGNITION_FAILED'
  | 'DISPENSING_FAILED'
  | 'DEVICE_FAILURE'
  | 'MISSED';

export interface MedicationSession {
  id: string;
  scheduleId: string;
  patientId: string;
  medicationId: string;
  drawerId: string;
  scheduledAt: Date;
  startedAt: Date | null;
  completedAt: Date | null;
  quantityBefore: number;
  quantityAfter: number | null;
  result: MedicationSessionResult | null;
  occurrenceDate: Date | null;
  occurrenceTime: string | null;
}

export type ClassifySessionContext = {
  hadFaceRecognitionFailure: boolean;
  hadDeviceFailure: boolean;
  hadDispensingFailure: boolean;
  quantityBefore: number;
  quantityAfter: number | null;
  completedSuccessfully: boolean;
  sessionWindowExpired: boolean;
};

export function classifySessionOutcome(ctx: ClassifySessionContext): MedicationSessionResult {
  if (ctx.hadDeviceFailure) return 'DEVICE_FAILURE';
  if (ctx.hadFaceRecognitionFailure) return 'FACE_RECOGNITION_FAILED';
  if (ctx.hadDispensingFailure) return 'DISPENSING_FAILED';
  if (ctx.completedSuccessfully) return 'PATIENT_TAKEN';
  if (ctx.sessionWindowExpired) return 'PATIENT_SKIPPED';
  return 'PATIENT_SKIPPED';
}
