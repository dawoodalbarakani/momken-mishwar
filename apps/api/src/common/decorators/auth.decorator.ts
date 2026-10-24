import { SetMetadata } from '@nestjs/common';

export const Auth = () => SetMetadata('auth', true);
export const AUTH_KEY = 'auth';
