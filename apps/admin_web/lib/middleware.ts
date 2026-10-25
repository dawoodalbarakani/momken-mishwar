import { NextResponse, type NextRequest } from "next/server";
import { PAGE_ROLES } from "./roles";
import { parseJwt } from "./auth";

const PROTECTED_PREFIXES = [
  "/",
  "/drivers",
  "/rides",
  "/pricing",
  "/finance",
  "/support",
  "/audit",
];

const AUTH_PATHS = ["/login"];

function userRoles(token: string | null): string[] {
  if (!token) return [];
  try {
    const payload = parseJwt<{ roles?: string[] }>(token);
    return payload?.roles ? [...payload.roles] : [];
  } catch {
    return [];
  }
}

function isAllowed(pathname: string, roles: string[]): boolean {
  const entry = Object.entries(PAGE_ROLES).find(([prefix]) =>
    pathname === prefix || pathname.startsWith(prefix + "/")
  );
  if (!entry) return true;
  return entry[1].some((r) => roles.includes(r));
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get("mishwar_admin_token")?.value ?? null;
  const roles = userRoles(token);

  if (AUTH_PATHS.includes(pathname)) {
    if (token && roles.length > 0) {
      return NextResponse.redirect(new URL("/", request.nextUrl));
    }
    return NextResponse.next();
  }

  const isProtected = PROTECTED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(prefix + "/")
  );

  if (isProtected) {
    if (!token) {
      const url = new URL("/login", request.nextUrl);
      url.searchParams.set("callbackUrl", pathname);
      return NextResponse.redirect(url);
    }
    if (!isAllowed(pathname, roles)) {
      return NextResponse.redirect(new URL("/login?forbidden=1", request.nextUrl));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/", "/drivers/:path*", "/rides/:path*", "/pricing/:path*", "/finance/:path*", "/support/:path*", "/audit/:path*", "/login"],
};
