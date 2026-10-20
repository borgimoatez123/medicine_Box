import type { IUserRepository, CreateUserData, UpdateUserData } from '@domain/repositories/IUserRepository';
import type { User, UserRole } from '@domain/entities/User';
import { prisma } from '@infrastructure/database/prisma/client';

export class PrismaUserRepository implements IUserRepository {
  async findById(id: string): Promise<User | null> {
    const user = await prisma.user.findUnique({ where: { id } });
    return user ? this.toDomain(user) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const user = await prisma.user.findUnique({ where: { email } });
    return user ? this.toDomain(user) : null;
  }

  async existsByEmail(email: string): Promise<boolean> {
    const count = await prisma.user.count({ where: { email } });
    return count > 0;
  }

  async findAll(): Promise<User[]> {
    const rows = await prisma.user.findMany({ orderBy: { createdAt: 'desc' } });
    return rows.map((r) => this.toDomain(r));
  }

  async create(data: CreateUserData): Promise<User> {
    const user = await prisma.user.create({ data });
    return this.toDomain(user);
  }

  async update(id: string, data: UpdateUserData): Promise<User> {
    const user = await prisma.user.update({ where: { id }, data });
    return this.toDomain(user);
  }

  async updatePassword(id: string, newPasswordHash: string): Promise<User> {
    const user = await prisma.user.update({
      where: { id },
      data: { passwordHash: newPasswordHash },
    });
    return this.toDomain(user);
  }

  private toDomain(model: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    email: string;
    passwordHash: string;
    phone: string | null;
    role: UserRole;
    createdAt: Date;
    updatedAt: Date;
  }): User {
    return {
      id: model.id,
      firstName: model.firstName,
      lastName: model.lastName,
      email: model.email,
      passwordHash: model.passwordHash,
      phone: model.phone,
      role: model.role,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    };
  }
}
