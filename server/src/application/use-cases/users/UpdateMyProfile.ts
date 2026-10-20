import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';
import { NotFoundError, ConflictError } from '@shared/errors';

type UpdateMyProfileInput = {
  userId: string;
  firstName?: string | null;
  lastName?: string | null;
  phone?: string | null;
  email?: string;
};

type UpdateMyProfileOutput = Omit<User, 'passwordHash'>;

export class UpdateMyProfile {
  constructor(private readonly userRepo: IUserRepository) {}

  public async execute(input: UpdateMyProfileInput): Promise<UpdateMyProfileOutput> {
    const existing = await this.userRepo.findById(input.userId);
    if (!existing) {
      throw new NotFoundError('User not found');
    }

    if (input.email !== undefined && input.email !== existing.email) {
      const duplicate = await this.userRepo.findByEmail(input.email);
      if (duplicate) {
        throw new ConflictError('Email is already in use');
      }
    }

    const patch = {
      firstName: input.firstName !== undefined ? input.firstName : existing.firstName,
      lastName: input.lastName !== undefined ? input.lastName : existing.lastName,
      phone: input.phone !== undefined ? input.phone : existing.phone,
      email: input.email !== undefined ? input.email : existing.email,
    };

    const user = await this.userRepo.update(input.userId, patch);

    const { passwordHash: _passwordHash, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }
}
