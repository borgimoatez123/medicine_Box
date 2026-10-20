import multer from 'multer';
import { AVATAR_ALLOWED_MIME, AVATAR_MAX_BYTES } from '@domain/repositories/IStorageService';
import { BadRequestError } from '@shared/errors/AppError';

const memoryStorage = multer.memoryStorage();

export const uploadAvatar = multer({
  storage: memoryStorage,
  limits: {
    fileSize: AVATAR_MAX_BYTES,
    files: 1,
    fields: 0,
  },
  fileFilter: (_req, file, cb) => {
    if (!AVATAR_ALLOWED_MIME.has(file.mimetype)) {
      cb(
        new BadRequestError(
          `Invalid image type: ${file.mimetype}. Allowed: image/jpeg, image/png, image/webp`,
        ),
      );
      return;
    }
    cb(null, true);
  },
});

export const avatarUploadSingle = uploadAvatar.single('image');

const PROBE_IMAGE_MAX_BYTES = 8 * 1024 * 1024;
const PROBE_ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/jpg',
  'application/octet-stream',
]);

export const uploadProbeImage = multer({
  storage: memoryStorage,
  limits: {
    fileSize: PROBE_IMAGE_MAX_BYTES,
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    if (!PROBE_ALLOWED_MIME.has(file.mimetype)) {
      cb(
        new BadRequestError(
          `Invalid probe image type: ${file.mimetype}. Allowed: image/jpeg, image/png, image/webp`,
        ),
      );
      return;
    }
    cb(null, true);
  },
});

export const probeImageUploadSingle = uploadProbeImage.single('probe_image');
