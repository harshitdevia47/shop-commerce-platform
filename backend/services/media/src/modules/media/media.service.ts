import { mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { Errors, getContext, requireShopId, uuidv7 } from '@qc/common';
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
  now?: () => Date;
}

export function createMediaService({ db, root, publicPath, now = () => new Date() }: MediaServiceOptions) {
  const toPublic = (file: MediaFile): PublicMedia => ({
    id: file.id,
    kind: file.kind,
    url: `${publicPath}/${file.path}`,
    thumbUrl: `${publicPath}/${file.thumbPath}`,
    width: file.width,
    height: file.height,
  });

  return {
    toPublic,

    /** Processes and stores a public catalog image for the current shop. */
    async uploadImage(input: Buffer, kind: MediaKind): Promise<PublicMedia> {
      const shopId = requireShopId();
      const userId = getContext()?.userId;
      if (!userId) throw Errors.unauthorized('AUTH_REQUIRED', 'Login required');

      const image = await processImage(input);
      const id = uuidv7();
      const date = now();
      const folder = `${shopId}/${date.getUTCFullYear()}/${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
      const path = `${folder}/${id}-full.webp`;
      const thumbPath = `${folder}/${id}-thumb.webp`;
      const absolute = (relative: string) => join(root, 'public', relative);

      await mkdir(dirname(absolute(path)), { recursive: true });
      await Promise.all([writeFile(absolute(path), image.full), writeFile(absolute(thumbPath), image.thumb)]);
      try {
        const file = await db.mediaFile.create({
          data: {
            id,
            shopId,
            uploadedBy: userId,
            kind,
            visibility: 'PUBLIC',
            path,
            thumbPath,
            width: image.width,
            height: image.height,
            bytes: image.full.length + image.thumb.length,
          },
        });
        return toPublic(file);
      } catch (err) {
        await Promise.allSettled([rm(absolute(path)), rm(absolute(thumbPath))]);
        throw err;
      }
    },

    /** Media of the current shop among `ids` (unknown or other shops' ids are left out). */
    async resolve(ids: string[]): Promise<PublicMedia[]> {
      if (ids.length === 0) return [];
      const files = await db.mediaFile.findMany({ where: { id: { in: ids }, deletedAt: null } });
      return files.map(toPublic);
    },
  };
}

export type MediaService = ReturnType<typeof createMediaService>;
