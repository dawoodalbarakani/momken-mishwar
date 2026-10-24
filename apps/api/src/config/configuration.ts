import { EnvSchema, type Env } from './env.schema.js';

/**
 * Validate required environment variables at startup. Throws a clear error when a
 * required variable is missing so the process fails fast instead of misbehaving.
 */
export function validateConfig(env: NodeJS.ProcessEnv): Env {
  const parsed = EnvSchema.safeParse(env);
  if (!parsed.success) {
    const missing = Object.keys(parsed.error.flatten().fieldErrors);
    throw new Error(
      `[config] Missing or invalid required environment variables: ${missing.join(', ')}`,
    );
  }
  return parsed.data;
}

export function configuration() {
  return {
    nodeEnv: process.env.NODE_ENV ?? 'development',
    port: Number(process.env.PORT ?? 4000),
    databaseUrl: process.env.DATABASE_URL,
    databaseTestUrl: process.env.DATABASE_TEST_URL,
    jwtAccessSecret: process.env.JWT_ACCESS_SECRET,
    jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
    startCodeSecret: process.env.START_CODE_SECRET,
    otpProvider: (process.env.OTP_PROVIDER ?? 'console') as 'console' | 'sms' | 'stub',
    otpDevDisplay: process.env.OTP_DEV_DISPLAY === 'true',
    redisUrl: process.env.REDIS_URL,
    corsOrigin: (process.env.CORS_ORIGIN ?? 'http://localhost:3000').split(','),
  } as const;
}
