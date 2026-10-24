const TOKEN_KEY = "mishwar_admin_token";
const USER_KEY = "mishwar_admin_user";

export interface JwtPayload {
  sub?: string;
  email?: string;
  roles?: string[];
  iat?: number;
  exp?: number;
}

export interface AdminUser {
  id: string;
  email: string;
  roles: string[];
}

export function getToken(): string | null {
  if (typeof document === "undefined") return null;
  const match = document.cookie.match(/(?:^|; )\s*${TOKEN_KEY}=([^;]*)/);
  return match ? decodeURIComponent(match[1]) : null;
}

export function setToken(token: string, options: { path?: string; maxAge?: number } = {}): void {
  if (typeof document === "undefined") return;
  const parts = [`${TOKEN_KEY}=${encodeURIComponent(token)}`, "Path=/"];
  if (options.maxAge) parts.push(`Max-Age=${options.maxAge}`);
  if (options.path) parts.push(`Path=${options.path}`);
  parts.push("SameSite=Lax");
  if (location.protocol === "https:") parts.push("Secure");
  document.cookie = parts.join("; ");
}

export function removeToken(): void {
  if (typeof document === "undefined") return;
  document.cookie = `${TOKEN_KEY}=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT`;
}

export function setUser(user: AdminUser): void {
  if (typeof window === "undefined") return;
  try { localStorage.setItem(USER_KEY, JSON.stringify(user)); } catch { /* ignore */ }
}

export function getUser(): AdminUser | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as AdminUser) : null;
  } catch {
    return null;
  }
}

export function removeUser(): void {
  if (typeof window === "undefined") return;
  try { localStorage.removeItem(USER_KEY); } catch { /* ignore */ }
}

export function parseJwt<T = JwtPayload>(token: string): T | null {
  try {
    const base64 = token.split(".")[1];
    if (!base64) return null;
    const json = decodeURIComponent(
      atob(base64.replace(/-/g, "+").replace(/_/g, "/"))
        .split("")
        .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
        .join("")
    );
    return JSON.parse(json) as T;
  } catch {
    return null;
  }
}

export function getUserRoles(): string[] {
  const token = getToken();
  if (!token) return [];
  const payload = parseJwt<JwtPayload>(token);
  return payload?.roles ? [...payload.roles] : [];
}

export function getUserFromToken(): AdminUser | null {
  const token = getToken();
  if (!token) return null;
  const payload = parseJwt<JwtPayload & { email?: string; sub?: string }>(token);
  if (!payload) return null;
  return {
    id: payload.sub ?? "",
    email: payload.email ?? "",
    roles: payload.roles ?? [],
  };
}

export function isAuthenticated(): boolean {
  const token = getToken();
  if (!token) return false;
  const payload = parseJwt<JwtPayload>(token);
  if (payload?.exp && payload.exp * 1000 <= Date.now()) {
    removeToken();
    removeUser();
    return false;
  }
  return true;
}

export function hasRole(role: string): boolean {
  return getUserRoles().includes(role);
}

export function hasAnyRole(roles: string[]): boolean {
  const userRoles = getUserRoles();
  return roles.some((r) => userRoles.includes(r));
}

export function logout(): void {
  removeToken();
  removeUser();
  if (typeof window !== "undefined") {
    window.location.replace("/login");
  }
}
