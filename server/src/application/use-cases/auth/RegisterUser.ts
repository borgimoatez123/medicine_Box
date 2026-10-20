import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';
import type { UserRole } from '@shared/types';
import { BadRequestError } from '@shared/errors';

interface PasswordService {
  hash(password: string): Promise<string>;
  verify(plain: string, hash: string): Promise<boolean>;
}

interface JwtService {
  sign(params: { userId: string; role: UserRole }): string;
}

type RegisterUserInput = {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
};

type RegisterUserOutput = {
  user: Omit<User, 'passwordHash'>;
  token: string;
};

export class RegisterUser {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly passwordSvc: PasswordService,
    private readonly jwtSvc: JwtService,
  ) {}

  public async execute(input: RegisterUserInput): Promise<RegisterUserOutput> {
    const existing = await this.userRepo.findByEmail(input.email);
    if (existing) {
      throw new BadRequestError('Email already registered');
    }

    const passwordHash = await this.passwordSvc.hash(input.password);

    const user = await this.userRepo.create({
      email: input.email,
      passwordHash,
      firstName: input.firstName ?? null,
      lastName: input.lastName ?? null,
      phone: null,
    });

    const token = this.jwtSvc.sign({ userId: user.id, role: user.role });

    const { passwordHash: _passwordHash, ...userWithoutPassword } = user;

    return {
      user: userWithoutPassword,
      token,
    };
  }
}
