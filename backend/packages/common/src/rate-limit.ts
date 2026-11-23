import type { Redis } from 'ioredis';

/** Fixed-window counter. Returns the hit count in the current window. */
export interface RateLimitStore {
  hit(key: string, windowSeconds: number): Promise<number>;
}

export class RedisRateLimitStore implements RateLimitStore {
  constructor(private readonly redis: Redis) {}

  async hit(key: string, windowSeconds: number): Promise<number> {
    const results = await this.redis.multi().incr(key).expire(key, windowSeconds, 'NX').exec();
    const [incrError, count] = results?.[0] ?? [];
    if (incrError) throw incrError;
    return Number(count);
  }
}

/** For tests and single-process development. */
export class MemoryRateLimitStore implements RateLimitStore {
  private readonly counts = new Map<string, { count: number; expiresAt: number }>();

  constructor(private readonly now: () => number = Date.now) {}

  async hit(key: string, windowSeconds: number): Promise<number> {
    const entry = this.counts.get(key);
    if (entry && entry.expiresAt > this.now()) {
      entry.count++;
      return entry.count;
    }
    this.counts.set(key, { count: 1, expiresAt: this.now() + windowSeconds * 1000 });
    return 1;
  }
}

export interface LimitResult {
  allowed: boolean;
  count: number;
  /** Seconds until the current window resets (upper bound). */
  retryAfterSeconds: number;
}

/**
 * Fixed-window limit: at most `limit` hits per `windowSeconds` for `key`.
 * The window index is part of the key, so counters roll over automatically.
 */
export async function hitLimit(
  store: RateLimitStore,
  key: string,
  limit: number,
  windowSeconds: number,
  nowMs: number = Date.now(),
): Promise<LimitResult> {
  const windowIndex = Math.floor(nowMs / 1000 / windowSeconds);
  const count = await store.hit(`${key}:${windowIndex}`, windowSeconds);
  const retryAfterSeconds = (windowIndex + 1) * windowSeconds - Math.floor(nowMs / 1000);
  return { allowed: count <= limit, count, retryAfterSeconds };
}
