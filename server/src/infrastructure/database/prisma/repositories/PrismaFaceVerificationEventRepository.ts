import type {
  IFaceVerificationEventRepository,
  CreateFaceVerificationEventData,
} from '@domain/repositories/IFaceVerificationEventRepository';
import type { FaceVerificationEvent } from '@domain/entities/FaceVerificationEvent';
import { prisma } from '@infrastructure/database/prisma/client';

export class PrismaFaceVerificationEventRepository
  implements IFaceVerificationEventRepository
{
  async create(
    data: CreateFaceVerificationEventData,
  ): Promise<FaceVerificationEvent> {
    const row = await prisma.faceVerificationEvent.create({
      data: {
        deviceId: data.deviceId,
        patientId: data.patientId,
        verified: data.verified,
        similarity: data.similarity ?? null,
        timestamp: data.timestamp ?? new Date(),
      },
    });
    return this.toDomain(row);
  }

  async countByPatientId(patientId: string): Promise<number> {
    return prisma.faceVerificationEvent.count({ where: { patientId } });
  }

  private toDomain(model: {
    id: string;
    deviceId: string | null;
    patientId: string;
    verified: boolean;
    similarity: number | null;
    timestamp: Date;
  }): FaceVerificationEvent {
    return {
      id: model.id,
      deviceId: model.deviceId,
      patientId: model.patientId,
      verified: model.verified,
      similarity: model.similarity,
      timestamp: model.timestamp,
    };
  }
}
