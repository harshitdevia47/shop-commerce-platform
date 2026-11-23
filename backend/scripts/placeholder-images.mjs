// Writes solid-colour placeholder logo.png (512px) and icon.png (1024px) for a client,
// using the client's primary colour. Replace with real artwork before release.
//   node scripts/placeholder-images.mjs <slug> [--force]
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const [slug] = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (!slug) {
  console.error('Usage: node scripts/placeholder-images.mjs <slug> [--force]');
  process.exit(1);
}
const dir = fileURLToPath(new URL(`../../clients/${slug}/`, import.meta.url));
const config = JSON.parse(readFileSync(`${dir}client.json`, 'utf8'));
const hex = config.branding.colors.primary.slice(1);
const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16));

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function solidPng(size) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // RGB
  const row = Buffer.alloc(1 + size * 3);
  for (let x = 0; x < size; x++) row.set([r, g, b], 1 + x * 3);
  const raw = Buffer.concat(Array.from({ length: size }, () => row));
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

for (const [file, size] of [
  [config.branding.logo ?? 'logo.png', 512],
  [config.branding.icon ?? 'icon.png', 1024],
]) {
  const path = `${dir}${file}`;
  if (existsSync(path) && !process.argv.includes('--force')) {
    console.log(`skip ${path} (exists)`);
    continue;
  }
  writeFileSync(path, solidPng(size));
  console.log(`wrote ${path}`);
}
