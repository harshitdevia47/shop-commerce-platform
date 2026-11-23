import { AppError, Errors, handler, requireAdmin, requireShop } from '@qc/common';
import { Router, type RequestHandler } from 'express';
import multer from 'multer';
import { z } from 'zod';
import type { MediaService } from './media.service.js';

const ADMIN_KINDS = ['PRODUCT_IMAGE', 'CATEGORY_IMAGE'] as const;

/** Single `file` field in memory; anything else is rejected before it reaches sharp. */
function singleFile(maxBytes: number): RequestHandler {
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: maxBytes, files: 1, fields: 5, parts: 6 },
  }).single('file');
  return (req, res, next) => {
    upload(req, res, (err: unknown) => {
      if (!err) return next();
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return next(new AppError('MEDIA_TOO_LARGE', 413, `Image must be at most ${Math.floor(maxBytes / 1048576)} MB`));
        }
        return next(Errors.badRequest('MEDIA_INVALID_UPLOAD', err.message));
      }
      next(err);
    });
  };
}

export function mediaRouter(media: MediaService, maxUploadBytes: number): Router {
  const router = Router();

  // Admin uploads a catalog image (multipart/form-data: file, kind).
  router.post(
    '/api/v1/admin/media',
    requireAdmin,
    requireShop,
    singleFile(maxUploadBytes),
    handler({ body: z.object({ kind: z.enum(ADMIN_KINDS).default('PRODUCT_IMAGE') }) }, async ({ body }, req) => {
      if (!req.file) throw Errors.badRequest('MEDIA_FILE_REQUIRED', 'Attach an image in the "file" field');
      return media.uploadImage(req.file.buffer, body.kind);
    }, 201),
  );

  // Internal: catalog checks that media ids belong to the shop and gets their URLs.
  router.post(
    '/internal/media/resolve',
    requireShop,
    handler({ body: z.object({ ids: z.array(z.uuid()).max(100) }) }, ({ body }) => media.resolve(body.ids)),
  );

  return router;
}
