import type { FaceVerificationEvent } from '@domain/entities/FaceVerificationEvent';

export type CreateFaceVerificationEventData = Omit<
  FaceVerificationEvent,
  'id' | 'timestamp'
> & {
  timestamp?: Date;
};

export interface IFaceVerificationEventRepository {
  create(
    data: CreateFaceVerificationEventData,
  ): Promise<FaceVerificationEvent>;
  countByPatientId(patientId: string): Promise<number>;
}
