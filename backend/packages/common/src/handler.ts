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
    if (result !== undefined && !res.headersSent) res.status(successStatus).json({ data: result });
  };
}
