import type { Request, Response, NextFunction } from 'express';
import { UnauthorizedError, ForbiddenError } from '@shared/errors/AppError';
import type { JwtPayload, UserRole } from '@shared/types';
import { JwtService } from '@infrastructure/auth/JwtService';

declare module 'express-serve-static-core' {
  interface Request {
    user?: JwtPayload;
  }
}

const extractBearerToken = (header: string | undefined): string | null => {
  if (!header || !header.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
};

export const authenticate = (req: Request, _res: Response, next: NextFunction): void => {
  try {
    const token = extractBearerToken(req.headers.authorization);
    if (!token) {
      throw new UnauthorizedError('No token provided');
    }

    const jwtService = new JwtService();
    const payload = jwtService.verify(token);

    req.user = payload;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireAuth = (req: Request, _res: Response, next: NextFunction): void => {
  authenticate(req, _res, (err?: unknown) => {
    if (err) {
      next(err);
      return;
    }
    if (!req.user) {
      next(new UnauthorizedError('Authentication required'));
      return;
    }
    next();
  });
};

export const requireRole =
  (requiredRole: UserRole) =>
  (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      next(new UnauthorizedError('Authentication required'));
      return;
    }
    if (req.user.role !== requiredRole) {
      next(new ForbiddenError(`Insufficient permissions: required role ${requiredRole}`));
      return;
    }
    next();
  };
