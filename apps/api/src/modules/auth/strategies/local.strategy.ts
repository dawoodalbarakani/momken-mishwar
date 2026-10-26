import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';
import { UsersService } from '../../users/users.service.js';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class LocalAuthGuard extends PassportStrategy(Strategy, 'local') {
  constructor(private users: UsersService) {
    super({ usernameField: 'email' });
  }

  async validate(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user || !user.password_hash) throw new UnauthorizedException('Invalid credentials');
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');
    return user;
  }
}
