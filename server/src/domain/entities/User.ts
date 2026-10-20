export type UserRole = 'ADMIN' | 'USER';

export interface User {
  id: string;
  firstName: string | null;
  lastName: string | null;
  email: string;
  passwordHash: string;
  phone: string | null;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}
