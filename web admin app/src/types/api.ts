export type ApiStatus = 'success' | 'fail' | 'error';

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface ApiResponse<T> {
  status: ApiStatus;
  statusCode: number;
  data?: T;
  message?: string;
  meta?: PaginationMeta;
}

export interface ApiError {
  status: ApiStatus;
  statusCode: number;
  message: string;
  errors?: Record<string, string[]>;
}
