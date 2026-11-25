import { randomUUID } from 'node:crypto';
import { getContext } from './context.js';
import { AppError } from './errors.js';
import { signInternalHeaders, type InternalIdentity } from './internal-auth.js';

export interface InternalClientOptions {
  /** e.g. http://tenant:3000 */
  baseUrl: string;
  secret: string;
  /** Name of the calling service, sent as x-caller-service for logs. */
  caller: string;
  timeoutMs?: number;
}

export interface InternalRequestOptions {
  body?: unknown;
  /** Defaults to the current request context. */
  identity?: InternalIdentity;
}

export type InternalClient = ReturnType<typeof createInternalClient>;

/** Signed service-to-service HTTP client. Unwraps `{ data }` and rethrows upstream errors as AppError. */
export function createInternalClient({ baseUrl, secret, caller, timeoutMs = 3000 }: InternalClientOptions) {
  async function request<T>(method: string, path: string, options: InternalRequestOptions = {}): Promise<T> {
    const identity = options.identity ?? getContext() ?? { requestId: randomUUID() };
    const headers: Record<string, string> = {
      ...signInternalHeaders(identity, secret),
      'x-caller-service': caller,
      accept: 'application/json',
    };
    if (options.body !== undefined) headers['content-type'] = 'application/json';

    let response: Response;
    try {
      response = await fetch(new URL(path, baseUrl), {
        method,
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (err) {
      throw new AppError('UPSTREAM_UNAVAILABLE', 503, `Upstream ${baseUrl} unavailable`, {
        cause: err instanceof Error ? err.message : String(err),
      });
    }

    const text = await response.text();
    let json: unknown;
    try {
      json = text ? JSON.parse(text) : undefined;
    } catch {
      throw new AppError('UPSTREAM_BAD_RESPONSE', 502, `Upstream ${baseUrl} returned invalid JSON`);
    }

    if (!response.ok) {
      const error = (json as { error?: { code?: string; message?: string; details?: unknown } } | undefined)?.error;
      const status = response.status >= 500 ? 502 : response.status;
      // 4xx keep their code and details (e.g. OUT_OF_STOCK items) so callers can pass them on.
      throw new AppError(
        error?.code ?? 'UPSTREAM_ERROR',
        status,
        error?.message ?? `Upstream error ${response.status}`,
        status < 500 ? error?.details : undefined,
      );
    }
    // 204 No Content has no body.
    return (json as { data: T } | undefined)?.data as T;
  }

  return {
    get: <T>(path: string, options?: InternalRequestOptions) => request<T>('GET', path, options),
    post: <T>(path: string, options?: InternalRequestOptions) => request<T>('POST', path, options),
    put: <T>(path: string, options?: InternalRequestOptions) => request<T>('PUT', path, options),
    patch: <T>(path: string, options?: InternalRequestOptions) => request<T>('PATCH', path, options),
    delete: <T>(path: string, options?: InternalRequestOptions) => request<T>('DELETE', path, options),
  };
}
