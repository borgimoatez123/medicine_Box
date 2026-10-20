import type { Request, Response, NextFunction } from 'express';
import type { ZodError } from 'zod';
import { BadRequestError, UnauthorizedError } from '@shared/errors/AppError';
import { HTTP_STATUS } from '@shared/constants';
import { GetMyProfile } from '@application/use-cases/users/GetMyProfile';
import { UpdateMyProfile } from '@application/use-cases/users/UpdateMyProfile';
import { ChangePassword } from '@application/use-cases/users/ChangePassword';
import { GetUsers } from '@application/use-cases/users/GetUsers';
import { GetUserById } from '@application/use-cases/users/GetUserById';
import { PrismaUserRepository } from '@infrastructure/database/prisma/repositories/PrismaUserRepository';
import { PasswordService } from '@infrastructure/auth/PasswordService';
import {
  updateMyProfileSchema,
  changePasswordSchema,
} from '@presentation/validators/user.validator';

const formatZodErrors = (error: ZodError): string =>
  error.issues.map((issue) => issue.message).join(', ');

export const UserController = {
  async getMe(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }

    const userId = req.user.userId;
    const userRepository = new PrismaUserRepository();
    const getMyProfile = new GetMyProfile(userRepository);

    const result = await getMyProfile.execute({ userId });

    res.status(HTTP_STATUS.OK).json({
      status: 'success',
      statusCode: HTTP_STATUS.OK,
      data: result,
    });
    } catch (error) {
      next(error);
    }
  },

  async updateMe(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const validated = updateMyProfileSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const userId = req.user.userId;

      const userRepository = new PrismaUserRepository();
      const updateMyProfile = new UpdateMyProfile(userRepository);

      const result = await updateMyProfile.execute({
        userId,
        ...validated.data,
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

  async changePassword(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const validated = changePasswordSchema.safeParse(req.body);
      if (!validated.success) {
        throw new BadRequestError(formatZodErrors(validated.error));
      }

      const userId = req.user.userId;
      const { currentPassword, newPassword } = validated.data;

      const userRepository = new PrismaUserRepository();
      const passwordService = new PasswordService();
      const changePassword = new ChangePassword(userRepository, passwordService);

      const result = await changePassword.execute({
        userId,
        currentPassword,
        newPassword,
      });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data: result,
        message: 'Password changed successfully',
      });
    } catch (error) {
      next(error);
    }
  },

  async listUsers(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }

    const userRepository = new PrismaUserRepository();
    const getUsers = new GetUsers(userRepository);
    const data = await getUsers.execute();

    res.status(HTTP_STATUS.OK).json({
      status: 'success',
      statusCode: HTTP_STATUS.OK,
      data,
    });
    } catch (error) {
      next(error);
    }
  },

  async getUserById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        throw new UnauthorizedError('Authentication required');
      }

      const { id } = req.params as { id: string };

      const userRepository = new PrismaUserRepository();
      const getUserById = new GetUserById(userRepository);
      const data = await getUserById.execute({ id });

      res.status(HTTP_STATUS.OK).json({
        status: 'success',
        statusCode: HTTP_STATUS.OK,
        data,
      });
    } catch (error) {
      next(error);
    }
  },
};
