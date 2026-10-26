import { ForbiddenException } from '@nestjs/common';
import type { Reflector } from '@nestjs/core';
import { describe, expect, it, vi } from 'vitest';
import { RolesGuard } from './roles.guard.js';

/** Minimal ExecutionContext: the guard only reads `request.user` and the handler. */
const contextFor = (user: unknown) =>
  ({
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => function handler() {},
    getClass: () => class Controller {},
  }) as any;

const guardFor = (roles: string[] | undefined) => {
  const reflector = { get: vi.fn(() => roles) } as unknown as Reflector;
  return new RolesGuard(reflector);
};

describe('RolesGuard', () => {
  it('allows a handler that declares no roles', () => {
    expect(guardFor(undefined).canActivate(contextFor(undefined))).toBe(true);
    expect(guardFor([]).canActivate(contextFor(undefined))).toBe(true);
  });

  it('allows when the user holds one of the required roles', () => {
    const guard = guardFor(['SYSTEM', 'ADMIN']);
    const context = contextFor({ sub: 'user-1', roles: ['ADMIN'] });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('forbids when the user holds none of the required roles', () => {
    const guard = guardFor(['SYSTEM', 'ADMIN', 'SUPER_ADMIN']);
    const context = contextFor({ sub: 'user-1', roles: ['CUSTOMER'] });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('forbids an unauthenticated request reaching a role-guarded handler', () => {
    const guard = guardFor(['ADMIN']);

    expect(() => guard.canActivate(contextFor(undefined))).toThrow(ForbiddenException);
  });

  it('fails closed when the token carries no roles array', () => {
    const guard = guardFor(['ADMIN']);

    expect(() => guard.canActivate(contextFor({ sub: 'user-1' }))).toThrow(ForbiddenException);
  });

  it('does not grant access for a role that merely contains the required one as a substring', () => {
    const guard = guardFor(['ADMIN']);
    const context = contextFor({ sub: 'user-1', roles: ['ADMINISTRATOR'] });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });
});
