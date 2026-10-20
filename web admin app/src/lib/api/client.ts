import { getToken, clearAuth } from '@/lib/auth/storage';
import { maskSensitive } from '@/lib/utils';
import type { ApiResponse } from '@/types';

const rawBaseUrl = process.env.NEXT_PUBLIC_API_URL || '';
const normalizedEnvUrl = rawBaseUrl.endsWith('/')
  ? rawBaseUrl.slice(0, -1)
  : rawBaseUrl;

const isBrowser = typeof window !== 'undefined';

const LIKELY_LOCAL_PROXY = (() => {
  if (!normalizedEnvUrl) return true;
  try {
    const u = new URL(normalizedEnvUrl);
    const host = u.hostname.toLowerCase();
    return host === 'localhost' || host === '127.0.0.1' || host === '[::1]';
  } catch {
    return false;
  }
})();

const baseUrl = isBrowser && LIKELY_LOCAL_PROXY ? '/api' : normalizedEnvUrl;

function joinUrl(base: string, endpoint: string): string {
  if (!base) {
    return endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
  }
  const basePart = base.endsWith('/') ? base.slice(0, -1) : base;
  const endpointPart = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
  return `${basePart}${endpointPart}`;
}

export class ApiError extends Error {
  statusCode: number;
  errors?: Record<string, string[]>;

  constructor(
    statusCode: number,
    message: string,
    errors?: Record<string, string[]>
  ) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
    this.errors = errors;
  }
}

interface RequestOptions {
  body?: any;
  params?: Record<string, any>;
  headers?: Record<string, string>;
  auth?: boolean;
}

async function request<T>(
  method: string,
  endpoint: string,
  options: RequestOptions = {}
): Promise<T> {
  const { body, params, headers: customHeaders, auth = true } = options;

  let url = joinUrl(baseUrl || '', endpoint);

  if (params) {
    const searchParams = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        searchParams.append(key, String(value));
      }
    }
    const queryString = searchParams.toString();
    if (queryString) {
      url += `?${queryString}`;
    }
  }

  const headers: Record<string, string> = {
    ...customHeaders,
  };

  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  if (auth) {
    const token = getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
  }

  const config: RequestInit = {
    method,
    headers,
  };

  if (body !== undefined) {
    config.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, config);

    if (response.status === 204) {
      return null as T;
    }

    let responseData: ApiResponse<any> | null = null;
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      responseData = await response.json();
    }

    if (response.ok) {
      if (responseData && 'data' in responseData) {
        return responseData.data as T;
      }
      return (responseData as unknown as T) || (null as T);
    }

    const safeResponseData = maskSensitive(responseData);

    switch (response.status) {
      case 401:
        clearAuth();
        throw new ApiError(
          401,
          (safeResponseData as any)?.message ||
            'Session expired. Please login again.'
        );
      case 403:
        throw new ApiError(403, 'Insufficient permissions');
      case 404:
        throw new ApiError(404, 'Resource not found');
      case 409:
        throw new ApiError(
          409,
          (safeResponseData as any)?.message || 'Conflict'
        );
      case 400:
        throw new ApiError(
          400,
          (safeResponseData as any)?.message || 'Validation error',
          (safeResponseData as any)?.errors
        );
      case 500:
        throw new ApiError(500, 'Server error. Please try again later.');
      default:
        throw new ApiError(
          response.status,
          (safeResponseData as any)?.message ||
            `Request failed with status ${response.status}`
        );
    }
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    if (
      error instanceof TypeError &&
      (error.message.includes('fetch') ||
        error.message.includes('Failed to fetch') ||
        error.message.includes('NetworkError'))
    ) {
      const maskedUrl = maskSensitive({ url });
      console.error(
        `[API] Network failure (${method} ${maskedUrl.url}):`,
        error.message
      );
      throw new ApiError(
        0,
        `Cannot reach backend at ${baseUrl || 'API URL not set'} (${method} ${endpoint}). ` +
          `Admin UI proxies /api → ${normalizedEnvUrl || 'http://localhost:3000/api'} via Next.js rewrites. ` +
          `Verify: (1) backend is running on port 3000; (2) Admin UI runs on ports 3001–3005 (npm run dev uses port 3002); ` +
          `(3) NEXT_PUBLIC_API_URL in .env.local points to your backend URL.`
      );
    }
    const maskedError = maskSensitive({ error });
    console.error('API request error:', maskedError);
    throw new ApiError(0, 'An unexpected error occurred.');
  }
}

export const apiClient = {
  get: <T>(endpoint: string, options?: Omit<RequestOptions, 'body'>) =>
    request<T>('GET', endpoint, options),

  post: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>('POST', endpoint, options),

  patch: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>('PATCH', endpoint, options),

  delete: <T>(endpoint: string, options?: Omit<RequestOptions, 'body'>) =>
    request<T>('DELETE', endpoint, options),
};
