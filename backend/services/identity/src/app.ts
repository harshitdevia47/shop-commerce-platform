import { createServiceApp, finalizeApp, internalAuth, type Logger, type RateLimitStore } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { createOtpService } from './modules/auth/otp.service.js';
import { createTokenService } from './modules/auth/token.service.js';
import { usersRouter } from './modules/users/users.routes.js';
import { createUsersService } from './modules/users/users.service.js';
import type { SmsProvider } from './sms/sms-provider.js';

export interface IdentityAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  sms: SmsProvider;
  limits: RateLimitStore;
  otpSecret: string;
  otpDevEcho: boolean;
  jwt: { privateKeyPem: string; issuer: string; accessTtlSeconds: number; refreshTtlDays: number };
  now?: () => Date;
}

export async function createIdentityApp(deps: IdentityAppDeps): Promise<Express> {
  const { db, logger, now } = deps;
  const app = createServiceApp({ service: 'identity', logger, ready: () => db.$queryRaw`SELECT 1` });

  const users = createUsersService(db, now);
  const otp = createOtpService({
    db,
    sms: deps.sms,
    limits: deps.limits,
    secret: deps.otpSecret,
    logger,
    devEcho: deps.otpDevEcho,
    now,
  });
  const tokens = await createTokenService({ db, logger, ...deps.jwt, now });

  app.use(internalAuth(deps.internalSecret));
  app.use(authRouter(otp, tokens, users));
  app.use(usersRouter(users));

  finalizeApp(app, logger);
  return app;
}
