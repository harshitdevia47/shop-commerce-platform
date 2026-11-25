# Platform Admin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A private web page for the platform owner to track shop subscriptions (paid/due/overdue), record UPI payments, pause/resume a shop's online ordering, see per-shop numbers, and get a daily Gmail alert for overdue shops.

**Architecture:** New `platform` service (own DB `qc_platform`, server-rendered HTML, own email-code login) reached through nginx at `admin.<domain>`. It reads other services only through new HMAC-signed internal endpoints (per shop context) and pushes a platform-owned `subscription` section into tenant runtime config, which the order service and the app obey.

**Tech Stack:** Node 24, TypeScript, Express 5, Prisma 7, Zod 4, Vitest + Supertest, nodemailer (platform only), Flutter (Riverpod 3).

**Spec:** `docs/superpowers/specs/2026-11-25-platform-admin-design.md`

## Global Constraints

- Money in integer paise; dates in IST (`+05:30`), stored as `DATE` for due dates.
- Status thresholds: due soon = from `next_due - 5 days`; overdue = from `max(next_due + 7 days, extended_until)`; paused wins.
- App state mapping: paid/due soon/not set up → `ok`; due/overdue → `due`; paused → `paused`.
- Never auto-pause. Mark paid resumes a platform pause.
- Owner's `PATCH /api/v1/admin/settings` must not be able to change `subscription`; `client.js sync` must not overwrite it.
- Login codes: 6 digits, HMAC-stored, 10 min, 5 attempts, newest only, 30 s resend, 5/hour per email, 20/hour per IP; allowlist `ADMIN_EMAILS`; unknown email gets the same response and no mail.
- Session cookie `__Host-qc_admin`, HttpOnly, Secure (except `NODE_ENV=development`/test, where name is `qc_admin`), SameSite=Strict, 7 days; every POST checks `Origin` equals `ADMIN_ORIGIN`.
- Daily email at ≥ 09:00 IST, once per day, only for new `alert_log` entries; one entry per (shop, kind, due_date).
- No personal values in git: `ADMIN_EMAILS`, `MAIL_USER`, `PLATFORM_UPI_ID`, `PLATFORM_DEFAULT_FEE_RUPEES` come from env.
- Error code for paused ordering: `SHOP_SUSPENDED` (409).
- en/gu/hi for every new app string.

## Review Focus

1. Month-end due days: due day 28 + Mark paid in February, and `months covered` > 1 → next due keeps the same day (tested in Task 5).
2. Owner toggles "Taking orders" off and on while platform-paused → orders still refused (Task 2 test).
3. Double-submitted Mark paid form (back button / double tap) → two payments recorded is acceptable only if the user submitted twice; the form carries a one-time `formId` and a repeat is ignored (Task 6 test).
4. Shop created before this feature (no subscription row) → shows "Not set up", never alerted or paused (Task 5 + 7 tests).
5. Tenant unreachable during hourly push → job logs and retries next hour, page still renders from platform DB (Task 5 test with failing tenant client).

---

### Task 1: Tenant — platform-owned subscription section + platform internal endpoints

**Files:**
- Modify: `backend/packages/config-schema/src/schema.ts` (add `subscriptionStateSchema`, `subscription` in runtime config, default `{ state: 'ok' }`), `backend/packages/config-schema/src/index.ts`
- Modify: `backend/services/tenant/prisma/schema.prisma` (`subscription Json?` on Shop) + migration `20261126090000_platform_subscription`
- Modify: `backend/services/tenant/src/modules/shops/shops.service.ts`, `shops.routes.ts`
- Test: `backend/services/tenant/test/tenant.test.ts`

**Interfaces:**
- Produces: `SubscriptionState = { state: 'ok'|'due'|'paused'; amountPaise?: number; dueDate?: string /*YYYY-MM-DD*/; payTo?: string }` exported from `@qc/config-schema`; `RuntimeConfig['subscription']`.
- Produces internal routes (all `requireShop` except list):
  - `GET /internal/platform/shops` (no shop context) → `{ id, slug, name, businessType, contact, isActive, createdAt }[]`
  - `PUT /internal/platform/shops/:id/subscription` body `SubscriptionState` → `204`
  - `POST /internal/platform/shops/sync` body client.json → `{ id, slug, created: boolean }` (reuses `upsertFromClientConfig`)

- [ ] Step 1: tests — `subscription` defaults to `{state:'ok'}` in `/shop/config`; PUT sets `paused` and `/shop/config` shows it; owner PATCH with `subscription` → `VALIDATION_FAILED`; `client.js`-style `upsertFromClientConfig` keeps it; sync endpoint creates then updates (created true/false); list returns both test shops.
- [ ] Step 2: run `npx vitest run` in tenant → new tests FAIL.
- [ ] Step 3: implement; migration via `prisma migrate diff` (dev + `_test` deploy).
- [ ] Step 4: tenant tests PASS; `npm run typecheck` clean.
- [ ] Step 5: commit `feat(tenant): platform subscription state and internal platform endpoints`.

### Task 2: Order — refuse new orders when the platform paused the shop

**Files:** Modify `backend/services/order/src/modules/orders/orders.service.ts`; Test `backend/services/order/test/orders.test.ts`

- [ ] Step 1: tests — config `subscription.state='paused'` → place returns 409 `SHOP_SUSPENDED`; with `ordering.paused=false` too (owner switch on) still 409; `due` → order placed.
- [ ] Step 2: FAIL. Step 3: check before the `ORDERS_PAUSED` check. Step 4: PASS. Step 5: commit `feat(order): refuse orders while the platform pauses a shop`.

### Task 3: Stats internal endpoints (identity, catalog, reporting)

**Files:**
- identity: `src/modules/users/stats.routes.ts` (new), `src/app.ts`; test in `test/identity.test.ts`
- catalog: `src/modules/products/…routes` add route; test in `test/catalog.test.ts` (or existing products test file)
- reporting: `src/modules/reports/reports.routes.ts` + service; test in existing reporting test

**Interfaces (all `requireShop`, signed, shop from context):**
- identity `GET /internal/stats/customers?since=YYYY-MM-DD` → `{ total, newSince, activeSince }` (CUSTOMER role, `deletedAt` null; active = `lastLoginAt >= since` IST midnight)
- identity `GET /internal/stats/owner` → `{ name: string|null, phone: string|null, hasLoggedIn: boolean }`
- identity `POST /internal/platform/owner` body `{ phone, name? }` → `{ id }` (same as users CLI `create-owner`)
- catalog `GET /internal/stats/products` → `{ count }` (not deleted)
- reporting `GET /internal/stats/month?from=YYYY-MM-DD` → `{ orders, salesPaise, lastOrderAt: string|null }`

- [ ] Step 1: tests per service, each with a cross-tenant assertion (shop B context → zero/null numbers for shop A data).
- [ ] Step 2: FAIL. Step 3: implement. Step 4: PASS in all three. Step 5: commit `feat: internal stats endpoints for the platform admin`.

### Task 4: Platform service skeleton + email-code login

**Files (create):** `backend/services/platform/{package.json, tsconfig.json, tsup.config.ts, vitest.config.ts, prisma.config.ts, prisma/schema.prisma, prisma/migrations/20261126100000_init/migration.sql, src/{main.ts, app.ts, env.ts, db.ts}, src/mail/mailer.ts, src/modules/auth/{auth.service.ts, auth.routes.ts, session.ts}, src/web/layout.ts, test/{global-setup.ts, auth.test.ts}, .env.example}`; Modify `deploy/postgres/init-databases.sh` (add `platform`).

**Interfaces:**
- `Mailer { send(to: string, subject: string, html: string, text: string): Promise<void> }`; `createMailer({provider:'console'|'gmail', user?, appPassword?}, logger)`
- `requireAdmin` middleware sets `res.locals.admin = { email }`; redirects to `/login` (GET) or 401 (POST).
- `page(title: string, body: string, opts?: { admin?: string }): string` in `src/web/layout.ts` (escaped helper `h\`\`` template tag exported as `html`).
- Env: `DATABASE_URL, REDIS_URL?, INTERNAL_HMAC_SECRET, ADMIN_EMAILS (comma list, ≥1), ADMIN_ORIGIN, LOGIN_CODE_SECRET (≥32), MAIL_PROVIDER, MAIL_USER, MAIL_APP_PASSWORD(_FILE), MAIL_TO?, TENANT_URL, IDENTITY_URL, CATALOG_URL, REPORTING_URL, PLATFORM_UPI_ID?, PLATFORM_API_TOKEN_HASH?, PORT` (dev 4011). Production refuses `MAIL_PROVIDER=console`.
- Prisma models: `AdminLoginCode`, `AdminSession`, `Subscription`, `SubscriptionPayment`, `AlertLog`, `UsedForm` (spec §7.2; `UsedForm(id pk, createdAt)` for Review Focus 3). Rate limits in DB counts (no Redis needed).

- [ ] Step 1: tests — allowlisted email gets a mail with a 6-digit code, unknown email same response and no mail; wrong code ×5 locks; expired code refused; only newest code valid; resend < 30 s refused; correct code sets cookie and redirects to `/`; `/` without cookie → 302 `/login`; POST with foreign `Origin` → 403; logout clears the session; `/health` 200.
- [ ] Step 2: FAIL. Step 3: implement (copy tenant structure; no tenant scoping; `createServiceApp` without `internalAuth` on public pages; urlencoded body parser). Step 4: PASS. Step 5: commit `feat(platform): new platform service with email-code admin login`.

### Task 5: Subscription rules, actions and sync with tenant

**Files:** `src/modules/subscriptions/{status.ts, subscriptions.service.ts, shop-directory.ts}`, `src/jobs/push-states.ts`; tests `test/status.test.ts`, `test/subscriptions.test.ts`

**Interfaces:**
- `type Status = 'not_set_up'|'paid'|'due_soon'|'due'|'overdue'|'paused'`
- `statusOf(sub: { nextDueDate: string; extendedUntil: string|null; pausedAt: Date|null } | null, today: string): Status`
- `appStateOf(status, sub, payTo?): SubscriptionState`
- `addMonths(date: string, months: number, dueDay: number): string` (clamps to due day; due day ≤ 28 so always valid)
- `firstDueDate(created: string, dueDay: number): string` (next occurrence strictly after `created`)
- `ShopDirectory { list(): Promise<ShopSummary[]>; numbers(shopId, monthStart): Promise<ShopNumbers>; pushState(shopId, state): Promise<void>; sync(clientJson): Promise<{id, slug, created}>; createOwner(shopId, phone, name?): Promise<void> }` (HTTP impl with `createInternalClient`, per-shop context header; fake in tests)
- Service: `setup(shopId, {feePaise, dueDay})`, `edit(shopId, {feePaise, dueDay})`, `markPaid(shopId, {amountPaise, upiRef?, paidOn, months, note?, by, formId})`, `extend(shopId)`, `pause(shopId)`, `resume(shopId)`, `overview(today)` → rows with status + numbers; each mutating action calls `pushState`.

- [ ] Step 1: tests — status table around every threshold (−6, −5, −1, 0, +6, +7 days; extension beyond +7; paused); `addMonths('2026-01-28',1,28)='2026-02-28'`, months 3; `firstDueDate('2026-11-25',5)='2026-12-05'`, `('2026-11-05',5)='2026-12-05'`; markPaid moves date, clears extension, unpauses, pushes `ok`; same `formId` twice → one payment; extend sets `max(next_due+7, current)+7`; push job with failing directory logs and continues other shops.
- [ ] Step 2: FAIL. Step 3: implement; job `startIntervalJob('push-states', 60 min)` also on start. Step 4: PASS. Step 5: commit `feat(platform): subscription rules, payments and tenant sync`.

### Task 6: Web pages

**Files:** `src/web/{home.page.ts, shop.page.ts, login.page.ts, styles.ts}`, `src/modules/subscriptions/subscriptions.routes.ts`; test `test/pages.test.ts`

Routes: `GET /` home; `GET /shops/:id`; `POST /shops/:id/{setup,edit,paid,extend,pause,resume,checklist}` (checklist toggles `logoDone` / `playDone`) → 303 back to the shop page with a flash message (query `?done=paid`). Pause/resume use a confirm page (`GET /shops/:id/pause` shows confirm). Remind link: `https://wa.me/<owner digits>?text=` prefilled with shop name, amount, due date, `PLATFORM_UPI_ID`. Strict CSP `default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'`.

- [ ] Step 1: tests — home lists shops ordered overdue, due, due soon, paid, not set up, paused tiles counts; shop page shows fee, history, numbers, checklist; each POST changes state; HTML-escapes a shop named `<b>x</b>`; repeated `formId` ignored; unknown shop id 404.
- [ ] Step 2: FAIL. Step 3: implement (phone-first single column, `max-width: 920px`, light/dark via `color-scheme`). Step 4: PASS. Step 5: commit `feat(platform): admin web pages`.

### Task 7: Daily overdue email

**Files:** `src/jobs/daily-alerts.ts`; test `test/alerts.test.ts`

**Interfaces:** `runDailyAlerts({ db, mailer, directory, now, to, baseUrl }): Promise<{ sent: boolean; shops: number }>`

- [ ] Step 1: tests — before 09:00 IST nothing; at 09:00 one mail listing newly overdue shops; second run same day nothing; next day nothing new → no mail; after extension ends → mailed again (`extension_ended`); not-set-up and paused shops never listed.
- [ ] Step 2: FAIL. Step 3: implement; job every 15 min. Step 4: PASS. Step 5: commit `feat(platform): daily overdue email`.

### Task 8: New-shop command registers on the live server

**Files:** `src/modules/shops-api/shops-api.routes.ts` (platform, `POST /api/shops`, bearer token compared to `PLATFORM_API_TOKEN_HASH` sha256); `backend/services/tenant/scripts/{new-shop.ts, new-shop-lib.ts}` (questions fee + due day, `ShopAnswers.feeRupees`, `dueDay`); `backend/scripts/platform-token.mjs` (prints a new token + its hash); tests `platform/test/shops-api.test.ts`, `tenant/test/new-shop.test.ts`.

- [ ] Step 1: tests — missing/wrong token 401; valid → directory.sync + createOwner + subscription with `firstDueDate`; re-run keeps the subscription; lib validates fee (1–100000 ₹) and due day (1–28).
- [ ] Step 2: FAIL. Step 3: implement; CLI uses `PLATFORM_URL`/`PLATFORM_TOKEN` from env when set, else prints manual steps as today. Step 4: PASS. Step 5: commit `feat: new-shop registers the shop on the live server`.

### Task 9: App — due card and paused state

**Files:** `app/lib/core/config/shop_settings.dart` (`SubscriptionInfo`), `app/lib/features/admin_dashboard/presentation/subscription_card.dart` (new), `admin_home_screen.dart`, customer home banner (where `shopPausedBanner` lives), `app/lib/core/l10n/l10n.dart` (`SHOP_SUSPENDED`), ARB en/gu/hi; tests `app/test/features/subscription_test.dart`.

- [ ] Step 1: tests — `due` shows owner card with amount, date, UPI button opening `upi://pay?pa=<payTo>&am=<rupees>`; `paused` shows owner "Orders are paused" card and customer banner "This shop is not taking online orders right now. Please call the shop."; `ok` shows neither.
- [ ] Step 2: FAIL. Step 3: implement. Step 4: `flutter test` + `flutter analyze` clean. Step 5: install on emulator; commit `feat(app): subscription due card and paused banner`.

### Task 10: Deploy wiring and docs

**Files:** `deploy/docker-compose.yml` (platform service, `working_dir`, env, mail secret file), `deploy/nginx/nginx.conf` + `nginx.tls.conf` (server `admin.<domain>` → `platform:3000`), `deploy/.env.example`, `docs/deploy.md` (admin section: DNS, create DB on existing servers `CREATE DATABASE qc_platform`, Gmail app password steps, token for laptop, Uptime Kuma email), `CLAUDE.md` (service table + conventions), dev `.env` for platform.

- [ ] Step 1: smoke stack `docker compose -p qc-smoke up -d --build`; create `qc_platform` in the existing smoke DB; `curl` login page via nginx with `Host: admin.localhost` → 200.
- [ ] Step 2: commit `chore(deploy): platform admin service and docs`.
