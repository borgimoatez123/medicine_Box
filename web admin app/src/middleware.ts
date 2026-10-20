import { NextRequest, NextResponse } from 'next/server';

const AUTH_TOKEN_COOKIE = 'smd_auth_token';
const AUTH_USER_COOKIE = 'smd_auth_user';

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/users/:path*',
    '/medicine-boxes/:path*',
    '/drawers/:path*',
  ],
};

export default function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const token = request.cookies.get(AUTH_TOKEN_COOKIE)?.value;
  const userCookie = request.cookies.get(AUTH_USER_COOKIE)?.value;

  if (!token) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (userCookie) {
    try {
      let user: { role?: string } = {};

      try {
        user = JSON.parse(userCookie);
      } catch {
        try {
          const decoded = atob(userCookie);
          user = JSON.parse(decoded);
        } catch {
          user = {};
        }
      }

      if (user.role && user.role !== 'ADMIN') {
        const loginUrl = new URL('/login', request.url);
        loginUrl.searchParams.set('error', 'admin_required');
        return NextResponse.redirect(loginUrl);
      }
    } catch {
    }
  }

  return NextResponse.next();
}
