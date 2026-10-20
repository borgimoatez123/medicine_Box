import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
} from '@shared/errors';

export type GetPatientFaceReferenceResult = {
  patientId: string;
  faceReference: {
    url: string;
    updatedAt: Date;
  };
};

export class GetPatientFaceReference {
  constructor(
    private readonly patientRepo: IPatientRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
  ) {}

  async execute(
    patientId: string,
    requestingDeviceId: string,
  ): Promise<GetPatientFaceReferenceResult> {
    const p = (patientId ?? '').trim();
    const d = (requestingDeviceId ?? '').trim();
    if (!p) throw new BadRequestError('patientId is required');
    if (!d) throw new BadRequestError('deviceId is required');

    const patient = await this.patientRepo.findById(p);
    if (!patient) throw new NotFoundError('Patient not found');

    const box = await this.medicineBoxRepo.findByDeviceId(d);
    if (!box) throw new NotFoundError('Device not found');

    if (!box.userId || patient.userId !== box.userId) {
      throw new ForbiddenError('Patient is not associated with this device');
    }

    if (!patient.avatarUrl) {
      throw new NotFoundError('Patient face reference not found');
    }

    return {
      patientId: patient.id,
      faceReference: {
        url: patient.avatarUrl,
        updatedAt: patient.updatedAt,
      },
    };
  }
}
