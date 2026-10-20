import jwt from 'jsonwebtoken';
import { UnauthorizedError } from '@shared/errors';
import type { JwtPayload, UserRole } from '@shared/types';

export class JwtService {
  private readonly secret: string;
  private readonly expiresIn: string;

  constructor(
    secret: string = process.env.JWT_SECRET ?? '',
    expiresIn: string = process.env.JWT_EXPIRES_IN ?? '24h',
  ) {
    this.secret = secret;
    this.expiresIn = expiresIn;
  }

  sign(params: { userId: string; role: UserRole }): string {
    const payload: JwtPayload = { userId: params.userId, role: params.role };
    return jwt.sign(payload, this.secret, {
      expiresIn: this.expiresIn as jwt.SignOptions['expiresIn'],
    });
  }

  verify(token: string): JwtPayload {
    try {
      const decoded = jwt.verify(token, this.secret) as jwt.JwtPayload;
      if (!decoded || typeof decoded.userId !== 'string' || (decoded.role !== 'ADMIN' && decoded.role !== 'USER')) {
        throw new UnauthorizedError('Invalid token');
      }
      return {
        userId: decoded.userId,
        role: decoded.role as UserRole,
      };
    } catch (err) {
      if (err instanceof jwt.TokenExpiredError) {
        throw new UnauthorizedError('Expired token');
      }
      if (err instanceof jwt.JsonWebTokenError) {
        throw new UnauthorizedError('Invalid token');
      }
      throw err;
    }
  }
}
