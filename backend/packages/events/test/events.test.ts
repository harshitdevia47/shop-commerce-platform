import { randomUUID } from 'node:crypto';
import { createLogger, getContext } from '@qc/common';
import { Redis } from 'ioredis';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import {
  DEAD_LETTER_STREAM,
  EVENTS,
  buildEvent,
  createConsumer,
  createOutboxRelay,
  parseEvent,
  streamKey,
  toOutboxRow,
  type AnyEvent,
  type OutboxRecord,
  type OutboxStore,
} from '../src/index.js';

// Database 15 keeps test streams away from services running in development.
const REDIS_URL = process.env.TEST_REDIS_URL ?? 'redis://localhost:6380/15';
const redis = new Redis(REDIS_URL);
const logger = createLogger('events-test', 'silent');
const SHOP = randomUUID();

const placed = (number = 1) =>
  buildEvent('order.placed', SHOP, {
    orderId: randomUUID(),
    number,
    customerId: randomUUID(),
    totalPaise: 12_000,
    itemCount: 2,
    fulfillment: 'DELIVERY',
    paymentMethod: 'COD',
  });

/** In-memory outbox with the same contract as the Postgres one. */
function memoryStore(rows: OutboxRecord[]): OutboxStore {
  return {
    async drain(limit, publish) {
      const batch = rows.slice(0, limit);
      if (batch.length === 0) return 0;
      await publish(batch);
      rows.splice(0, batch.length);
      return batch.length;
    },
  };
}

const record = (event: AnyEvent): OutboxRecord => {
  const row = toOutboxRow(event);
  return { id: row.id, stream: row.stream, envelope: JSON.stringify(row.envelope) };
};

async function until(check: () => boolean | Promise<boolean>, timeoutMs = 5000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (!(await check())) {
    if (Date.now() > deadline) throw new Error('timed out');
    await new Promise((r) => setTimeout(r, 20));
  }
}

beforeEach(async () => {
  await redis.flushdb();
});

afterAll(async () => {
  await redis.flushdb();
  redis.disconnect();
});

describe('event schemas', () => {
  it('every event has a stream and a positive version', () => {
    for (const spec of Object.values(EVENTS)) {
      expect(spec.stream).toMatch(/^[a-z]+$/);
      expect(spec.version).toBeGreaterThan(0);
    }
  });

  it('round-trips an event', () => {
    const event = placed(7);
    const parsed = parseEvent(JSON.stringify(event));
    expect(parsed).toEqual({ ok: true, event });
  });

  it('rejects payloads that do not match the catalog', () => {
    expect(() =>
      buildEvent('order.placed', SHOP, { orderId: 'x' } as never),
    ).toThrow();
    const event = { ...placed(), payload: { orderId: randomUUID() } };
    expect(parseEvent(JSON.stringify(event))).toMatchObject({ ok: false, reason: 'invalid payload for order.placed' });
  });

  it('reports unknown types and versions instead of throwing', () => {
    expect(parseEvent(JSON.stringify({ ...placed(), type: 'order.exploded' }))).toMatchObject({ ok: false });
    expect(parseEvent(JSON.stringify({ ...placed(), version: 99 }))).toMatchObject({ ok: false });
    expect(parseEvent('{')).toMatchObject({ ok: false, reason: 'invalid JSON' });
  });
});

describe('outbox relay', () => {
  it('publishes rows in order and removes them', async () => {
    const rows = [record(placed(1)), record(placed(2)), record(placed(3))];
    const relay = createOutboxRelay({ store: memoryStore(rows), redis, logger, batchSize: 2 });
    expect(await relay.flush()).toBe(3);
    expect(rows).toHaveLength(0);
    const entries = await redis.xrange(streamKey('order'), '-', '+');
    const numbers = entries.map(([, fields]) => JSON.parse(fields[1]!).payload.number);
    expect(numbers).toEqual([1, 2, 3]);
  });

  it('keeps rows when Redis refuses them', async () => {
    const rows = [record(placed())];
    const broken = new Redis(REDIS_URL, { lazyConnect: true, enableOfflineQueue: false });
    const relay = createOutboxRelay({ store: memoryStore(rows), redis: broken, logger });
    await expect(relay.flush()).rejects.toThrow();
    expect(rows).toHaveLength(1);
    broken.disconnect();
  });

  it('kick publishes without waiting for the poll', async () => {
    const rows: OutboxRecord[] = [];
    const relay = createOutboxRelay({ store: memoryStore(rows), redis, logger, pollMs: 60_000 });
    relay.start();
    await new Promise((r) => setTimeout(r, 50));
    rows.push(record(placed()));
    relay.kick();
    await until(async () => (await redis.xlen(streamKey('order'))) === 1);
    await relay.stop();
  });
});

describe('consumer', () => {
  async function publish(event: AnyEvent) {
    await redis.xadd(streamKey(EVENTS[event.type].stream), '*', 'event', JSON.stringify(event));
  }

  it('delivers wanted events once per group inside the tenant context', async () => {
    const seen: { type: string; shopId?: string }[] = [];
    const consumer = createConsumer({
      redis: redis.duplicate(),
      group: 'test-a',
      streams: ['order'],
      types: ['order.placed'],
      handle: async (event) => {
        seen.push({ type: event.type, shopId: getContext()?.shopId });
      },
      logger,
      blockMs: 100,
    });
    await consumer.start();
    await publish(placed());
    await publish(
      buildEvent('order.status_changed', SHOP, {
        orderId: randomUUID(),
        number: 1,
        customerId: randomUUID(),
        fulfillment: 'PICKUP',
        from: 'PLACED',
        to: 'CONFIRMED',
        byRole: 'OWNER',
        reason: null,
      }),
    );
    await redis.xadd(streamKey('order'), '*', 'event', 'not json');
    await until(async () => {
      const pending = (await redis.xpending(streamKey('order'), 'test-a')) as [number];
      const info = (await redis.xinfo('GROUPS', streamKey('order'))) as unknown[][];
      const lag = info[0]![info[0]!.indexOf('entries-read') + 1];
      return pending[0] === 0 && lag === 3;
    });
    await consumer.stop();
    expect(seen).toEqual([{ type: 'order.placed', shopId: SHOP }]);
  });

  it('retries a failing handler, then succeeds without skipping later events', async () => {
    let calls = 0;
    const handled: number[] = [];
    const consumer = createConsumer({
      redis: redis.duplicate(),
      group: 'test-b',
      streams: ['order'],
      types: ['order.placed'],
      handle: async (event) => {
        if (event.type !== 'order.placed') return;
        calls++;
        if (event.payload.number === 1 && calls < 3) throw new Error('flaky');
        handled.push(event.payload.number);
      },
      logger,
      blockMs: 100,
      retryDelayMs: 10,
    });
    await consumer.start();
    await publish(placed(1));
    await publish(placed(2));
    await until(() => handled.length === 2);
    await consumer.stop();
    expect(handled).toEqual([1, 2]);
  });

  it('dead-letters an event that keeps failing', async () => {
    const handled: number[] = [];
    const consumer = createConsumer({
      redis: redis.duplicate(),
      group: 'test-c',
      streams: ['order'],
      types: ['order.placed'],
      handle: async (event) => {
        if (event.type === 'order.placed' && event.payload.number === 1) throw new Error('poison');
        if (event.type === 'order.placed') handled.push(event.payload.number);
      },
      logger,
      blockMs: 100,
      retryDelayMs: 5,
      maxAttempts: 3,
    });
    await consumer.start();
    await publish(placed(1));
    await publish(placed(2));
    await until(() => handled.length === 1);
    await consumer.stop();
    const dead = await redis.xrange(DEAD_LETTER_STREAM, '-', '+');
    expect(dead).toHaveLength(1);
    expect(dead[0]![1]).toContain('test-c');
  });

  it('resumes unacknowledged entries after a restart', async () => {
    const handled: number[] = [];
    let crash = true;
    const make = () =>
      createConsumer({
        redis: redis.duplicate(),
        group: 'test-d',
        consumerName: 'test-d-1',
        streams: ['order'],
        types: ['order.placed'],
        handle: async (event) => {
          if (crash) throw new Error('crash');
          if (event.type === 'order.placed') handled.push(event.payload.number);
        },
        logger,
        blockMs: 100,
        retryDelayMs: 60_000,
      });
    const first = make();
    await first.start();
    await publish(placed(5));
    await until(async () => ((await redis.xpending(streamKey('order'), 'test-d')) as [number])[0] === 1);
    await first.stop();

    crash = false;
    const second = make();
    await second.start();
    await until(() => handled.length === 1);
    await second.stop();
    expect(handled).toEqual([5]);
  });
});
