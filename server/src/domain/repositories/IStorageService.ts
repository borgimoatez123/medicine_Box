export type UploadResult = {
  path: string;
  publicUrl: string;
};

export interface IStorageService {
  upload(
    bucket: string,
    path: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<UploadResult>;
  delete(bucket: string, path: string): Promise<void>;
  getPublicUrl(bucket: string, path: string): string;
  extractPathFromPublicUrl(bucket: string, publicUrl: string): string | null;
}

export const AVATAR_BUCKET = 'patient-avatars';
export const AVATAR_MAX_BYTES = 5 * 1024 * 1024;
export const AVATAR_ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);
export const AVATAR_ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp']);
