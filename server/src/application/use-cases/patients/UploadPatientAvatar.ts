import type { IPatientRepository } from '@domain/repositories/IPatientRepository';
import type {
  IStorageService,
} from '@domain/repositories/IStorageService';
import {
  AVATAR_ALLOWED_EXT,
  AVATAR_ALLOWED_MIME,
  AVATAR_BUCKET,
  AVATAR_MAX_BYTES,
} from '@domain/repositories/IStorageService';
import type { Patient } from '@domain/entities/Patient';
import { BadRequestError, NotFoundError } from '@shared/errors/AppError';
import { randomUUID } from 'crypto';

export type UploadPatientAvatarFile = {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
};

export type UploadPatientAvatarInput = {
  userId: string;
  patientId: string;
  file: UploadPatientAvatarFile;
};

const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': 'jpeg',
  'image/png': 'png',
  'image/webp': 'webp',
};

const extOf = (name: string): string => {
  const idx = name.lastIndexOf('.');
  return idx >= 0 ? name.slice(idx).toLowerCase() : '';
};

const validateFile = (f: UploadPatientAvatarFile): { mimeType: string; ext: string } => {
  if (!AVATAR_ALLOWED_MIME.has(f.mimetype)) {
    throw new BadRequestError(
      `Invalid image type: ${f.mimetype}. Allowed: image/jpeg, image/png, image/webp`,
    );
  }
  const ext = extOf(f.originalname);
  if (!AVATAR_ALLOWED_EXT.has(ext)) {
    throw new BadRequestError(
      `Invalid file extension: ${ext || '(none)'}. Allowed: .jpg, .jpeg, .png, .webp`,
    );
  }
  if (f.size > AVATAR_MAX_BYTES) {
    throw new BadRequestError(
      `File too large: ${f.size} bytes. Maximum ${AVATAR_MAX_BYTES} bytes (5 MB).`,
    );
  }
  const normalizedExt = MIME_TO_EXT[f.mimetype];
  return { mimeType: f.mimetype, ext: normalizedExt };
};

export class UploadPatientAvatar {
  constructor(
    private readonly patientRepo: IPatientRepository,
    private readonly storageService: IStorageService,
  ) {}

  public async execute(input: UploadPatientAvatarInput): Promise<Patient> {
    const patient = await this.patientRepo.findByIdAndUserId(
      input.patientId,
      input.userId,
    );
    if (!patient) throw new NotFoundError('Patient not found');

    const { mimeType, ext } = validateFile(input.file);

    const fileName = `${randomUUID()}.${ext}`;
    const storagePath = `patients/${input.patientId}/avatar/${fileName}`;

    const oldAvatarUrl = patient.avatarUrl;
    const oldPath = oldAvatarUrl
      ? this.storageService.extractPathFromPublicUrl(AVATAR_BUCKET, oldAvatarUrl)
      : null;

    const uploaded = await this.storageService.upload(
      AVATAR_BUCKET,
      storagePath,
      input.file.buffer,
      mimeType,
    );

    let updated: Patient;
    try {
      updated = await this.patientRepo.update(input.patientId, {
        avatarUrl: uploaded.publicUrl,
      });
    } catch (dbError) {
      try {
        await this.storageService.delete(AVATAR_BUCKET, storagePath);
      } catch {
        /* swallow; best-effort cleanup. DB error is the root cause to throw. */
      }
      throw dbError;
    }

    if (oldPath) {
      try {
        await this.storageService.delete(AVATAR_BUCKET, oldPath);
      } catch {
        /* best-effort; new avatar is active, orphan is acceptable */
      }
    }

    return updated;
  }
}
