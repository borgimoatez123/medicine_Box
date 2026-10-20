import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';
import { NotFoundError } from '@shared/errors';

type GetMyProfileInput = {
  userId: string;
};

type GetMyProfileOutput = Omit<User, 'passwordHash'>;

export class GetMyProfile {
  constructor(private readonly userRepo: IUserRepository) {}

  public async execute(input: GetMyProfileInput): Promise<GetMyProfileOutput> {
    const user = await this.userRepo.findById(input.userId);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    const { passwordHash: _passwordHash, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }
}
