// Generates an RS256 key pair for local development JWT signing/verification.
// identity signs with the private key; gateway verifies with the public key.
import { generateKeyPairSync } from 'node:crypto';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const dir = fileURLToPath(new URL('../.keys/', import.meta.url));
const privatePath = `${dir}jwt-private.pem`;
const publicPath = `${dir}jwt-public.pem`;

if (existsSync(privatePath) && !process.argv.includes('--force')) {
  console.log(`Keys already exist in ${dir} (use --force to regenerate)`);
  process.exit(0);
}

mkdirSync(dir, { recursive: true });
const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
writeFileSync(privatePath, privateKey, { mode: 0o600 });
writeFileSync(publicPath, publicKey);
console.log(`Wrote ${privatePath} and ${publicPath}`);
