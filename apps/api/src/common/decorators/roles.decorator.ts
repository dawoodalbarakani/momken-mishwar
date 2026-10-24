import { applyDecorators, SetMetadata, UseGuards } from '@nestjs/common';
import { RolesGuard } from '../guards/roles.guard.js';

export const Roles = (...roles: string[]) =>
  applyDecorators(SetMetadata('roles', roles), UseGuards(RolesGuard));

export const ROLES_KEY = 'roles';
