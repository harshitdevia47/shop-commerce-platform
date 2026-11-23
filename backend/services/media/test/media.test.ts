import { randomUUID } from 'node:crypto';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, signInternalHeaders, type Role } from '@qc/common';
import type { Express } from 'express';
import sharp from 'sharp';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createMediaApp } from '../src/app.js';
import { createDb } from '../src/db.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const OWNER = randomUUID();

let root: string;
let app: Express;

/** Signed gateway headers; `role: null` = anonymous (no user). */
function as(shopId: string, role: Role | null = 'OWNER') {
  return signInternalHeaders(
    { requestId: randomUUID(), shopId, userId: role ? OWNER : undefined, role: role ?? undefined },
    SECRET,
  );
}

/** A 3000x2000 JPEG carrying EXIF orientation 6 (rotate 90°) and GPS-like metadata. */
async function photo(): Promise<Buffer> {
  return sharp({ create: { width: 3000, height: 2000, channels: 3, background: '#2e7d32' } })
    .jpeg()
    .withMetadata({ orientation: 6, exif: { IFD0: { Make: 'TestCam' } } })
    .toBuffer();
}

function upload(shopId: string, file: Buffer, filename = 'photo.jpg', role: Role | null = 'OWNER') {
  return request(app).post('/api/v1/admin/media').set(as(shopId, role)).field('kind', 'PRODUCT_IMAGE').attach('file', file, filename);
}

beforeAll(() => {
  root = mkdtempSync(join(tmpdir(), 'qc-media-'));
  app = createMediaApp({
    db,
    logger: createLogger('media-test', 'silent'),
    internalSecret: SECRET,
    root,
    publicPath: '/media',
    maxUploadBytes: 2 * 1024 * 1024,
    serveStatic: true,
  });
});

afterAll(async () => {
  await rawPrisma.mediaFile.deleteMany({ where: { shopId: { in: [SHOP_A, SHOP_B] } } });
  await rawPrisma.$disconnect();
  rmSync(root, { recursive: true, force: true });
});

describe('POST /api/v1/admin/media', () => {
  it('stores WebP renditions, applies EXIF rotation and strips metadata', async () => {
    const res = await upload(SHOP_A, await photo());
    expect(res.status).toBe(201);
    const media = res.body.data;
    expect(media.url).toMatch(new RegExp(`^/media/${SHOP_A}/\\d{4}/\\d{2}/${media.id}-full\\.webp$`));
    expect(media.thumbUrl).toMatch(/-thumb\.webp$/);
    // Portrait after applying orientation 6, longest edge capped at 1200.
    expect({ width: media.width, height: media.height }).toEqual({ width: 800, height: 1200 });

    const full = join(root, 'public', media.url.replace('/media/', ''));
    const meta = await sharp(full).metadata();
    expect(meta.format).toBe('webp');
    expect(meta.exif).toBeUndefined();
    expect(meta.orientation).toBeUndefined();
    const thumb = await sharp(join(root, 'public', media.thumbUrl.replace('/media/', ''))).metadata();
    expect(Math.max(thumb.width!, thumb.height!)).toBe(400);

    const served = await request(app).get(media.url);
    expect(served.status).toBe(200);
    expect(served.headers['content-type']).toBe('image/webp');
  });

  it('does not enlarge small images', async () => {
    const small = await sharp({ create: { width: 300, height: 200, channels: 3, background: '#fff' } }).png().toBuffer();
    const res = await upload(SHOP_A, small, 'small.png');
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ width: 300, height: 200 });
  });

  it('rejects files that are not images, whatever their name says', async () => {
    const res = await upload(SHOP_A, Buffer.from('<?php echo 1; ?>'), 'evil.jpg');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('MEDIA_INVALID_IMAGE');
  });

  it('rejects files over the size limit', async () => {
    const res = await upload(SHOP_A, Buffer.alloc(3 * 1024 * 1024, 1), 'huge.jpg');
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('MEDIA_TOO_LARGE');
  });

  it('requires a file', async () => {
    const res = await request(app).post('/api/v1/admin/media').set(as(SHOP_A)).field('kind', 'PRODUCT_IMAGE');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('MEDIA_FILE_REQUIRED');
  });

  it('is only for shop admins', async () => {
    expect((await upload(SHOP_A, await photo(), 'p.jpg', 'CUSTOMER')).status).toBe(403);
    expect((await upload(SHOP_A, await photo(), 'p.jpg', null)).status).toBe(401);
  });

  it('rejects unsigned requests', async () => {
    const res = await request(app).post('/api/v1/admin/media').set('x-internal-shop-id', SHOP_A).attach('file', await photo(), 'p.jpg');
    expect(res.status).toBe(401);
  });
});

describe('POST /internal/media/resolve (tenant isolation)', () => {
  it("returns only the current shop's media", async () => {
    const a = (await upload(SHOP_A, await photo())).body.data;
    const b = (await upload(SHOP_B, await photo())).body.data;

    const res = await request(app).post('/internal/media/resolve').set(as(SHOP_A, null)).send({ ids: [a.id, b.id, randomUUID()] });
    expect(res.status).toBe(200);
    expect(res.body.data.map((m: { id: string }) => m.id)).toEqual([a.id]);
    expect(existsSync(join(root, 'public', SHOP_B))).toBe(true);
  });

  it('rejects malformed ids', async () => {
    const res = await request(app).post('/internal/media/resolve').set(as(SHOP_A, null)).send({ ids: ['x'] });
    expect(res.status).toBe(400);
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
