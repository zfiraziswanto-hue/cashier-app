import { NextResponse, NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  const token = req.cookies.get('token')?.value;
  const userCookie = req.cookies.get('user')?.value;
  const user = userCookie ? JSON.parse(userCookie) : null;
  const path = req.nextUrl.pathname;

  // Public routes (no auth required)
  const publicRoutes = ['/login', '/register'];
  if (publicRoutes.some((p) => path.startsWith(p))) {
    // Redirect to dashboard if already logged in
    if (token && user) {
      const role = user.role || 'user';
      const redirectPath = role === 'admin' ? '/admin/dashboard' : role === 'kasir' ? '/kasir/pos' : '/katalog';
      return NextResponse.redirect(new URL(redirectPath, req.url));
    }
    return NextResponse.next();
  }

  // Protected routes
  if (!token || !user) {
    return NextResponse.redirect(new URL('/login', req.url));
  }

  const role = user.role || 'user';

  // Role-based route protection
  if (path.startsWith('/admin') && role !== 'admin') {
    return NextResponse.redirect(new URL(role === 'kasir' ? '/kasir/pos' : '/katalog', req.url));
  }

  if (path.startsWith('/kasir') && role !== 'kasir' && role !== 'admin') {
    return NextResponse.redirect(new URL(role === 'admin' ? '/admin/dashboard' : '/katalog', req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
