import type { ErrorRequestHandler, RequestHandler } from 'express';
import type { Logger } from 'pino';

/**
 * Expected, client-visible error. `code` is a stable machine-readable string
 * the app maps to a localized message; never change existing codes.
 */
export class AppError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    message?: string,
    readonly details?: unknown,
  ) {
    super(message ?? code);
    this.name = 'AppError';
  }
}

export const Errors = {
  badRequest: (code = 'BAD_REQUEST', message?: string, details?: unknown) =>
    new AppError(code, 400, message, details),
  unauthorized: (code = 'UNAUTHORIZED', message?: string) => new AppError(code, 401, message),
  forbidden: (code = 'FORBIDDEN', message?: string) => new AppError(code, 403, message),
  notFound: (code = 'NOT_FOUND', message?: string) => new AppError(code, 404, message),
  conflict: (code = 'CONFLICT', message?: string) => new AppError(code, 409, message),
  tooManyRequests: (code = 'RATE_LIMITED', message?: string) => new AppError(code, 429, message),
  unavailable: (code = 'SERVICE_UNAVAILABLE', message?: string) => new AppError(code, 503, message),
};

export interface ErrorBody {
  error: { code: string; message: string; details?: unknown };
}

export function errorBody(code: string, message: string, details?: unknown): ErrorBody {
  return { error: details === undefined ? { code, message } : { code, message, details } };
}

/** Errors thrown by express.json() carry a `type` field. */
function bodyParserError(err: unknown): AppError | undefined {
  if (typeof err !== 'object' || err === null || !('type' in err)) return undefined;
  switch ((err as { type: unknown }).type) {
    case 'entity.parse.failed':
      return new AppError('INVALID_JSON', 400, 'Request body is not valid JSON');
    case 'entity.too.large':
      return new AppError('PAYLOAD_TOO_LARGE', 413, 'Request body is too large');
    default:
      return undefined;
  }
}

export function errorHandler(logger: Logger): ErrorRequestHandler {
  return (err, req, res, _next) => {
    const appError = err instanceof AppError ? err : bodyParserError(err);
    if (appError) {
      if (appError.status >= 500) logger.warn({ err, path: req.path }, appError.message);
      res.status(appError.status).json(errorBody(appError.code, appError.message, appError.details));
      return;
    }
    logger.error({ err, path: req.path }, 'Unhandled error');
    res.status(500).json(errorBody('INTERNAL', 'Something went wrong'));
  };
}

export const notFoundHandler: RequestHandler = (_req, _res, next) => {
  next(Errors.notFound('ROUTE_NOT_FOUND', 'Route not found'));
};
