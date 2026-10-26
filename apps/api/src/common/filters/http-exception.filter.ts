import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { AppException, ErrorCode } from '../exceptions/app.exception.js';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();
    const request_id =
      (request.headers['x-request-id'] as string) ?? request.id ?? crypto.randomUUID();

    let code: string = ErrorCode.INTERNAL;
    let messageAr = 'حدث خطأ داخلي في الخادم';
    let messageEn = 'Internal server error';
    let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;

    if (exception instanceof AppException) {
      code = exception.code;
      messageAr = exception.messageAr;
      messageEn = exception.messageEn;
      statusCode = exception.statusCode;
    } else if (exception instanceof HttpException) {
      const res = exception.getResponse() as
        | { message?: string; error?: string }
        | string;
      statusCode = exception.getStatus();
      messageEn =
        typeof res === 'string' ? res : res.message ?? exception.message;
      messageAr = messageEn;
      code = String(exception.getStatus());
    } else if (exception instanceof Error) {
      messageEn = exception.message;
      messageAr = exception.message;
    }

    this.logger.error(
      `[${request_id}] ${messageEn} (${code})`,
      exception instanceof Error ? exception.stack : undefined,
    );

    response.status(statusCode).json({
      error: {
        code,
        message_ar: messageAr,
        message_en: messageEn,
        request_id: request_id,
      },
    });
  }
}
