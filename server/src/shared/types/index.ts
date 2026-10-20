export type UserRole = 'ADMIN' | 'USER';

export interface JwtPayload {
  userId: string;
  role: UserRole;
}

export interface AuthenticatedRequest {
  user: JwtPayload;
}

export type PaginationParams = {
  page?: number;
  limit?: number;
};

export type PaginatedResult<T> = {
  data: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type SuccessResponse<T = undefined> = {
  status: 'success';
  statusCode: number;
  message?: string;
  data?: T;
  meta?: PaginatedResult<never>['meta'];
};
