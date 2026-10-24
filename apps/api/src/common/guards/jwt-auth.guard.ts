import {
  ExecutionContext,
  Injectable,
  CanActivate,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface JwtPayload {
  sub: string;
  phone?: string;
  email?: string;
  roles: string[];
}

/**
 * Validates the access JWT using @nestjs/jwt. Attaches the payload to
 * `request.user` so RBAC and ownership checks can use it.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const auth = request.headers.authorization;
    if (!auth?.startsWith('Bearer ')) {
      throw new UnauthorizedException('غير مصرح لك بالوصول', 'Unauthorized');
    }
    const token = auth.substring(7);
    try {
      const payload = this.jwt.verify<JwtPayload>(token, {
        secret: process.env.JWT_ACCESS_SECRET,
      });
      request.user = {
        sub: payload.sub,
        phone: payload.phone,
        email: payload.email,
        roles: payload.roles ?? [],
      };
      return true;
    } catch {
      throw new UnauthorizedException('التوقيع غير صالح أو منتهي الصلاحية', 'Unauthorized');
    }
  }
}
