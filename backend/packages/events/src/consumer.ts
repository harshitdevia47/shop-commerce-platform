import { hostname } from 'node:os';
import { requireShopId, runWithContext, type Logger } from '@qc/common';
import type { Redis } from 'ioredis';
import { DEAD_LETTER_STREAM, parseEvent, streamKey, type AnyEvent, type EventType, type StreamName } from './schemas.js';

/**
 * Redis Streams consumer group loop.
 *
 * - Each service is one consumer group (`group`), so every service sees every event once.
 * - Handlers run inside the event's tenant context (`runWithContext({ shopId })`).
 * - A handler error leaves the entry pending; it is retried with backoff and, after
 *   `maxAttempts`, copied to `qc:events:dead` and acknowledged so the stream keeps moving.
 * - Delivery is at least once: handlers must be idempotent (see `processed_events`).
 * - Unknown or invalid events are logged and acknowledged.
 */

export type EventHandler = (event: AnyEvent) => Promise<void>;

export interface ConsumerOptions {
  /** Connection used only by this consumer (it blocks). Pass `redis.duplicate()`. */
  redis: Redis;
  group: string;
  streams: StreamName[];
  /** Only these types reach the handler; others are acknowledged and skipped. */
  types: readonly EventType[];
  handle: EventHandler;
  logger: Logger;
  consumerName?: string;
  maxAttempts?: number;
  blockMs?: number;
  batchSize?: number;
  /** Base retry delay; doubles per attempt (capped at 30 s). */
  retryDelayMs?: number;
  /** Where a new group starts: `$` (only new events, default) or `0` (whole stream). */
  startId?: '$' | '0';
}

export interface Consumer {
  start(): Promise<void>;
  stop(): Promise<void>;
}

type StreamEntries = [key: string, entries: [id: string, fields: string[]][]][];

export function createConsumer({
  redis,
  group,
  streams,
  types,
  handle,
  logger,
  consumerName = `${group}-${hostname()}`,
  maxAttempts = 5,
  blockMs = 5000,
  batchSize = 20,
  retryDelayMs = 1000,
  startId = '$',
}: ConsumerOptions): Consumer {
  const keys = streams.map(streamKey);
  const wanted = new Set<string>(types);
  const attempts = new Map<string, number>();
  let running = false;
  let loop: Promise<void> | null = null;
  let sleeping: { timer: NodeJS.Timeout; resolve: () => void } | null = null;

  const sleep = (ms: number) =>
    new Promise<void>((resolve) => {
      sleeping = { timer: setTimeout(resolve, ms), resolve };
    }).finally(() => {
      sleeping = null;
    });

  async function ensureGroups(): Promise<void> {
    for (const key of keys) {
      try {
        await redis.xgroup('CREATE', key, group, startId, 'MKSTREAM');
      } catch (err) {
        if (!String(err).includes('BUSYGROUP')) throw err;
      }
    }
  }

  /** Returns false when the entry failed and should be retried later. */
  async function process(key: string, id: string, fields: string[]): Promise<boolean> {
    const raw = fields[fields.indexOf('event') + 1];
    const parsed = raw === undefined ? { ok: false as const, reason: 'no event field' } : parseEvent(raw);
    if (!parsed.ok) {
      logger.warn({ stream: key, id, reason: parsed.reason }, 'skipping unreadable event');
      await redis.xack(key, group, id);
      return true;
    }
    const event = parsed.event;
    if (!wanted.has(event.type)) {
      await redis.xack(key, group, id);
      return true;
    }
    try {
      await runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => handle(event));
      await redis.xack(key, group, id);
      attempts.delete(id);
      return true;
    } catch (err) {
      const attempt = (attempts.get(id) ?? 0) + 1;
      attempts.set(id, attempt);
      if (attempt < maxAttempts) {
        logger.warn({ err, eventId: event.eventId, type: event.type, attempt }, 'event handler failed; will retry');
        return false;
      }
      logger.error({ err, eventId: event.eventId, type: event.type, attempt }, 'event handler gave up; dead-lettered');
      await redis.xadd(DEAD_LETTER_STREAM, 'MAXLEN', '~', 10_000, '*', 'group', group, 'stream', key, 'id', id, 'event', raw!, 'error', String(err));
      await redis.xack(key, group, id);
      attempts.delete(id);
      return true;
    }
  }

  async function run(): Promise<void> {
    // Start with entries delivered to us before a restart but never acknowledged.
    let backlog = true;
    let failures = 0;
    while (running) {
      try {
        const ids = keys.map(() => (backlog ? '0' : '>'));
        const response = (await redis.xreadgroup(
          'GROUP',
          group,
          consumerName,
          'COUNT',
          batchSize,
          'BLOCK',
          blockMs,
          'STREAMS',
          ...keys,
          ...ids,
        )) as StreamEntries | null;
        const batches = (response ?? []).filter(([, entries]) => entries.length > 0);
        if (backlog && batches.length === 0) {
          backlog = false;
          continue;
        }
        let failed = false;
        for (const [key, entries] of batches) {
          for (const [id, fields] of entries) {
            if (!running) return;
            if (!(await process(key, id, fields))) {
              failed = true;
              break;
            }
          }
          if (failed) break;
        }
        if (failed) {
          backlog = true; // re-read pending entries (the failed one is first)
          failures++;
          await sleep(Math.min(retryDelayMs * 2 ** (failures - 1), 30_000));
        } else {
          failures = 0;
        }
      } catch (err) {
        if (!running) return;
        logger.error({ err }, 'event consumer read failed; retrying');
        await sleep(Math.min(retryDelayMs * 2, 30_000));
      }
    }
  }

  return {
    async start() {
      if (running) return;
      await ensureGroups();
      running = true;
      loop = run();
    },
    async stop() {
      running = false;
      if (sleeping) {
        clearTimeout(sleeping.timer);
        sleeping.resolve();
      }
      // Unblocks a pending XREADGROUP BLOCK.
      redis.disconnect();
      await loop;
    },
  };
}

/** Per-service record of handled events (`processed_events` table, unique per shop + event id). */
export interface ProcessedEvents {
  has(eventId: string): Promise<boolean>;
  add(eventId: string, type: string): Promise<void>;
}

/**
 * Skips events this service already handled. The record is written after the handler
 * succeeds, so a crash in between re-runs the handler: handlers stay idempotent on their own,
 * this only keeps duplicates (e.g. a relay re-publish) from repeating side effects like pushes.
 */
export function onceOnly(processed: ProcessedEvents, handle: EventHandler): EventHandler {
  return async (event) => {
    if (await processed.has(event.eventId)) return;
    await handle(event);
    await processed.add(event.eventId, event.type);
  };
}

/** Prisma-backed `ProcessedEvents` for a service's tenant-scoped `processedEvent` model. */
export function prismaProcessedEvents(model: {
  findFirst(args: { where: { eventId: string }; select: { eventId: true } }): Promise<unknown>;
  createMany(args: { data: { shopId: string; eventId: string; type: string }[]; skipDuplicates: true }): Promise<unknown>;
}): ProcessedEvents {
  return {
    has: async (eventId) => (await model.findFirst({ where: { eventId }, select: { eventId: true } })) !== null,
    add: async (eventId, type) => {
      await model.createMany({ data: [{ shopId: requireShopId(), eventId, type }], skipDuplicates: true });
    },
  };
}
