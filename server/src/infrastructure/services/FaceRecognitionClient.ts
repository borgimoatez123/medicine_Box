import { InternalServerError, BadRequestError, NotFoundError } from '@shared/errors';

export type FaceVerifyResult = {
  verified: boolean;
  similarity: number;
  threshold: number;
  referenceFaceDetected?: boolean;
  probeFaceDetected?: boolean;
};

export type FaceVerifyErrorCode =
  | 'REFERENCE_FACE_NOT_FOUND'
  | 'PROBE_FACE_NOT_FOUND'
  | 'MULTIPLE_FACES_DETECTED'
  | 'INVALID_IMAGE'
  | 'REFERENCE_IMAGE_TOO_LARGE'
  | 'PROBE_IMAGE_TOO_LARGE'
  | 'FACE_ENGINE_NOT_READY'
  | 'VERIFICATION_INTERNAL_ERROR'
  | 'FACE_SERVICE_UNAVAILABLE'
  | 'FACE_SERVICE_MISCONFIGURED';

export class FaceVerificationError extends BadRequestError {
  public readonly code: FaceVerifyErrorCode;
  constructor(code: FaceVerifyErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = 'FaceVerificationError';
  }
}

export class FaceServiceUnavailableError extends InternalServerError {
  public readonly code: FaceVerifyErrorCode = 'FACE_SERVICE_UNAVAILABLE';
  constructor(message: string) {
    super(message);
    this.name = 'FaceServiceUnavailableError';
  }
}

const buildUserMessage = (code: FaceVerifyErrorCode, raw: string): string => {
  switch (code) {
    case 'REFERENCE_FACE_NOT_FOUND':
      return 'No face detected in the patient reference photo. Please upload a clear portrait of the patient first.';
    case 'PROBE_FACE_NOT_FOUND':
      return 'No face detected in the camera image. Please ensure your face is clearly visible and try again.';
    case 'MULTIPLE_FACES_DETECTED':
      return 'Multiple faces were detected. Only one person should be visible during verification.';
    case 'INVALID_IMAGE':
      return 'The captured image is invalid or corrupted. Please try again.';
    case 'REFERENCE_IMAGE_TOO_LARGE':
    case 'PROBE_IMAGE_TOO_LARGE':
      return 'The image file is too large. Please use a smaller picture and try again.';
    case 'FACE_ENGINE_NOT_READY':
      return 'The face verification service is starting up. Please try again in a moment.';
    case 'VERIFICATION_INTERNAL_ERROR':
      return 'Face verification encountered an internal error. Please try again.';
    case 'FACE_SERVICE_UNAVAILABLE':
      return 'Unable to reach the face verification service. Please try again later.';
    case 'FACE_SERVICE_MISCONFIGURED':
      return 'The face verification service is not configured correctly. Please contact support.';
    default:
      return raw || 'Face verification failed. Please try again.';
  }
};

const MAX_IMAGES_BYTES = 8 * 1024 * 1024;

export class FaceRecognitionClient {
  private readonly baseUrl: string;

  constructor(baseUrl?: string) {
    const configured = (baseUrl ?? process.env.FACE_SERVICE_URL ?? '').trim().replace(/\/$/, '');
    this.baseUrl = configured;
  }

  public isConfigured(): boolean {
    return this.baseUrl.length > 0;
  }

  private assertConfigured(): void {
    if (!this.isConfigured()) {
      throw new FaceVerificationError(
        'FACE_SERVICE_MISCONFIGURED',
        buildUserMessage('FACE_SERVICE_MISCONFIGURED', ''),
      );
    }
  }

  public async verify(
    referenceImage: Buffer,
    probeImage: Buffer,
    referenceName = 'reference.jpg',
    probeName = 'probe.jpg',
  ): Promise<FaceVerifyResult> {
    this.assertConfigured();

    if (!referenceImage || referenceImage.length === 0) {
      throw new FaceVerificationError(
        'INVALID_IMAGE',
        buildUserMessage('INVALID_IMAGE', 'reference image empty'),
      );
    }
    if (!probeImage || probeImage.length === 0) {
      throw new FaceVerificationError(
        'INVALID_IMAGE',
        buildUserMessage('INVALID_IMAGE', 'probe image empty'),
      );
    }
    if (referenceImage.length > MAX_IMAGES_BYTES) {
      throw new FaceVerificationError(
        'REFERENCE_IMAGE_TOO_LARGE',
        buildUserMessage('REFERENCE_IMAGE_TOO_LARGE', ''),
      );
    }
    if (probeImage.length > MAX_IMAGES_BYTES) {
      throw new FaceVerificationError(
        'PROBE_IMAGE_TOO_LARGE',
        buildUserMessage('PROBE_IMAGE_TOO_LARGE', ''),
      );
    }

    const endpoint = `${this.baseUrl}/face/verify`;

    let response: Response;
    try {
      const formData = new FormData();
      const refBlob = new Blob([referenceImage], { type: 'image/jpeg' });
      const probeBlob = new Blob([probeImage], { type: 'image/jpeg' });
      formData.set('reference_image', refBlob, referenceName);
      formData.set('probe_image', probeBlob, probeName);

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 30_000);
      try {
        response = await fetch(endpoint, {
          method: 'POST',
          body: formData as never,
          signal: controller.signal,
        });
      } finally {
        clearTimeout(timeout);
      }
    } catch (error) {
      const isAbort = error instanceof DOMException && error.name === 'AbortError';
      const message = isAbort
        ? 'Face verification request timed out. Please try again.'
        : `Unable to connect to the face verification service: ${error instanceof Error ? error.message : String(error)}`;
      throw new FaceServiceUnavailableError(message);
    }

    const text = await response.text();
    let data: Record<string, unknown> | null = null;
    try {
      data = text.length > 0 ? (JSON.parse(text) as Record<string, unknown>) : null;
    } catch {
      data = null;
    }

    if (response.status >= 200 && response.status < 300) {
      if (!data) {
        throw new InternalServerError('Face verification service returned an empty response.');
      }
      const verified = Boolean(data.verified);
      const similarity = Number(data.similarity);
      const threshold = Number(data.threshold);
      if (!Number.isFinite(similarity) || !Number.isFinite(threshold)) {
        throw new InternalServerError(
          'Face verification service returned invalid similarity/threshold values.',
        );
      }
      const result: FaceVerifyResult = {
        verified,
        similarity,
        threshold,
      };
      if (typeof data.reference_face_detected === 'boolean') {
        result.referenceFaceDetected = data.reference_face_detected;
      }
      if (typeof data.probe_face_detected === 'boolean') {
        result.probeFaceDetected = data.probe_face_detected;
      }
      return result;
    }

    let code: FaceVerifyErrorCode = 'VERIFICATION_INTERNAL_ERROR';
    let serverMessage: string | undefined;
    if (data && typeof data.detail === 'object' && data.detail !== null) {
      const detail = data.detail as Record<string, unknown>;
      if (typeof detail.code === 'string') {
        code = detail.code as FaceVerifyErrorCode;
      }
      if (typeof detail.message === 'string') {
        serverMessage = detail.message;
      }
    } else if (typeof data?.code === 'string') {
      code = data.code as FaceVerifyErrorCode;
      if (typeof (data as { message?: unknown }).message === 'string') {
        serverMessage = (data as { message: string }).message;
      }
    }

    const userMessage = buildUserMessage(code, serverMessage ?? text);

    if (code === 'REFERENCE_FACE_NOT_FOUND') {
      throw new NotFoundError(userMessage);
    }
    if (
      code === 'FACE_ENGINE_NOT_READY' ||
      code === 'FACE_SERVICE_UNAVAILABLE' ||
      response.status >= 500
    ) {
      throw new FaceServiceUnavailableError(userMessage);
    }
    throw new FaceVerificationError(code, userMessage);
  }
}
