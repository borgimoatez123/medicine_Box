import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';

type GetUsersOutput = Omit<User, 'passwordHash'>[];

export class GetUsers {
  constructor(private readonly userRepo: IUserRepository) {}

  public async execute(): Promise<GetUsersOutput> {
    const rows = await this.userRepo.findAll();
    return rows.map((u) => {
      const { passwordHash: _p, ...rest } = u;
      return rest;
    });
  }
}
