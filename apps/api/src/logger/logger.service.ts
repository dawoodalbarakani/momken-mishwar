import { Injectable, Logger } from '@nestjs/common';
import pino from 'pino';

/**
 * Thin Pino-based logger. NestJS overrides `Logger.log` etc.; this service wraps
 * pino so structured logs (request_id, duration, level) are emitted consistently.
 */
@Injectable()
export class AppLogger {
  private readonly pino = pino({
    level: process.env.LOG_LEVEL ?? 'info',
    transport:
      process.env.NODE_ENV === 'development'
        ? { target: 'pino-pretty', options: { colorize: true, singleLine: true } }
        : undefined,
  });

  log(message: string, context?: string) {
    this.pino.info({ context }, message);
  }
  error(message: string, trace?: string, context?: string) {
    this.pino.error({ context, trace }, message);
  }
  warn(message: string, context?: string) {
    this.pino.warn({ context }, message);
  }
  debug(message: string, context?: string) {
    this.pino.debug({ context }, message);
  }
  verbose(message: string, context?: string) {
    this.pino.debug({ context }, message);
  }
}

export const pinoLogger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport:
    process.env.NODE_ENV === 'development'
      ? { target: 'pino-pretty', options: { colorize: true, singleLine: true } }
      : undefined,
});
