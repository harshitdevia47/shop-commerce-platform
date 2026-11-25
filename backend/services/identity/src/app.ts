import { createServiceApp, finalizeApp, internalAuth, type Logger, type RateLimitStore } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { addressesRouter } from './modules/addresses/addresses.routes.js';
import { createAddressesService } from './modules/addresses/addresses.service.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { devicesRouter } from './modules/devices/devices.routes.js';
import { createDevicesService } from './modules/devices/devices.service.js';
import { createOtpService } from './modules/auth/otp.service.js';
import { createTokenService } from './modules/auth/token.service.js';
import { teamRouter } from './modules/team/team.routes.js';
import { createTeamService } from './modules/team/team.service.js';
import { usersRouter } from './modules/users/users.routes.js';
import { createUsersService, type OpenOrders } from './modules/users/users.service.js';
import type { SmsProvider } from './sms/sms-provider.js';

export interface IdentityAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  sms: SmsProvider;
  /** Order service: unfinished orders block account deletion. */
  orders: OpenOrders;
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
  const devices = createDevicesService(db);
  app.use(authRouter(otp, tokens, users, devices));
  app.use(devicesRouter(devices));
  app.use(teamRouter(createTeamService(db, tokens)));
  app.use(addressesRouter(createAddressesService(db, now), users));
  app.use(usersRouter(users, deps.orders));

  finalizeApp(app, logger);
  return app;
}
