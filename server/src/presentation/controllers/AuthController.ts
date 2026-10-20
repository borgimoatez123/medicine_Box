import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import { registerSchema, loginSchema } from '@presentation/validators/auth.validator';
import { RegisterUser } from '@application/use-cases/auth/RegisterUser';
import { LoginUser } from '@application/use-cases/auth/LoginUser';
import { PrismaUserRepository } from '@infrastructure/database/prisma/repositories/PrismaUserRepository';
import { PasswordService } from '@infrastructure/auth/PasswordService';
import { JwtService } from '@infrastructure/auth/JwtService';

const formatZodErrors = (error: ZodError): string => {
  return error.issues.map((issue) => issue.message).join(', ');
};

export const AuthController = {
  async register(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = registerSchema.safeParse(req.body);

      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const { email, password, firstName, lastName } = validated.data;

      const userRepository = new PrismaUserRepository();
      const passwordService = new PasswordService();
      const jwtService = new JwtService();
      const registerUser = new RegisterUser(userRepository, passwordService, jwtService);

      const result = await registerUser.execute({
        email,
        password,
        firstName,
        lastName,
      });

      res.status(HTTP_STATUS.CREATED).json({
        status: 'success',
        statusCode: HTTP_STATUS.CREATED,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = loginSchema.safeParse(req.body);

      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const { email, password } = validated.data;

      const userRepository = new PrismaUserRepository();
      const passwordService = new PasswordService();
      const jwtService = new JwtService();
      const loginUser = new LoginUser(userRepository, passwordService, jwtService);

      const result = await loginUser.execute({
        email,
        password,
      });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },
};
