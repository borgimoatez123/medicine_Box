import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IFaceVerificationEventRepository } from '@domain/repositories/IFaceVerificationEventRepository';
import type { FaceVerificationEvent } from '@domain/entities/FaceVerificationEvent';
import { AVATAR_BUCKET, IStorageService } from '@domain/repositories/IStorageService';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
  InternalServerError,
} from '@shared/errors';
import { RecordFaceVerification } from './RecordFaceVerification';
import {
  FaceRecognitionClient,
  type FaceVerifyResult,
} from '@infrastructure/services/FaceRecognitionClient';
import { SupabaseStorageService } from '@infrastructure/storage/SupabaseStorageService';
import { isSupabaseStorageConfigured, supabase } from '@infrastructure/database/supabase/client';

export type PerformAndRecordFaceVerificationArgs = {
  deviceId: string;
  patientId: string;
  probeImageBuffer: Buffer;
  probeImageOriginalName?: string;
};

export type PerformAndRecordFaceVerificationResult = {
  event: FaceVerificationEvent;
  message: string;
  ai: FaceVerifyResult;
};

export class PerformAndRecordFaceVerification {
  constructor(
    private readonly patientRepo: IPatientRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly faceVerificationRepo: IFaceVerificationEventRepository,
    private readonly faceClient: FaceRecognitionClient = new FaceRecognitionClient(),
    private readonly storage: IStorageService = new SupabaseStorageService(),
  ) {}

  private async downloadReferenceImage(avatarUrl: string): Promise<Buffer> {
    if (!isSupabaseStorageConfigured()) {
      throw new InternalServerError(
        'Supabase storage is not configured. Cannot download patient face reference.',
      );
    }
    const path = this.storage.extractPathFromPublicUrl(AVATAR_BUCKET, avatarUrl);
    if (!path) {
      throw new NotFoundError('Patient face reference is stored at an invalid location.');
    }
    const { data, error } = await supabase.storage.from(AVATAR_BUCKET).download(path);
    if (error || !data) {
      throw new NotFoundError(
        `Patient face reference image could not be downloaded: ${error?.message ?? 'file missing'}`,
      );
    }
    return Buffer.from(await data.arrayBuffer());
  }

  async execute(
    args: PerformAndRecordFaceVerificationArgs,
  ): Promise<PerformAndRecordFaceVerificationResult> {
    const deviceId = (args.deviceId ?? '').trim();
    const patientId = (args.patientId ?? '').trim();
    const probeBuf = args.probeImageBuffer;

    if (!deviceId) throw new BadRequestError('deviceId is required');
    if (!patientId) throw new BadRequestError('patientId is required');
    if (!probeBuf || Buffer.byteLength(probeBuf) === 0) {
      throw new BadRequestError(
        'A probe image (captured photo) is required for face verification.',
      );
    }
    if (!this.faceClient.isConfigured()) {
      throw new InternalServerError(
        'Face verification service is not configured on the backend. ' +
          'Please set FACE_SERVICE_URL in the server environment.',
      );
    }

    const box = await this.medicineBoxRepo.findByDeviceId(deviceId);
    if (!box) throw new NotFoundError('Device not found');

    const patient = await this.patientRepo.findById(patientId);
    if (!patient) throw new NotFoundError('Patient not found');

    if (!box.userId || patient.userId !== box.userId) {
      throw new ForbiddenError('Patient is not associated with this device');
    }

    if (!patient.avatarUrl) {
      throw new NotFoundError('Patient face reference not found');
    }

    const referenceBuffer = await this.downloadReferenceImage(patient.avatarUrl);

    const aiResult = await this.faceClient.verify(
      referenceBuffer,
      probeBuf,
      `${patientId}-reference.jpg`,
      args.probeImageOriginalName ?? `${patientId}-probe.jpg`,
    );

    const recorder = new RecordFaceVerification(
      this.patientRepo,
      this.medicineBoxRepo,
      this.faceVerificationRepo,
    );
    const audit = await recorder.execute({
      deviceId,
      patientId,
      verified: aiResult.verified,
      similarity: aiResult.similarity,
    });

    return {
      event: audit.event,
      message: audit.message,
      ai: aiResult,
    };
  }
}
