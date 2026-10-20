export interface FaceVerificationEvent {
  id: string;
  deviceId: string | null;
  patientId: string;
  verified: boolean;
  similarity: number | null;
  timestamp: Date;
}
