"use client";
"use strict";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { getToken, getUser, isAuthenticated, hasAnyRole, type AdminUser } from "@/lib/auth";

type SessionContextValue = {
  user: AdminUser | null;
  isAuthenticated: boolean;
  hasAnyRole: (roles: string[]) => boolean;
  login: (token: string, user: AdminUser) => void;
  logout: () => void;
};

const SessionContext = createContext<SessionContextValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const u = getToken() ? getUser() : null;
    setUser(u);
    setReady(true);
  }, []);

  const login = (token: string, user: AdminUser) => {
    setUser(user);
  };

  const logout = () => {
    setUser(null);
  };

  if (!ready) {
    return null as unknown as ReactNode;
  }

  return (
    <SessionContext.Provider
      value={{
        user,
        isAuthenticated: !!getToken(),
        hasAnyRole,
        login,
        logout,
      }}
    >
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used within SessionProvider");
  return ctx;
}
