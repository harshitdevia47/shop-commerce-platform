# Platform Admin App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the web admin pages with a Flutter "Shop Admin" app for the platform owner, backed by a JSON API on the platform service, with overdue alerts as phone notifications.

**Architecture:** The platform service keeps its services (auth, subscriptions, alerts, new-shop API) and swaps the HTML pages for `/api/admin/*` JSON routes with bearer sessions. Overdue alerts go to registered admin phones through FCM (shared `@qc/fcm` package, moved from notification); email only when no phone is registered. New Flutter project `platform_app/`.

**Tech Stack:** Node 24/TS/Express 5/Prisma 7/Zod 4/Vitest; Flutter, Riverpod 3, go_router, dio, flutter_secure_storage, firebase_core/messaging, flutter_local_notifications, url_launcher, intl.

**Spec:** `docs/superpowers/specs/2026-11-26-platform-admin-app-design.md` (+ user decision 2026-11-26: delete the web pages; do not push).

## Global Constraints

- Login code rules unchanged (6 digits, HMAC, 10 min, 5 attempts, 30 s resend, allowlist, same answer for unknown emails).
- App sessions 90 days, extended to 90 days from now when used (at most once a day); logout deletes the session and the device.
- Same validation/limits as the removed forms: fee ₹ (paise int > 0, ≤ ₹1,00,000), due day 1–28, months 1–12, upiRef ≤ 40, note ≤ 200, `formId` dedupe.
- Alerts: one push per new alert (title "<shop> is N days overdue" / "<shop>: the extra 7 days are over", body "<₹fee> since <date>", data `{shopId}`), at most one run a day from 09:00 IST; email only when zero admin devices or push provider is console-less.
- Money paise; dates IST `YYYY-MM-DD`.
- App: English only, Android only, package `in.qcommerce.platformadmin`, name "Shop Admin".

## Review Focus

1. Expired/revoked token mid-use → app returns to login, not a crash loop (Task 4 test).
2. FCM token gone (UNREGISTERED) → device removed, next alert falls back correctly (Task 3 test).
3. Double tap on "Save payment" → one payment (formId per sheet; Task 4 test).
4. Shop list empty / tenant down → home shows a readable error with retry (Task 4 test).
5. Notification tapped while logged out → login first, then that shop (Task 5, manual check).

---

### Task 1: `@qc/fcm` shared package
**Files:** create `backend/packages/fcm/{package.json,tsconfig.json,src/index.ts,test/fcm.test.ts}` (move `services/notification/src/push/push-sender.ts`); modify notification imports, its test, notification `package.json` (dep `@qc/fcm`).
- [ ] Move file + FCM tests into the package; notification imports `@qc/fcm`.
- [ ] `npx vitest run` in packages/fcm and services/notification pass; typecheck clean. Commit `refactor: move the FCM sender into @qc/fcm`.

### Task 2: Platform JSON API, web pages removed
**Files:** delete `src/web/*`, `src/modules/auth/{auth.routes.ts,session.ts}`, `src/modules/subscriptions/subscriptions.routes.ts`, tests `pages.test.ts`; create `src/modules/admin-api/{admin-api.routes.ts,bearer.ts}`, `src/format.ts` (rupees/niceDate for alerts); modify `auth.service.ts` (`verifyCode` → token for `app` sessions 90 days, `session()` renews), schema (`AdminDevice` model; drop nothing else), `app.ts`, `env.ts` (`ADMIN_ORIGIN` removed), tests `auth.test.ts` → `api.test.ts`.

**Interfaces (all JSON `{data}` / `{error:{code,message}}`):**
- `POST /api/admin/login/code {email}` → `{sent: true}`; `POST /api/admin/login/verify {email, code}` → `{token, email}`; `POST /api/admin/logout` (bearer) → 204.
- `GET /api/admin/overview` → `{rows: [{shop, subscription|null, status, numbers}], counts: {overdue,due,due_soon,paid,paused,not_set_up}}`.
- `GET /api/admin/shops/:id` → `{shop, subscription, payments, status, numbers, today, payTo, defaultFeeRupees}`.
- `POST /api/admin/shops/:id/setup {feeRupees, dueDay, formId}`; `/edit` same; `/paid {amountRupees, months, upiRef?, paidOn, note?, formId}`; `/extend|/pause|/resume {formId}`; `/checklist {logoDone, playDone}` → `{result: 'done'|'repeat'}`.
- `PUT /api/admin/device {token, platform:'android'}` → 204; device removed on logout.
- Errors: 401 `ADMIN_AUTH_REQUIRED`; 400 `VALIDATION_FAILED` with field messages; 404 `SHOP_NOT_FOUND`; 409 `SUBSCRIPTION_EXISTS`.
- [ ] Tests: login flow (codes, unknown email, lockout, expiry, resend), bearer required everywhere, 90-day expiry + renewal, every action, formId repeat, validation messages, unknown shop 404, logout removes session + device.
- [ ] Implement; delete web code; tests pass; typecheck. Commit `feat(platform): JSON admin API for the app; web pages removed`.

### Task 3: Push alerts to admin phones
**Files:** modify `src/jobs/daily-alerts.ts` (deps `push: PushSender | null`, `mailer`), `src/main.ts`, `src/env.ts` (`PUSH_PROVIDER console|fcm`, `FCM_SERVICE_ACCOUNT(_FILE)`); tests `alerts.test.ts`.
- [ ] Tests: devices registered → pushes (one per alert, data shopId), no email; no devices → email; UNREGISTERED token → device deleted; second run same day nothing.
- [ ] Implement; pass; commit `feat(platform): overdue alerts as phone notifications`.

### Task 4: Flutter `platform_app` — login, home, shop, actions
**Files:** `platform_app/` (flutter create, package `in.qcommerce.platformadmin`), `lib/{main.dart,app.dart,api/admin_api.dart,api/models.dart,auth/session.dart,screens/{login_screen,home_screen,shop_screen,paid_sheet,edit_sheet}.dart}`, `config/env.dev.json` (`ADMIN_API_URL=http://localhost:4011`), tests `test/app_test.dart` with a fake `AdminApi`.
- [ ] Tests: login email→code→home; home tiles and order; shop page shows fee/next due/payments/numbers/checklist; Mark paid sheet sends amount/months/date and shows "Payment saved"; pause asks confirmation; 401 returns to login; error with Retry.
- [ ] Implement; `flutter test`, `flutter analyze` clean. Commit `feat(platform_app): Shop Admin app`.

### Task 5: Notifications in the app, install, docs
**Files:** `platform_app/lib/push/push.dart` (Firebase only when `FIREBASE_*` defines exist, like the shop app; channel `alerts`; tap → `/shops/<id>`), `platform_app/tool/firebase_defines.dart` (reads `google-services.json`), docs `docs/deploy.md` 6e, `CLAUDE.md`, `deploy/` (env example: `PUSH_PROVIDER`, FCM file for platform; drop `ADMIN_ORIGIN`).
- [ ] Build + install on the S24 FE via `adb reverse tcp:4011`; log in; check actions; commit `feat(platform_app): notifications; docs`.
