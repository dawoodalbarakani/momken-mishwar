import { SetMetadata } from '@nestjs/common';

export const Idempotency = () => SetMetadata('idempotency', true);
export const IDEMPOTENCY_KEY = 'idempotency';
