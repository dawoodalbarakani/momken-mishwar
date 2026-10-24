import { HttpStatus } from '@nestjs/common';

/**
 * Application error with a stable code and bilingual messages. The unified HTTP
 * error body is { error: { code, message_ar, message_en, request_id } }.
 */
export class AppException extends Error {
  readonly code: string;
  readonly messageAr: string;
  readonly messageEn: string;
  readonly statusCode: number;

  constructor(code: string, messageAr: string, messageEn: string, statusCode: number) {
    super(messageEn);
    this.name = 'AppException';
    this.code = code;
    this.messageAr = messageAr;
    this.messageEn = messageEn;
    this.statusCode = statusCode;
  }
}

export const ErrorCode = {
  VALIDATION: 'VALIDATION_ERROR',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  TOO_MANY_REQUESTS: 'TOO_MANY_REQUESTS',
  IDEMPOTENCY_CONFLICT: 'IDEMPOTENCY_CONFLICT',
  RIDE_NOT_FOUND: 'RIDE_NOT_FOUND',
  RIDE_ALREADY_ASSIGNED: 'RIDE_ALREADY_ASSIGNED',
  ILLEGAL_TRANSITION: 'ILLEGAL_TRANSITION',
  START_CODE_NOT_VERIFIED: 'START_CODE_NOT_VERIFIED',
  DRIVER_NOT_APPROVED: 'DRIVER_NOT_APPROVED',
  INSUFFICIENT_BALANCE: 'INSUFFICIENT_BALANCE',
  PRICING_ERROR: 'PRICING_ERROR',
  INTERNAL: 'INTERNAL_SERVER_ERROR',
} as const;
