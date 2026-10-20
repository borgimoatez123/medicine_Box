import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User } from '@domain/entities/User';
import type { UserRole } from '@shared/types';
import { UnauthorizedError } from '@shared/errors';

interface PasswordService {
  hash(password: string): Promise<string>;
  verify(plain: string, hash: string): Promise<boolean>;
}

interface JwtService {
  sign(params: { userId: string; role: UserRole }): string;
}

type LoginUserInput = {
  email: string;
  password: string;
};

type LoginUserOutput = {
  user: Omit<User, 'passwordHash'>;
  token: string;
};

export class LoginUser {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly passwordSvc: PasswordService,
    private readonly jwtSvc: JwtService,
  ) {}

  public async execute(input: LoginUserInput): Promise<LoginUserOutput> {
    const user = await this.userRepo.findByEmail(input.email);
    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const isValid = await this.passwordSvc.verify(input.password, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const token = this.jwtSvc.sign({ userId: user.id, role: user.role });

    const { passwordHash: _passwordHash, ...userWithoutPassword } = user;

    return {
      user: userWithoutPassword,
      token,
    };
  }
}
