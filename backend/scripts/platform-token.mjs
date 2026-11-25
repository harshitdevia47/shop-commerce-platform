#!/usr/bin/env node
/**
 * Makes the token the laptop's `npm run new-shop` uses to create shops on the live server.
 *   node backend/scripts/platform-token.mjs
 * Put PLATFORM_TOKEN in backend/.env.platform (laptop) and PLATFORM_API_TOKEN_HASH in deploy/.env (server).
 */
import { createHash, randomBytes } from 'node:crypto';

const token = randomBytes(32).toString('base64url');
const hash = createHash('sha256').update(token).digest('hex');
console.log(`Laptop  (backend/.env.platform):  PLATFORM_TOKEN=${token}`);
console.log(`Server  (deploy/.env):            PLATFORM_API_TOKEN_HASH=${hash}`);
console.log('Keep the token secret. Anyone with it can create shops on your server.');
