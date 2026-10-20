import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type { IStorageService } from '@domain/repositories/IStorageService';
import { AVATAR_BUCKET } from '@domain/repositories/IStorageService';
import { NotFoundError } from '@shared/errors/AppError';

export type DeletePatientAvatarInput = {
  userId: string;
  patientId: string;
};

export class DeletePatientAvatar {
  constructor(
    private readonly patientRepo: IPatientRepository,
    private readonly storageService: IStorageService,
  ) {}

  public async execute(input: DeletePatientAvatarInput): Promise<void> {
    const patient = await this.patientRepo.findByIdAndUserId(
      input.patientId,
      input.userId,
    );
    if (!patient) throw new NotFoundError('Patient not found');

    const currentUrl = patient.avatarUrl;
    if (!currentUrl) return;

    const storagePath = this.storageService.extractPathFromPublicUrl(
      AVATAR_BUCKET,
      currentUrl,
    );

    await this.patientRepo.update(input.patientId, { avatarUrl: null });

    if (storagePath) {
      try {
        await this.storageService.delete(AVATAR_BUCKET, storagePath);
      } catch {
        /* best-effort; DB already nullified correctly */
      }
    }
  }
}
