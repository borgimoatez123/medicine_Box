import { PAGINATION } from '@shared/constants';
import type { PaginationParams, PaginatedResult } from '@shared/types';

export const calculatePagination = (
  params: PaginationParams,
): { skip: number; take: number; page: number; limit: number } => {
  const page = Math.max(1, params.page ?? PAGINATION.DEFAULT_PAGE);
  const limit = Math.min(
    Math.max(1, params.limit ?? PAGINATION.DEFAULT_LIMIT),
    PAGINATION.MAX_LIMIT,
  );
  const skip = (page - 1) * limit;
  return { skip, take: limit, page, limit };
};

export const buildPaginatedResult = <T>(
  data: T[],
  total: number,
  page: number,
  limit: number,
): PaginatedResult<T> => ({
  data,
  meta: {
    page,
    limit,
    total,
    totalPages: Math.ceil(total / limit) || 0,
  },
});

export const asyncHandler =
  <TArgs extends unknown[], TReturn>(fn: (...args: TArgs) => Promise<TReturn>) =>
  (...args: TArgs): Promise<TReturn> =>
    Promise.resolve(fn(...args));
