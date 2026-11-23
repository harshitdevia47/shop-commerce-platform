import { handler, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { toPublicUser, type UsersService } from '../users/users.service.js';
import { OTP_LENGTH, type OtpService } from './otp.service.js';
import { phoneSchema } from './phone.js';
import type { DevicesService } from '../devices/devices.service.js';
import type { TokenService } from './token.service.js';

const refreshBody = z.object({ refreshToken: z.string().min(20).max(200) });

export function authRouter(otp: OtpService, tokens: TokenService, users: UsersService, devices: DevicesService): Router {
  const router = Router();
  router.use('/api/v1/auth', requireShop);

  router.post(
    '/api/v1/auth/otp/request',
    handler({ body: z.object({ phone: phoneSchema }) }, ({ body }) => otp.request(body.phone)),
  );

  router.post(
    '/api/v1/auth/otp/verify',
    handler(
      {
        body: z.object({
          phone: phoneSchema,
          code: z.string().regex(new RegExp(`^\\d{${OTP_LENGTH}}$`), `Code must be ${OTP_LENGTH} digits`),
        }),
      },
      async ({ body }, req) => {
        await otp.verify(body.phone, body.code);
        const { user, isNewUser } = await users.loginByPhone(body.phone);
        const pair = await tokens.issue(user, req.header('user-agent'));
        return { ...pair, user: toPublicUser(user), isNewUser };
      },
    ),
  );

  router.post(
    '/api/v1/auth/refresh',
    handler({ body: refreshBody }, async ({ body }, req) => {
      const { tokens: pair, user } = await tokens.refresh(body.refreshToken, req.header('user-agent'));
      return { ...pair, user: toPublicUser(user) };
    }),
  );

  router.post(
    '/api/v1/auth/logout',
    handler({ body: refreshBody.extend({ deviceToken: z.string().min(20).max(4096).optional() }) }, async ({ body }, _req, res) => {
      const userId = await tokens.revoke(body.refreshToken);
      // Stop pushes to this phone for the account that just logged out.
      if (userId && body.deviceToken) await devices.remove([body.deviceToken], userId);
      res.status(204).end();
    }),
  );

  return router;
}
