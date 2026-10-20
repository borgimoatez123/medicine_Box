import type { IUserRepository } from '@domain/repositories/IUserRepository';
import { BadRequestError, NotFoundError, UnauthorizedError } from '@shared/errors';

interface PasswordService {
  hash(password: string): Promise<string>;
  verify(plain: string, hash: string): Promise<boolean>;
}

type ChangePasswordInput = {
  userId: string;
  currentPassword: string;
  newPassword: string;
};

type ChangePasswordOutput = {
  success: true;
};

export class ChangePassword {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly passwordSvc: PasswordService,
  ) {}

  public async execute(input: ChangePasswordInput): Promise<ChangePasswordOutput> {
    if (input.newPassword.length < 8) {
      throw new BadRequestError('New password must be at least 8 characters long');
    }

    const user = await this.userRepo.findById(input.userId);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    const isCurrentValid = await this.passwordSvc.verify(input.currentPassword, user.passwordHash);
    if (!isCurrentValid) {
      throw new UnauthorizedError('Current password is incorrect');
    }

    const newPasswordHash = await this.passwordSvc.hash(input.newPassword);
    await this.userRepo.updatePassword(input.userId, newPasswordHash);

    return { success: true };
  }
}
