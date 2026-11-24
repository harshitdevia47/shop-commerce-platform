import { mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { ADMIN_ROLES, Errors, getContext, requireShopId, uuidv7, type ShopConfigSource } from '@qc/common';
import type { Features } from '@qc/config-schema';
import type { Db } from '../../db.js';
import type { MediaFile, MediaKind } from '../../generated/prisma/client.js';
import { processImage } from './image-pipeline.js';

export interface PublicMedia {
  id: string;
  kind: MediaKind;
  url: string;
  thumbUrl: string;
  width: number;
  height: number;
}

export interface MediaServiceOptions {
  db: Db;
  root: string;
  publicPath: string;
  /** Feature flags of the current shop (private upload kinds are switched on per shop). */
  shopConfig?: ShopConfigSource<{ features: Features }>;
  now?: () => Date;
}

export const PRIVATE_KINDS = ['PRESCRIPTION', 'HANDWRITTEN_LIST', 'RETURN_PHOTO'] as const;
export type PrivateKind = (typeof PRIVATE_KINDS)[number];

const FEATURE_OF: Record<PrivateKind, keyof Features> = {
  PRESCRIPTION: 'prescriptionUpload',
  HANDWRITTEN_LIST: 'handwrittenListUpload',
  RETURN_PHOTO: 'returns',
};

export interface PrivateMedia {
  id: string;
  kind: PrivateKind;
  width: number;
  height: number;
}

export function createMediaService({ db, root, publicPath, shopConfig, now = () => new Date() }: MediaServiceOptions) {
  const toPublic = (file: MediaFile): PublicMedia => ({
    id: file.id,
    kind: file.kind,
    url: `${publicPath}/${file.path}`,
    thumbUrl: `${publicPath}/${file.thumbPath}`,
    width: file.width,
    height: file.height,
  });

  async function store(input: Buffer, kind: MediaKind, visibility: 'PUBLIC' | 'PRIVATE'): Promise<MediaFile> {
    const shopId = requireShopId();
    const userId = getContext()?.userId;
    if (!userId) throw Errors.unauthorized('AUTH_REQUIRED', 'Login required');

    const image = await processImage(input);
    const id = uuidv7();
    const date = now();
    const folder = `${shopId}/${date.getUTCFullYear()}/${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
    const path = `${folder}/${id}-full.webp`;
    const thumbPath = `${folder}/${id}-thumb.webp`;
    const absolute = (relative: string) => join(root, visibility === 'PUBLIC' ? 'public' : 'private', relative);

    await mkdir(dirname(absolute(path)), { recursive: true });
    await Promise.all([writeFile(absolute(path), image.full), writeFile(absolute(thumbPath), image.thumb)]);
    try {
      return await db.mediaFile.create({
        data: {
          id,
          shopId,
          uploadedBy: userId,
          kind,
          visibility,
          path,
          thumbPath,
          width: image.width,
          height: image.height,
          bytes: image.full.length + image.thumb.length,
        },
      });
    } catch (err) {
      await Promise.allSettled([rm(absolute(path)), rm(absolute(thumbPath))]);
      throw err;
    }
  }

  return {
    toPublic,

    /** Processes and stores a public catalog image for the current shop. */
    async uploadImage(input: Buffer, kind: MediaKind): Promise<PublicMedia> {
      return toPublic(await store(input, kind, 'PUBLIC'));
    },

    /** A customer's private photo (prescription, handwritten list, return photo). */
    async uploadPrivate(input: Buffer, kind: PrivateKind): Promise<PrivateMedia> {
      const features = (await shopConfig?.get())?.features;
      if (!features?.[FEATURE_OF[kind]]) throw Errors.badRequest('FEATURE_DISABLED', 'This shop does not take these uploads');
      const file = await store(input, kind, 'PRIVATE');
      return { id: file.id, kind, width: file.width, height: file.height };
    },

    /**
     * Path of a private rendition if the caller may see it: the customer who uploaded it, or the
     * shop's owner/staff. Everyone else (other customers, riders, other shops) gets 404.
     */
    async privatePath(id: string, size: 'full' | 'thumb'): Promise<string> {
      const context = getContext();
      const file = await db.mediaFile.findFirst({ where: { id, visibility: 'PRIVATE', deletedAt: null } });
      const isAdmin = context?.role !== undefined && ADMIN_ROLES.includes(context.role);
      if (!file || (!isAdmin && file.uploadedBy !== context?.userId)) {
        throw Errors.notFound('MEDIA_NOT_FOUND', 'File not found');
      }
      return join(root, 'private', size === 'thumb' ? file.thumbPath : file.path);
    },

    /** Internal (order service): these private files were uploaded by `userId` in this shop, with these kinds. */
    async claim(ids: string[], userId: string, kinds: PrivateKind[]): Promise<PrivateMedia[]> {
      if (ids.length === 0) return [];
      const files = await db.mediaFile.findMany({
        where: { id: { in: ids }, visibility: 'PRIVATE', uploadedBy: userId, kind: { in: kinds }, deletedAt: null },
      });
      if (files.length !== new Set(ids).size) throw Errors.notFound('MEDIA_NOT_FOUND', 'Some photos were not found');
      return files.map((f) => ({ id: f.id, kind: f.kind as PrivateKind, width: f.width, height: f.height }));
    },

    /** Media of the current shop among `ids` (unknown or other shops' ids are left out). */
    async resolve(ids: string[]): Promise<PublicMedia[]> {
      if (ids.length === 0) return [];
      const files = await db.mediaFile.findMany({ where: { id: { in: ids }, visibility: 'PUBLIC', deletedAt: null } });
      return files.map(toPublic);
    },
  };
}

export type MediaService = ReturnType<typeof createMediaService>;
