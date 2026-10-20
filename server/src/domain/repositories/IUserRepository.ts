import type { User } from '@domain/entities/User';

export type CreateUserData = Omit<User, 'id' | 'createdAt' | 'updatedAt' | 'role'> & {
  role?: User['role'];
};
export type UpdateUserData = Partial<
  Omit<User, 'id' | 'createdAt' | 'updatedAt' | 'passwordHash'>
>;

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  existsByEmail(email: string): Promise<boolean>;
  findAll(): Promise<User[]>;
  create(data: CreateUserData): Promise<User>;
  update(id: string, data: UpdateUserData): Promise<User>;
  updatePassword(id: string, newPasswordHash: string): Promise<User>;
}
