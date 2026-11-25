# Platform admin (web) — design

Date: 2026-11-25. Status: draft, waiting for the platform owner's approval.

## 1. Why

The business sells the app to local shops as a service: the shop runs its own shop in the app
(products, settings, riders) and pays the platform owner a **monthly subscription by UPI**. The
platform owner gives technical support. Today nothing tracks who has paid, and there is no place to
see all shops at once. With a handful of shops this becomes a daily question: *which shops paid this
month and which are due?*

The platform owner wants one private web page, used from a phone or laptop browser, that answers that
question, lets them act on it (record a payment, pause a shop that does not pay), and shows how each
shop's app is doing (customers, orders).

## 2. Goals

1. See at a glance which shops have **paid**, are **due soon**, **due**, **overdue** or **paused**.
2. Record a UPI payment in a few taps ("Mark paid"), which moves the shop's next due date a month ahead.
3. Get **one Gmail email** when a shop is 7 days past its due date (and again when an extension runs
   out), so nothing is missed without opening the page.
4. **Pause** a shop's online ordering by hand, and resume it (automatically on Mark paid).
5. See per shop: customers (total, new this month, active this month), orders this month, last order,
   and a launch checklist.
6. Adding a shop stays one laptop command (`npm run new-shop`), which now also registers the shop and
   its owner **on the live server** with its fee and due day — no logging into the server.

## 3. Non-goals (for this version)

- No automatic payment collection (no Razorpay subscriptions, no UPI auto-verification).
- No automatic pause. The platform owner decides each time (some shop owners are relatives or friends).
- No web form for creating shops (the Android app must be built on the laptop anyway).
- No list of customers' names or phone numbers across shops; counts only (privacy policy: the operator
  is the tech provider). Looking up one customer is a later addition if support needs it.
- No editing of shop products, orders or settings from this page (that is the shop owner's job).
- No GST invoices for the subscription, no multiple admin roles, no mobile app for the admin.

## 4. Anti-goals (would be a failure even if it works)

- A shop's app stops taking orders without the platform owner pressing Pause.
- The shop owner can undo a platform pause with their own "Taking orders" switch.
- The page is reachable by anyone else, or leaks one shop's data into another shop's app.
- Daily email spam (the same shop repeated every day while nothing changed).
- The platform owner needs to SSH into the server for routine work.

## 5. What the platform owner sees

### 5.1 Login
- Address `https://admin.<domain>` (own nginx host).
- Enter email → 6-digit code sent to that Gmail → logged in. Only emails listed in `ADMIN_EMAILS`
  (server env) can get a code; others see the same "code sent" message (no account probing) but get
  nothing.
- Session lasts 7 days on that browser; "Log out" ends it.

### 5.2 Home
- Four count tiles: **Overdue**, **Due** (past due date, under 7 days), **Due soon** (next 5 days),
  **Paid**. Plus **Paused** when any.
- Shop list below, overdue first, then due, due soon, paid; each row: shop name, fee, next due date,
  status badge, customers, orders this month. Tapping opens the shop page.
- Works on a 360 px phone screen (one column) and on a laptop.

### 5.3 Shop page
- Header: name, slug, business type, owner name + phone, shop phone, status badge.
- **Subscription**: monthly fee, due day, next due date, extension (if any), status.
  Buttons:
  - **Mark paid** → form: amount (prefilled with the fee), UPI reference (optional), date
    (default today), months covered (default 1), note. Saves a payment, moves the next due date one month ahead, clears any
    extension, and resumes the shop if it was paused by the platform.
  - **Extend 7 days** → pushes the "overdue" point 7 days later (the shop stays usable). Once per
    due period is enough; pressing again extends from the current extension.
  - **Pause orders** / **Resume orders** → confirmation dialog first.
  - **Remind on WhatsApp** → opens `wa.me/<owner phone>` with a prefilled message (amount, due date,
    the platform owner's UPI ID).
  - **Edit** fee and due day.
- Shops that exist without a subscription (the shops created before this feature, or created without
  the platform token) show as **Not set up** on the home page, with a "Set up subscription" form (fee,
  due day). They are never paused or emailed about until set up.
- **Payment history**: date, amount, UPI reference, note (newest first).
- **App numbers**: customers total / new this month / active this month (logged in this month),
  orders this month (not cancelled/rejected), sales this month (₹), last order date.
- **Launch checklist**: Shop created ✓ (always), Owner logged in (auto), First product (auto), First
  order (auto), Real logo added (manual tick), App on Play Store (manual tick).

### 5.4 Email
- Sender: the platform owner's own Gmail through Gmail SMTP with an **app password** (free).
- **Daily summary at 9:00 IST**, sent only if something *new* crossed a line since the last email:
  shops that reached 7 days overdue, or whose extension ended. Each shop appears once per due period
  (it is listed again only after an extension ends or the next period goes overdue). Each line has
  shop, amount, days overdue, and a link to the shop page.
- The login codes use the same mail settings.
- Uptime Kuma (already in the stack) is pointed at the same Gmail for server-down alerts (docs only).

## 6. What shop owners and customers see

The subscription state reaches the apps through the shop's runtime config (`GET /shop/config`), as a
new section that only the platform can change:

```json
"subscription": { "state": "ok" | "due" | "paused", "amountPaise": 99900, "dueDate": "2026-12-05", "payTo": "name@upi" }
```

- `ok` (paid or due soon): nothing visible.
- `due` (past the due date, not paused): owner/staff dashboard shows a card "Subscription due:
  ₹999 since 5 Dec. Pay to name@upi" with a "Pay by UPI" button (UPI intent link, like the customer
  checkout) and the existing support WhatsApp button. Customers see nothing; ordering works.
- `paused`: the order service refuses new orders with `SHOP_SUSPENDED` (409); the customer home shows
  "This shop is not taking online orders right now. Please call the shop." with the call button; the
  owner dashboard shows "Orders are paused: subscription unpaid. Pay to resume." The owner can still
  log in and handle existing orders, riders can still deliver, nothing else is blocked.
- The owner's own "Taking orders" switch keeps working independently; the platform pause wins.
- Changes reach the apps within about a minute (existing config caching).

## 7. How it is built (decided)

These choices are the designer's call (the platform owner left the technical choices to us), kept
consistent with the existing platform:

### 7.1 New service `platform`
- Same stack as the other services (Express 5, Prisma 7, Zod, pino, Vitest), own database
  `qc_platform`, port 4011 in dev, folder `backend/services/platform`, in the single `qc-backend`
  image, compose entry with `working_dir`.
- It is **not a tenant service**: its data is about shops, not inside a shop, so its tables have no
  tenant scoping and it does not use `tenantScopeExtension`. It talks to other services only through
  their internal APIs (HMAC-signed, with the target shop's id in the signed shop header), never their
  databases.
- **Web pages are server-rendered HTML** from this service (like the legal pages: escaped templates,
  small inline CSS, a few lines of inline JS at most), plain forms with POST → redirect. No frontend
  framework, no build step. Strict CSP. This keeps the page fast on a phone and the code small.
- Public only through nginx host `admin.<domain>` (TLS); the gateway does not route it. This is the
  one service reachable from outside besides the gateway, so it does its own auth on every route
  except `/login`, `/health`.

### 7.2 Data (`qc_platform`)
- `admin_login_codes` (email, code HMAC, expires 10 min, attempts ≤ 5, single use, newest only;
  rate limit: 30 s resend, 5/hour per email, 20/hour per IP).
- `admin_sessions` (token hash, email, expires 7 days, last seen). Cookie `__Host-qc_admin`, HttpOnly,
  Secure, SameSite=Strict; POSTs also check `Origin`.
- `subscriptions` (shop_id unique, slug, fee_paise, due_day 1–28, next_due_date, extended_until,
  paused_at, logo_done, play_done, created_at, updated_at).
- `subscription_payments` (id, shop_id, amount_paise, upi_ref, paid_on, note, recorded_by email,
  created_at). Money in paise.
- `alert_log` (shop_id, kind `overdue|extension_ended`, due_date, sent_at) — one row per shop per due
  period per kind; this is what prevents repeated emails.

### 7.3 Status rules (IST dates)
- `today < next_due - 5 days` → **paid**; `next_due - 5 ≤ today < next_due` → **due soon**;
  `next_due ≤ today < max(next_due + 7, extended_until)` → **due**; after that → **overdue**;
  `paused_at` set → **paused** (wins).
- App state: paid/due soon → `ok`; due/overdue → `due`; paused → `paused`.
- Mark paid: `next_due_date += months covered` (same due day), `extended_until = null`, unpause. Partial
  amounts are recorded as given and still move the date (the owner decides; the note field explains).
- First due date when a shop is created: the next occurrence of its due day after creation (so the
  first month is free until then).

### 7.4 Changes in other services
- **tenant**: a platform-owned `subscription` section in runtime config (column, not editable by
  `PATCH /admin/settings`, kept by `client.js sync`), set by `PUT /internal/platform/shops/:id/subscription`.
  Plus `GET /internal/platform/shops` (all shops: id, slug, name, business type, contact, active) and
  `POST /internal/platform/shops/sync` (body = client.json; same logic as `client.js sync`, used by the
  new-shop command through the platform service).
- **identity**: `GET /internal/stats/customers` (total, new this month, active this month for the
  current shop), `GET /internal/stats/owner` (owner name/phone, has logged in), and
  `POST /internal/platform/owner` (create-owner, same as the users CLI).
- **catalog**: `GET /internal/stats/products` (count).
- **reporting**: `GET /internal/stats/month` (orders, sales, last order date for the current shop).
- **order**: refuse placement with `SHOP_SUSPENDED` when `subscription.state == 'paused'`.
- **app**: `ShopSettings.subscription`, owner dashboard card (due / paused), customer paused banner,
  `SHOP_SUSPENDED` error text in en/gu/hi.
- The platform service pushes the app state to tenant whenever it changes (mark paid, pause, resume,
  edit) and once an hour for every shop (date-driven changes like ok → due).

### 7.5 New-shop command
- `npm run new-shop` asks two more questions: monthly fee (₹) and due day (1–28).
- If `PLATFORM_URL` and `PLATFORM_TOKEN` are set (laptop `.env`, not in git), it sends client.json,
  owner phone/name, fee and due day to `POST /api/shops` on the platform service (bearer token, a long
  random secret stored hashed on the server), which syncs the shop in tenant, creates the owner in
  identity and creates the subscription. Without them it behaves as today and prints the manual steps.
- Re-running for an existing slug updates the shop (same as `client.js sync`) and does not reset the
  subscription.

### 7.6 Email sending
- `nodemailer` over Gmail SMTP (`smtp.gmail.com:465`), env `MAIL_USER`, `MAIL_APP_PASSWORD(_FILE)`,
  `MAIL_TO` (defaults to the first admin email). `MAIL_PROVIDER=console` in dev logs mails instead.
- Daily job: `startIntervalJob` every 15 min; sends when IST time ≥ 09:00 and today's summary not yet
  sent, using `alert_log` to decide.

### 7.7 Testing
- Unit: status rules (dates around month ends, extensions, pause), email selection (no repeats).
- API: login flow (allowlist, code expiry, attempts, session cookie, logout), every page requires a
  session, Mark paid / extend / pause / resume / edit, CSRF (wrong Origin refused), new-shop API token.
- Internal endpoints in the other services: shop-scoped answers and the cross-tenant test (shop A's
  context never returns shop B's numbers).
- Order: `SHOP_SUSPENDED`. App: widget tests for the owner card and the customer banner.
- Manual: run on the emulator (owner due card, paused banner) and the admin page in a phone-sized
  browser.

## 8. Calls made without asking (check these)
- Server-rendered HTML pages instead of a separate web app (simpler, nothing to build or host).
- First month free: the first due date is the next due day after the shop is created.
- "Due soon" = 5 days before the due date; "overdue" = 7 days after it (the platform owner's rule).
- A partial payment still moves the due date; the note explains it.
- Customers and the owner are never blocked from the app itself; only new orders stop when paused.
- Deactivating or deleting a shop entirely (stopped subscription) is not in this version.

## 9. Left to the builder
- Exact page styling (clean, readable, matches nothing in particular; light/dark).
- Exact email wording and HTML.
- How the platform service caches the shop list and numbers (they can be a minute old).
- Order of implementation steps.

## 10. Open items for the platform owner
- **UPI ID** that shops pay to (shown in the owner's reminder card and WhatsApp reminder).
- **Gmail address** for login and alerts, and creating a Gmail app password (guided, at setup time).
- **Default monthly fee** to prefill in the new-shop command.
