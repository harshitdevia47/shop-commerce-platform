import type { Logger } from '@qc/common';
import type { Redis } from 'ioredis';
import { streamKey } from './schemas.js';

/**
 * Transactional outbox relay.
 *
 * Services write events to their own `outbox_events` table in the same transaction as the
 * change (see `toOutboxRow`). The relay copies them to Redis Streams and deletes them.
 * Delivery is at least once: if Redis accepted an event but the delete failed, the event is
 * published again, so consumers must be idempotent (they are, via `processed_events`).
 */

export interface OutboxRecord {
  id: string;
  stream: string;
  /** Envelope JSON as text. */
  envelope: string;
}

export interface OutboxStore {
  /** Locks up to `limit` oldest rows, runs `publish`, then deletes them (all in one transaction). */
  drain(limit: number, publish: (rows: OutboxRecord[]) => Promise<void>): Promise<number>;
}

/** The subset of a Prisma client the relay needs. Pass the unscoped client: the relay serves all shops. */
export interface RawSqlClient {
  $queryRawUnsafe<T = unknown>(query: string, ...values: unknown[]): Promise<T>;
  $executeRawUnsafe(query: string, ...values: unknown[]): Promise<number>;
}

export interface RawSqlTransactor extends RawSqlClient {
  $transaction<R>(fn: (tx: RawSqlClient) => Promise<R>): Promise<R>;
}

/** Outbox on the `outbox_events` table (columns: id, stream, envelope jsonb; ids are UUID v7, so id order = time order). */
export function prismaOutboxStore(prisma: RawSqlTransactor): OutboxStore {
  return {
    drain: (limit, publish) =>
      prisma.$transaction(async (tx) => {
        const rows = await tx.$queryRawUnsafe<OutboxRecord[]>(
          'SELECT id::text AS id, stream, envelope::text AS envelope FROM outbox_events ORDER BY id LIMIT $1 FOR UPDATE SKIP LOCKED',
          limit,
        );
        if (rows.length === 0) return 0;
        await publish(rows);
        await tx.$executeRawUnsafe('DELETE FROM outbox_events WHERE id = ANY($1::uuid[])', rows.map((r) => r.id));
        return rows.length;
      }),
  };
}

export interface OutboxRelayOptions {
  store: OutboxStore;
  redis: Redis;
  logger: Logger;
  batchSize?: number;
  /** Safety-net poll; `kick()` publishes right after a commit. */
  pollMs?: number;
  /** Approximate cap per stream (XADD MAXLEN ~). */
  maxStreamLength?: number;
}

export interface OutboxRelay {
  start(): void;
  /** Publish now (call after committing a transaction that wrote outbox rows). */
  kick(): void;
  /** Publishes everything pending once; used by tests and on shutdown. */
  flush(): Promise<number>;
  stop(): Promise<void>;
}

export function createOutboxRelay({
  store,
  redis,
  logger,
  batchSize = 100,
  pollMs = 1000,
  maxStreamLength = 100_000,
}: OutboxRelayOptions): OutboxRelay {
  let running = false;
  let wake: (() => void) | null = null;
  let loop: Promise<void> | null = null;
  let kicked = false;

  async function publish(rows: OutboxRecord[]): Promise<void> {
    const pipeline = redis.pipeline();
    for (const row of rows) {
      pipeline.xadd(streamKey(row.stream), 'MAXLEN', '~', maxStreamLength, '*', 'event', row.envelope);
    }
    const results = (await pipeline.exec()) ?? [];
    const failed = results.find(([err]) => err);
    if (failed) throw failed[0];
  }

  async function flush(): Promise<number> {
    let total = 0;
    for (;;) {
      const count = await store.drain(batchSize, publish);
      total += count;
      if (count < batchSize) return total;
    }
  }

  async function run(): Promise<void> {
    let failures = 0;
    while (running) {
      kicked = false;
      try {
        await flush();
        failures = 0;
      } catch (err) {
        failures++;
        logger.error({ err, failures }, 'outbox relay failed; will retry');
      }
      if (!running) break;
      if (kicked && failures === 0) continue;
      const delay = failures === 0 ? pollMs : Math.min(pollMs * 2 ** failures, 30_000);
      await new Promise<void>((resolve) => {
        const timer = setTimeout(resolve, delay);
        wake = () => {
          clearTimeout(timer);
          resolve();
        };
      });
      wake = null;
    }
  }

  return {
    start() {
      if (running) return;
      running = true;
      loop = run();
    },
    kick() {
      kicked = true;
      wake?.();
    },
    flush,
    async stop() {
      running = false;
      wake?.();
      await loop;
    },
  };
}
