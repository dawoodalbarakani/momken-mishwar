export type Role =
  | "CUSTOMER"
  | "DRIVER"
  | "SUPPORT_AGENT"
  | "OPERATIONS_MANAGER"
  | "FINANCE_MANAGER"
  | "ADMIN"
  | "SUPER_ADMIN";

export const ALL_ROLES: Role[] = [
  "CUSTOMER",
  "DRIVER",
  "SUPPORT_AGENT",
  "OPERATIONS_MANAGER",
  "FINANCE_MANAGER",
  "ADMIN",
  "SUPER_ADMIN",
];

export const PAGE_ROLES: Record<string, Role[]> = {
  "/drivers": ["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"],
  "/rides": ["SUPPORT_AGENT", "OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"],
  "/pricing": ["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"],
  "/finance": ["FINANCE_MANAGER", "ADMIN", "SUPER_ADMIN"],
  "/support": ["SUPPORT_AGENT", "OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"],
  "/audit": ["ADMIN", "SUPER_ADMIN"],
};

export function roleHierarchyIndex(role: Role): number {
  return ALL_ROLES.indexOf(role);
}

export function canAccessPage(role: Role | undefined, pathname: string): boolean {
  if (!role) return false;
  const allowed = PAGE_ROLES[pathname];
  if (!allowed) return true;
  return allowed.includes(role);
}

export function canEscalateTo(from: Role | undefined, to: Role): boolean {
  if (!from) return false;
  const fromIdx = roleHierarchyIndex(from);
  const toIdx = roleHierarchyIndex(to);
  return toIdx <= fromIdx;
}

export function hasRole(role: Role): boolean {
  const stored = typeof localStorage !== "undefined" ? localStorage.getItem("mishwar_admin_user") : null;
  if (stored) {
    try {
      const user = JSON.parse(stored);
      return Array.isArray(user.roles) && user.roles.includes(role);
    } catch {
      return false;
    }
  }
  return false;
}

export function hasAnyRole(roles: Role[]): boolean {
  return roles.some((r) => hasRole(r));
}
