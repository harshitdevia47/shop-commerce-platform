import sharp from 'sharp';
import { Errors } from '@qc/common';

/** Longest edge of each rendition, in pixels. */
export const RENDITIONS = { thumb: 400, full: 1200 } as const;

const ACCEPTED_FORMATS = new Set(['jpeg', 'png', 'webp', 'heif', 'avif', 'gif']);
/** Refuse decompression bombs: 40 MP is plenty for a phone photo. */
const MAX_INPUT_PIXELS = 40_000_000;

export interface ProcessedImage {
  thumb: Buffer;
  full: Buffer;
  width: number;
  height: number;
}

/**
 * Decodes an untrusted upload and re-encodes it as WebP renditions.
 * The format is detected from the bytes (never the client's mime type); EXIF orientation is
 * applied, and all metadata (GPS, camera) is dropped because sharp does not copy it by default.
 */
export async function processImage(input: Buffer): Promise<ProcessedImage> {
  let format: string | undefined;
  try {
    format = (await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS }).metadata()).format;
  } catch {
    throw Errors.badRequest('MEDIA_INVALID_IMAGE', 'File is not a supported image');
  }
  if (!format || !ACCEPTED_FORMATS.has(format)) {
    throw Errors.badRequest('MEDIA_INVALID_IMAGE', 'File is not a supported image');
  }

  const render = (edge: number, quality: number) =>
    sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, animated: false })
      .rotate()
      .resize({ width: edge, height: edge, fit: 'inside', withoutEnlargement: true })
      .webp({ quality })
      .toBuffer({ resolveWithObject: true });

  try {
    const [full, thumb] = await Promise.all([render(RENDITIONS.full, 80), render(RENDITIONS.thumb, 75)]);
    return { full: full.data, thumb: thumb.data, width: full.info.width, height: full.info.height };
  } catch {
    throw Errors.badRequest('MEDIA_INVALID_IMAGE', 'Image could not be processed');
  }
}
