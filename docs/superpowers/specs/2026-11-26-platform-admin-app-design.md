# Platform admin app (Flutter) — design

Date: 2026-11-26. Status: draft, waiting for the platform owner's approval.
Builds on: `2026-11-25-platform-admin-design.md` (the web admin, built and working).

## 1. Why

The platform owner checks shop subscriptions from their phone. A real app is easier for them than a
web page, and it can show a **phone notification** when a shop becomes 7 days overdue. With the app,
they do not want overdue emails any more.

## 2. Goals

1. An Android app "Shop Admin", only for the platform owner, with everything the web admin does:
   home (Overdue / Due / Due soon / Paid / Paused / Not set up + shop list), shop page (subscription,
   Mark paid, Extend 7 days, Pause with confirmation / Resume, Remind on WhatsApp, edit fee and due day,
   payment history, app numbers, launch checklist with the two manual ticks).
2. Login with the admin email + 6-digit code (same rules as the web), then the app stays logged in
   (90 days, renewed while used).
3. **Overdue alerts as phone notifications** (same rule as today: once per shop per due period and kind,
   at most one notification run a day from 09:00 IST). Tapping opens that shop. No overdue email.
4. The web admin keeps working; both use the same server data.

## 3. Non-goals

- Not on the Play Store (installed by cable / APK; one user).
- No new admin features beyond the web admin.
- No Gujarati/Hindi (the owner uses English); no iOS.
- No change to the shop apps.

## 4. Anti-goals

- An overdue shop is missed silently (for example the phone was never registered for notifications).
- Admin code or screens end up inside any shop app.
- A stolen phone keeps access forever (sessions expire and "Log out" ends them on the server).

## 5. Decisions

### 5.1 Server (platform service)
- New JSON API under `/api/admin/*` next to the web pages, using the **same services** (subscriptions,
  auth), so web and app can never disagree:
  - `POST /api/admin/login/code {email}` → same answer for any email; `POST /api/admin/login/verify
    {email, code}` → `{token}`; `POST /api/admin/logout`.
  - `GET /api/admin/overview`, `GET /api/admin/shops/:id`,
    `POST /api/admin/shops/:id/{setup,edit,paid,extend,pause,resume,checklist}` (JSON bodies with the
    same validation as the forms, `formId` dedupe kept).
  - `PUT /api/admin/device {token, platform}` / `DELETE` on logout.
- Auth: `Authorization: Bearer <token>` (no cookies, so no CSRF check on `/api/admin`); same
  `admin_sessions` table with a `kind` (`web` 7 days, `app` 90 days, extended when used).
- Push: FCM HTTP v1 with the platform's service account, the same signing approach as the notification
  service (moved into a small shared package `packages/fcm` so both use one copy). Device tokens in a new
  `admin_devices` table (email, token, updated_at).
- Daily alert job: sends one notification per new alert ("Sharma Kirana is 7 days overdue — ₹999 since
  5 Dec"; data `shopId`). **Email is only a fallback** when no admin device is registered or FCM is not
  configured, so an alert is never lost (designer's call).
- Login codes still go to Gmail (the only way to prove the email); server-down alerts stay with Uptime
  Kuma (the server cannot notify when it is down).

### 5.2 App
- New Flutter project `platform_app/` in the repo (own `pubspec.yaml`, package `in.qcommerce.platformadmin`,
  app name "Shop Admin"). Same stack as the shop app: Riverpod 3, go_router, dio, flutter_secure_storage,
  firebase_messaging + flutter_local_notifications, url_launcher; Material 3 with a neutral theme.
- Settings by `--dart-define-from-file`: `ADMIN_API_URL` (dev USB: `http://localhost:4011` via
  `adb reverse`; production `https://admin.<domain>`), Firebase values for the admin app.
- Screens: Login (email → code), Home, Shop, Mark paid sheet, Edit sheet, Pause confirm dialog.
  Pull to refresh; errors shown in plain words.
- Notifications: permission asked after login; token sent to the server; tap opens `/shops/<id>`.

### 5.3 Firebase
- Add a second Android app (`in.qcommerce.platformadmin`) to the same Firebase project as the shops;
  its `google-services.json` goes in `platform_app/` (gitignored). Until Firebase is set up, the app
  works without notifications and alerts fall back to email.

## 6. Testing
- Server: API tests for every endpoint (auth required, same results as the forms, formId dedupe, bearer
  token expiry/renewal, device register/remove), alert job sends pushes to registered devices and emails
  only when none, `packages/fcm` unit tests (moved from notification, which keeps passing).
- App: widget tests for login, home ordering/tiles, shop actions, pause confirmation; installed on the
  owner's S24 FE by USB with numbered steps.

## 7. Calls made without asking (check these)
- Email fallback when no phone is registered (so alerts are never lost).
- App login lasts 90 days (renewed when used); web stays 7 days.
- English only; Android only; not on the Play Store.
- A shared `packages/fcm` instead of copying the FCM code.

## 8. Left to the builder
Exact look of the screens, file layout inside `platform_app/`, order of steps.
