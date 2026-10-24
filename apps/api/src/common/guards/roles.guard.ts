import {
  ExecutionContext,
  Injectable,
  CanActivate,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

/**
 * Server-side RBAC guard. Roles are matched against `user.roles` (array of strings).
 * Support staff does NOT receive financial privileges automatically; each role is
 * checked explicitly.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.get<string[]>('roles', context.getHandler());
    if (!roles || roles.length === 0) {
      return true;
    }
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    if (!user || !Array.isArray(user.roles)) {
      throw new ForbiddenException('غير مصرح لك بهذه العملية', 'Forbidden');
    }
    const hasRole = roles.some((role) => user.roles.includes(role));
    if (!hasRole) {
      throw new ForbiddenException('لا تملك الصلاحية لتنفيذ هذه العملية', 'Forbidden');
    }
    return true;
  }
}
