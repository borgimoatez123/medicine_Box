import type { User } from '@domain/entities/User';

export type PublicUser = Omit<User, 'passwordHash'>;

export const toPublicUser = (user: User): PublicUser => {
  const { passwordHash: _p, ...rest } = user;
  return rest;
};
