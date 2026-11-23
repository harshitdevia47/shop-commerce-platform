import type { Request, RequestHandler, Response } from 'express';
import { z } from 'zod';
import { AppError } from './errors.js';

interface Schemas {
  body?: z.ZodType;
  query?: z.ZodType;
  params?: z.ZodType;
}

type Infer<T> = T extends z.ZodType ? z.infer<T> : undefined;

export interface HandlerInput<S extends Schemas> {
  body: Infer<S['body']>;
  query: Infer<S['query']>;
  params: Infer<S['params']>;
}

interface ValidationIssue {
  location: string;
  path: string;
  message: string;
}

function parse(schema: z.ZodType | undefined, value: unknown, location: string, issues: ValidationIssue[]): unknown {
  if (!schema) return undefined;
  const result = schema.safeParse(value);
  if (result.success) return result.data;
  for (const issue of result.error.issues) {
    issues.push({ location, path: issue.path.join('.'), message: issue.message });
  }
  return undefined;
}

/** A page of a list. Sent as `{ data: items, nextCursor }` (nextCursor null on the last page). */
export class Page<T> {
  constructor(
    readonly items: T[],
    readonly nextCursor: string | null,
  ) {}
}

/** Takes up to `limit` rows from a query that fetched `limit + 1`, and the cursor of the next page. */
export function toPage<T, R = T>(rows: T[], limit: number, cursorOf: (row: T) => string, map?: (row: T) => R): Page<R> {
  const items = rows.slice(0, limit);
  const nextCursor = rows.length > limit && items.length > 0 ? cursorOf(items.at(-1)!) : null;
  return new Page(map ? items.map(map) : (items as unknown as R[]), nextCursor);
}

/**
 * Wraps a route: validates body/query/params with Zod, calls `fn` with typed input,
 * and sends `{ data: result }` (status `successStatus`) unless `fn` already responded
 * or returned undefined.
 */
export function handler<S extends Schemas>(
  schemas: S,
  fn: (input: HandlerInput<S>, req: Request, res: Response) => unknown,
  successStatus = 200,
): RequestHandler {
  return async (req, res) => {
    const issues: ValidationIssue[] = [];
    const input = {
      params: parse(schemas.params, req.params, 'params', issues),
      query: parse(schemas.query, req.query, 'query', issues),
      body: parse(schemas.body, req.body, 'body', issues),
    } as HandlerInput<S>;
    if (issues.length > 0) throw new AppError('VALIDATION_FAILED', 400, 'Invalid request', issues);
    const result = await fn(input, req, res);
    if (result === undefined || res.headersSent) return;
    if (result instanceof Page) {
      res.status(successStatus).json({ data: result.items, nextCursor: result.nextCursor });
      return;
    }
    res.status(successStatus).json({ data: result });
  };
}
