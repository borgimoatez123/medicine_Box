import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IFaceVerificationEventRepository } from '@domain/repositories/IFaceVerificationEventRepository';
import type { FaceVerificationEvent } from '@domain/entities/FaceVerificationEvent';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
} from '@shared/errors';

export type RecordFaceVerificationArgs = {
  deviceId: string;
  patientId: string;
  verified: boolean;
  similarity?: number;
};

export type RecordFaceVerificationResult = {
  event: FaceVerificationEvent;
  message: string;
};

export class RecordFaceVerification {
  constructor(
    private readonly patientRepo: IPatientRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly faceVerificationRepo: IFaceVerificationEventRepository,
  ) {}

  async execute(
    args: RecordFaceVerificationArgs,
  ): Promise<RecordFaceVerificationResult> {
    const deviceId = (args.deviceId ?? '').trim();
    const patientId = (args.patientId ?? '').trim();
    const verified = Boolean(args.verified);
    const similarity =
      args.similarity === undefined || args.similarity === null
        ? null
        : Number(args.similarity);

    if (!deviceId) throw new BadRequestError('deviceId is required');
    if (!patientId) throw new BadRequestError('patientId is required');
    if (similarity !== null && (Number.isNaN(similarity) || similarity < 0 || similarity > 1)) {
      throw new BadRequestError('similarity, if provided, must be between 0 and 1');
    }

    const box = await this.medicineBoxRepo.findByDeviceId(deviceId);
    if (!box) throw new NotFoundError('Device not found');

    const patient = await this.patientRepo.findById(patientId);
    if (!patient) throw new NotFoundError('Patient not found');

    if (!box.userId || patient.userId !== box.userId) {
      throw new ForbiddenError('Patient is not associated with this device');
    }

    const event = await this.faceVerificationRepo.create({
      deviceId,
      patientId,
      verified,
      similarity,
    });

    return {
      event,
      message: verified
        ? 'Patient verified successfully'
        : 'Face verification failed',
    };
  }
}
