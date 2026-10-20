import type { Request, Response, NextFunction } from 'express';
import { AppError, BadRequestError } from '@shared/errors';

interface ErrorResponse {
  status: string;
  statusCode: number;
  message: string;
  stack?: string;
}

const normalizeError = (error: Error | AppError): AppError => {
  if (error instanceof AppError) return error;

  const anyError = error as Error & { code?: string; name?: string; field?: string };
  if (anyError.name === 'MulterError') {
    const code = anyError.code ?? 'UNKNOWN_MULTER';
    const field = anyError.field ? ` (field: ${anyError.field})` : '';
    const messageMap: Record<string, string> = {
      LIMIT_FILE_SIZE: 'Uploaded file is too large.',
      LIMIT_FILE_COUNT: 'Too many files uploaded. A single file is required.',
      LIMIT_UNEXPECTED_FILE: `Unexpected file field${field}. Check the file field name in your request.`,
      LIMIT_PART_COUNT: 'Too many parts in the multipart request.',
      LIMIT_FIELDS: 'Too many form fields in the multipart request.',
    };
    return new BadRequestError(
      `${messageMap[code] ?? `Upload error: ${code}`}${field}`,
    );
  }

  return new AppError(error.message || 'Internal server error', 500);
};

export const errorMiddleware = (
  error: Error | AppError,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  const isDev = process.env.NODE_ENV === 'development';
  const appErr = normalizeError(error);

  const statusCode = appErr.statusCode;
  const status = statusCode >= 400 && statusCode < 500 ? 'fail' : 'error';
  const message = appErr.isOperational || isDev ? appErr.message : 'Something went wrong';

  const response: ErrorResponse = {
    status,
    statusCode,
    message,
  };

  if (isDev && error.stack) {
    response.stack = error.stack;
  }

  res.status(statusCode).json(response);
};
