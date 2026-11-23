import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { randomUUID } from 'node:crypto';
import { createAccessTokenVerifier, createLogger, type Role } from '@qc/common';
import { buildEvent } from '@qc/events';
import { SignJWT, exportSPKI, generateKeyPair } from 'jose';
import { io as connect, type Socket } from 'socket.io-client';
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import { attachRealtime, type ReportLocation } from '../src/realtime.js';

const ISSUER = 'qc-identity';
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const ALICE = randomUUID();
const BOB = randomUUID();

let privateKey: Awaited<ReturnType<typeof generateKeyPair>>['privateKey'];
let server: Server;
let url: string;
let realtime: ReturnType<typeof attachRealtime>;
const sockets: Socket[] = [];
let reported: { shopId: string; userId: string; lat: number }[] = [];
/** Fake delivery service: rider R1 of shop A is on the way with ALICE's order. */
const R1 = randomUUID();
const TRACKED_ORDER = randomUUID();
const reportLocation: ReportLocation = async (identity, ping) => {
  reported.push({ shopId: identity.shopId, userId: identity.userId, lat: ping.lat });
  const onTheWay = identity.shopId === SHOP_A && identity.userId === R1;
  return {
    targets: onTheWay ? [{ orderId: TRACKED_ORDER, customerId: ALICE }] : [],
    location: onTheWay ? { ...ping, at: '2026-11-23T10:00:00.000Z' } : null,
  };
};

async function token(shopId: string, userId: string, role: Role, ttlSeconds = 900) {
  return new SignJWT({ shopId, role, typ: 'access' })
    .setProtectedHeader({ alg: 'RS256' })
    .setSubject(userId)
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(Math.floor(Date.now() / 1000) + ttlSeconds)
    .sign(privateKey);
}

/** Connects and resolves once connected (or rejects with the server's error message). */
function open(auth: Record<string, unknown>): Promise<Socket> {
  const socket = connect(url, { auth, transports: ['websocket'], reconnection: false, forceNew: true });
  sockets.push(socket);
  return new Promise((resolve, reject) => {
    socket.on('connect', () => resolve(socket));
    socket.on('connect_error', (err) => reject(err));
  });
}

async function as(shopId: string, userId: string, role: Role) {
  return open({ token: await token(shopId, userId, role) });
}

function record(socket: Socket): unknown[] {
  const seen: unknown[] = [];
  socket.onAny((name: string, payload: unknown) => seen.push({ name, ...(payload as object) }));
  return seen;
}

const settle = () => new Promise((r) => setTimeout(r, 100));

beforeAll(async () => {
  const keys = await generateKeyPair('RS256', { extractable: true });
  privateKey = keys.privateKey;
  server = createServer();
  realtime = attachRealtime(server, {
    verify: await createAccessTokenVerifier(await exportSPKI(keys.publicKey), ISSUER),
    logger: createLogger('realtime-test', 'silent'),
    reportLocation,
  });
  await new Promise<void>((resolve) => server.listen(0, resolve));
  url = `http://localhost:${(server.address() as AddressInfo).port}`;
});

afterEach(() => {
  for (const s of sockets.splice(0)) s.disconnect();
});

afterAll(async () => {
  await realtime.io.close();
});

describe('connection', () => {
  it('refuses missing, invalid and expired tokens', async () => {
    await expect(open({})).rejects.toThrow('TOKEN_MISSING');
    await expect(open({ token: 'nope' })).rejects.toThrow('TOKEN_INVALID');
    await expect(open({ token: await token(SHOP_A, ALICE, 'CUSTOMER', -60) })).rejects.toThrow('TOKEN_EXPIRED');
  });

  it('closes the socket when the token expires', async () => {
    const socket = await open({ token: await token(SHOP_A, ALICE, 'CUSTOMER', 1) });
    const expired = new Promise((resolve) => socket.on('session.expired', resolve));
    const closed = new Promise((resolve) => socket.on('disconnect', resolve));
    await expired;
    await closed;
  });
});

describe('order and payment updates', () => {
  const placed = (shopId: string, customerId: string) =>
    buildEvent('order.placed', shopId, {
      orderId: randomUUID(),
      number: 7,
      customerId,
      totalPaise: 100,
      itemCount: 1,
      fulfillment: 'PICKUP',
      paymentMethod: 'COD',
    });

  it("reach the order's customer and their shop's admins only", async () => {
    const alice = record(await as(SHOP_A, ALICE, 'CUSTOMER'));
    const bob = record(await as(SHOP_A, BOB, 'CUSTOMER'));
    const owner = record(await as(SHOP_A, randomUUID(), 'OWNER'));
    const staff = record(await as(SHOP_A, randomUUID(), 'STAFF'));
    const rider = record(await as(SHOP_A, randomUUID(), 'RIDER'));
    const otherOwner = record(await as(SHOP_B, randomUUID(), 'OWNER'));
    // Same user id in another shop's token: still a different room.
    const aliceElsewhere = record(await as(SHOP_B, ALICE, 'CUSTOMER'));

    const event = placed(SHOP_A, ALICE);
    await realtime.handle(event);
    await settle();

    const expected = [{ name: 'order.updated', orderId: event.payload.orderId, number: 7, status: 'PLACED' }];
    expect(alice).toEqual(expected);
    expect(owner).toEqual(expected);
    expect(staff).toEqual(expected);
    expect(bob).toEqual([]);
    expect(rider).toEqual([]);
    expect(otherOwner).toEqual([]);
    expect(aliceElsewhere).toEqual([]);
  });

  it('status changes and payments carry the new status', async () => {
    const alice = record(await as(SHOP_A, ALICE, 'CUSTOMER'));
    const orderId = randomUUID();
    await realtime.handle(
      buildEvent('order.status_changed', SHOP_A, {
        orderId,
        number: 7,
        customerId: ALICE,
        fulfillment: 'DELIVERY',
        from: 'PLACED',
        to: 'CONFIRMED',
        byRole: 'OWNER',
        reason: null,
      }),
    );
    await realtime.handle(buildEvent('payment.marked_paid', SHOP_A, { orderId, orderNumber: 7, customerId: ALICE, amountPaise: 100 }));
    await settle();
    expect(alice).toEqual([
      { name: 'order.updated', orderId, number: 7, status: 'CONFIRMED' },
      { name: 'payment.updated', orderId, status: 'PAID' },
    ]);
  });
});

describe('deliveries and rider location', () => {
  const ping = (socket: Socket, body: unknown) =>
    new Promise<{ ok: boolean; tracking: number }>((resolve) => socket.emit('rider.location', body, resolve));

  it("a rider's location reaches that order's customer and the shop, nobody else", async () => {
    reported = [];
    const rider = await as(SHOP_A, R1, 'RIDER');
    const alice = record(await as(SHOP_A, ALICE, 'CUSTOMER'));
    const bob = record(await as(SHOP_A, BOB, 'CUSTOMER'));
    const owner = record(await as(SHOP_A, randomUUID(), 'OWNER'));

    expect(await ping(rider, { lat: 21.76, lng: 72.15, accuracy: 8 })).toEqual({ ok: true, tracking: 1 });
    await settle();
    const update = { name: 'rider.location', orderId: TRACKED_ORDER, lat: 21.76, lng: 72.15, accuracy: 8, at: '2026-11-23T10:00:00.000Z' };
    expect(alice).toEqual([update]);
    expect(owner).toEqual([update]);
    expect(bob).toEqual([]);
    expect(reported).toEqual([{ shopId: SHOP_A, userId: R1, lat: 21.76 }]);
  });

  it('ignores pings from non-riders, junk, and pings faster than every few seconds', async () => {
    reported = [];
    const customer = await as(SHOP_A, ALICE, 'CUSTOMER');
    expect(await ping(customer, { lat: 1, lng: 1 })).toEqual({ ok: false, tracking: 0 });
    const rider = await as(SHOP_A, R1, 'RIDER');
    expect(await ping(rider, { lat: 'x', lng: 1 })).toEqual({ ok: false, tracking: 0 });
    expect(await ping(rider, { lat: 91, lng: 1 })).toEqual({ ok: false, tracking: 0 });
    expect((await ping(rider, { lat: 21, lng: 72 })).ok).toBe(true);
    expect((await ping(rider, { lat: 21, lng: 72 })).ok).toBe(false);
    expect(reported).toHaveLength(1);
  });

  it('delivery changes reach the shop, the customer, the rider and a replaced rider', async () => {
    const newRider = randomUUID();
    const oldRider = randomUUID();
    const riderSeen = record(await as(SHOP_A, newRider, 'RIDER'));
    const oldSeen = record(await as(SHOP_A, oldRider, 'RIDER'));
    const alice = record(await as(SHOP_A, ALICE, 'CUSTOMER'));
    const owner = record(await as(SHOP_A, randomUUID(), 'OWNER'));
    const orderId = randomUUID();
    await realtime.handle(
      buildEvent('delivery.status_changed', SHOP_A, {
        deliveryId: randomUUID(),
        orderId,
        number: 4,
        customerId: ALICE,
        riderId: newRider,
        previousRiderId: oldRider,
        status: 'ASSIGNED',
      }),
    );
    await settle();
    const update = { name: 'delivery.updated', orderId, status: 'ASSIGNED' };
    expect(riderSeen).toEqual([update]);
    expect(alice).toEqual([update]);
    expect(owner).toEqual([update]);
    expect(oldSeen).toEqual([{ ...update, mine: false }]);
  });
});
