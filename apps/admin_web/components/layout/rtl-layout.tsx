"use strict";

import { useState } from "react";
import Link from "next/link";
import { useSession } from "@/components/providers/session-provider";
import { hasAnyRole } from "@/lib/auth";
import { LogOut, Menu, X, Sidebar, LayoutDashboard, Truck, CreditCard, Users, Headset, ShieldAlert, Percent, Settings } from "lucide-react";

const navItems = [
  { key: "dashboard", label: "لوحة التحكم", href: "/", icon: LayoutDashboard, roles: [] },
  { key: "drivers", label: "إدارة السائقين", href: "/drivers", icon: Truck, roles: ["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"] },
  { key: "rides", label: "إدارة الرحلات", href: "/rides", icon: CreditCard, roles: ["SUPPORT_AGENT", "OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"] },
  { key: "pricing", label: "إدارة التسعير", href: "/pricing", icon: Percent, roles: ["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"] },
  { key: "finance", label: "الإدارة المالية", href: "/finance", icon: Users, roles: ["FINANCE_MANAGER", "ADMIN", "SUPER_ADMIN"] },
  { key: "support", label: "الدعم والتدقيق", href: "/support", icon: Headset, roles: ["SUPPORT_AGENT", "OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"] },
  { key: "audit", label: "سجل التدقيق", href: "/audit", icon: ShieldAlert, roles: ["ADMIN", "SUPER_ADMIN"] },
  { key: "settings", label: "الإعدادات", href: "/settings", icon: Settings, roles: ["SUPER_ADMIN"] },
];

export default function RtlLayout({ children }: { children: React.ReactNode }) {
  const { user, logout } = useSession();
  const [open, setOpen] = useState(typeof window === "undefined" ? false : window.innerWidth > 768);

  const visible = navItems.filter((item) => item.roles.length === 0 || hasAnyRole(item.roles));

  return (
    <div className="flex h-screen flex-col">
      <header className="fixed top-0 right-0 left-0 z-20 h-14 bg-white border-b border-gray-200 flex items-center justify-between px-4">
        <button className="lg:hidden text-gray-600" onClick={() => setOpen(!open)}>
          {open ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
        </button>
        <div className="flex items-center gap-2 text-sm font-medium">
          <Sidebar className="w-4 h-4 mr-2" /> ميشوار اليمن — الإدارة
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden md:block text-sm">{user?.email || "زائر"}</span>
          <button onClick={logout} className="text-sm text-gray-600 hover:text-gray-900">تسجيل خروج</button>
        </div>
      </header>

      <aside className={`fixed top-14 bottom-0 right-0 z-30 bg-white border-l border-gray-200 flex flex-col w-64 transform transition-transform duration-300 ${open ? "translate-x-0" : "translate-x-full"} lg:relative lg:translate-x-0 lg:static lg:inset-0 lg:border-l lg:border-gray-200 lg:flex-col`}>
        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {visible.map((item) => (
            <Link key={item.key} href={item.href} className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100 hover:text-gray-900 transition">
              <item.icon className="w-4 h-4" />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="p-3 border-t border-gray-200">
          <div className="text-xs text-gray-500 mb-2">دور المستخدم: {user?.roles.join(", ") || "—"}</div>
          <button onClick={logout} className="w-full flex items-center justify-center gap-2 rounded-lg border border-gray-300 px-3 py-2 text-sm text-red-700 hover:bg-red-50">
            <LogOut className="w-4 h-4" /> تسجيل خروج
          </button>
        </div>
      </aside>

      <main className={`flex-1 pt-14 ${typeof window !== "undefined" ? (window.innerWidth <= 768 ? "md:pr-0" : "pr-72") : "pr-72"} pb-6`}>
        {children}
      </main>
    </div>
  );
}
