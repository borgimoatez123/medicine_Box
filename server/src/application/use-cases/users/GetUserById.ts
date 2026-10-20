import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';
import { NotFoundError } from '@shared/errors';

type GetUserByIdInput = {
  id: string;
};

type GetUserByIdOutput = Omit<User, 'passwordHash'>;

export class GetUserById {
  constructor(private readonly userRepo: IUserRepository) {}

  public async execute(input: GetUserByIdInput): Promise<GetUserByIdOutput> {
    const user = await this.userRepo.findById(input.id);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    const { passwordHash: _p, ...rest } = user;
    return rest;
  }
}
