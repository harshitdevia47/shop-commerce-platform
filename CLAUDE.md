# CLAUDE.md

Multi-tenant quick-commerce ordering platform (Zepto/Blinkit-style architecture) for local shops in small Indian cities. One backend platform (microservices) and one Flutter codebase serve every client shop. Each client gets a separately branded APK built from the same code.

> **Status:** Phases 0–4 done 2026-11-23: foundations, identity (OTP login), catalog + media, ordering (cart, checkout, order + payment, UPI + UTR, staging Docker stack, `docs/deploy.md`), and events (transactional outbox + Redis Streams via `@qc/events`, durable stock release / payment void, orphan sweepers, realtime Socket.IO service with live order screens, notification service with FCM pushes in each phone's language, device registry), and delivery (owner team management, delivery service with rider assignment / pickup / 4-digit delivery code, rider app, live rider location to the customer with distance + ETA, rider pushes). Next: Phase 6 (delivery slots, returns/exchanges, prescription and handwritten-list uploads per feature flags).

## 1. Repository layout

```
/
├── CLAUDE.md
├── app/                 Flutter app — roles: CUSTOMER, OWNER, STAFF, RIDER
├── backend/             npm-workspaces monorepo of Node.js + TypeScript microservices
│   ├── packages/        shared libraries (common, config-schema, events)
│   └── services/        one folder per service
├── clients/             one folder per client shop: client.json + brand assets (ONLY per-client source)
├── deploy/              docker-compose, nginx, backup + VPS provisioning scripts
└── docs/                design notes, ADRs, runbooks
```

## 2. Core principles

1. **Adding a client = adding `clients/<slug>/` + running a script.** No forks, no `if (shop == 'x')`. New client needs become config options or feature flags usable by all clients.
2. **Microservices, but cost-aware.** Services are separate deployables with separate data, but all run on ONE VPS via Docker Compose, sharing one Postgres instance (one database per service: `qc_<service>`, plus `qc_<service>_test`) and one Redis. No Kubernetes, no Kafka, no paid managed services. Move to k3s / multiple hosts only when load proves it.
3. **Tenant isolation is non-negotiable** (section 5).
4. **Feature flags are enforced on both sides:** the app hides disabled features; services reject requests for them.
5. **Services own their data.** A service never reads another service's tables. Cross-service data comes from a sync internal API call or from events (copied into a local read model).

## 3. Tech stack

**Backend (every service):** Node.js LTS, TypeScript strict, Express, Prisma, PostgreSQL, Zod, pino. Shared: Redis (cache, rate limits, live rider locations, Socket.IO adapter, event streams). Socket.IO (realtime service only), FCM HTTP v1 with a service account signed by `jose` (notification service only; no firebase-admin, it would bloat every image since images share one node_modules), sharp + multer (media service only). Tests: Vitest + Supertest + real Postgres/Redis via docker compose.

**App:** Flutter, Riverpod 3 (hand-written providers, no codegen), go_router, dio, hand-written immutable models with `fromJson` (adopt freezed later only if models get large), flutter_secure_storage, local cart persistence, socket_io_client, firebase_messaging + flutter_local_notifications, google_maps_flutter (native mobile maps SDK; never call paid Directions/Distance Matrix APIs — use haversine), geolocator (rider location, foreground service while on delivery), cached_network_image, image_picker, flutter_localizations + intl (ARB files).

**Hosting:** one Linux VPS (target 4 vCPU / 8 GB), Docker Compose, Nginx in front (TLS via Let's Encrypt, serves public `/media` from disk). Daily `pg_dump` backup copied off-server. Uptime Kuma self-hosted for monitoring.

## 4. Services

| Service | Owns (database) | Responsibilities |
|---|---|---|
| `gateway` | none | Single public entry. Resolves shop from `X-Shop-Key`, verifies JWT, rate limits, adds request id, forwards to services with internal headers. |
| `tenant` | `tenant` | Shops, runtime settings, feature flags, delivery rules, delivery slots. Public `GET /shop/config`. |
| `identity` | `identity` | OTP, users, roles, JWT issue/refresh, addresses, device tokens. SMS via `SmsProvider`. |
| `catalog` | `catalog` | Categories, products, variants, images metadata, stock + reservations, search. |
| `order` | `order` | Cart quote, orders, status machine, status history, attachments links, returns/exchanges. |
| `payment` | `payment` | `PaymentProvider` (COD, UPI intent, Razorpay later), payment records, UTR submission. |
| `delivery` | `delivery` | Riders, assignment, pickup/deliver flow, delivery OTP, latest rider location (Redis), ETA. |
| `media` | `media` | Uploads, sharp pipeline (WebP 400px/1200px, EXIF strip), private file access checks. |
| `notification` | `notification` | Consumes events, sends FCM pushes (and SMS when needed). Has no public routes. |
| `realtime` | none | Socket.IO server. Pushes events to rooms; receives rider location and forwards to delivery. |
| `reporting` | `reporting` | Consumes order/payment events into sales read models; admin sales endpoints. |

**Communication**
- **Sync:** internal REST over the Docker network (`http://catalog:3000/internal/...`). Only for calls that need an answer now (e.g. order → catalog `reserve-stock`, order → tenant `get-settings`). Use the shared `internalClient` (timeouts, retries for idempotent calls, propagates request id + tenant headers).
- **Async:** domain events on Redis Streams via `packages/events` (`@qc/events`). Publishing = **transactional outbox**: `tx.outboxEvent.create({ data: toOutboxRow(buildEvent(type, shopId, payload)) })` inside the same `db.$transaction` as the change, then `events.kick()` after commit. `createOutboxRelay({ store: prismaOutboxStore(rawPrisma), redis })` (started in `main.ts`) XADDs rows to `qc:events:<stream>` and deletes them (at least once). The `OutboxEvent` model is identical in every publishing service (id = event id, UUID v7).
- **Consumers:** `createConsumer({ group: '<service>', streams, types, handle })`, one consumer group per service, handler runs in `runWithContext({ shopId })` from the event. Failures retry with backoff, then go to `qc:events:dead`. Wrap handlers in `onceOnly(prismaProcessedEvents(db.processedEvent), handler)` (`ProcessedEvent` model, tenant-scoped) and keep them idempotent anyway. New groups start at `$` (only new events).
- **Events now:** `order.placed`, `order.status_changed` (stream `order`), `payment.utr_submitted`, `payment.marked_paid` (stream `payment`), `delivery.status_changed` (stream `delivery`; ASSIGNED with `previousRiderId` on reassignment, PICKED_UP, DELIVERED, CANCELLED). Planned: `product.stock_changed`. Rider location is deliberately **not** an event (ephemeral, every ~10 s): see Delivery below. Names are `<domain>.<past-tense>`; schemas in `packages/events/src/schemas.ts` (Zod, envelope `eventId`, `type`, `version`, `shopId`, `occurredAt`, `payload`). A breaking payload change = new version, never an in-place edit. Consumers: catalog (release stock on CANCELLED/REJECTED, commit reservation on placed), payment (void / confirm), delivery (cancel on CANCELLED/REJECTED, follow the shop's own OUT_FOR_DELIVERY / DELIVERED), notification (pushes), realtime (sockets).
- Order placement saga: order validates quote → catalog reserves stock → payment record → order + `order.placed` (one transaction). Sync compensation on failure is the fast path; durable fallbacks are the event consumers and the **orphan sweepers** in catalog and payment (`src/jobs/orphan-sweeper.ts`, every 5 min): reservations/payments not confirmed after 10 min are checked against `POST /internal/orders/existing` and released/voided if the order never got created.
- Interval jobs: `startIntervalJob(name, ms, fn, logger)` from common (never overlaps itself). Cross-shop scans for jobs use `rawPrisma` in `main.ts` and hand `{ shopId, ... }` rows to job code, which runs per shop in `runWithContext`.

## 5. Multi-tenant rules (MUST follow)

- Every shop-owned table in every service has non-null `shop_id`; every index on it starts with `shop_id`.
- **Gateway** resolves `X-Shop-Key` (shop slug baked into the APK) to `shopId` (cached), rejects unknown/inactive shops, verifies JWT and rejects if `token.shopId !== shopId`. It strips any incoming `x-internal-*` headers, then forwards `x-internal-shop-id`, `x-internal-user-id`, `x-internal-role`, `x-request-id`, and an HMAC signature of them.
- **Services are never exposed publicly** (Docker internal network only) and verify the gateway HMAC before trusting internal headers. `packages/common` puts them into AsyncLocalStorage context.
- Data access goes through the tenant-scoped Prisma client `db` (built in each service's `src/db.ts` with `tenantScopeExtension(TENANT_MODELS)` from `@qc/common`). It adds `shopId` to every `where` (including `findUnique`/`update`/`delete`, which Prisma allows), checks `data.shopId` on writes, refuses to move rows between shops, and throws without tenant context. `rawPrisma` is allowed only in `src/db.ts`, `src/main.ts`, `scripts/` and tests; a test fails if it appears elsewhere in `src/`.
- Every tenant model must be listed in that service's `TENANT_MODELS`.
- Creates pass `shopId: requireShopId()` explicitly (Prisma's types require it); the extension rejects a mismatch.
- Prisma queries are lazy: they run when awaited. Code outside a request (consumers, jobs, tests) must use `runWithContext({ requestId, shopId }, fn)`, which also resolves returned queries inside the context.
- Events always carry `shopId`; consumers run inside that tenant context.
- Users are per shop: `UNIQUE(shop_id, phone)`; same phone at two shops = two accounts.
- Socket.IO rooms are shop-namespaced: `shop:<shopId>:admins` (OWNER/STAFF), `shop:<shopId>:user:<userId>`. No client-joinable rooms: the server decides recipients per event (order's customer, shop admins, assigned and replaced rider), so there is nothing to authorize on join. Sockets authenticate with the access JWT (`auth.token`), are closed when it expires (`session.expired`), and carry only ids + statuses: apps re-fetch over REST.
- Files live under `uploads/<shopId>/...`; private files (prescriptions, handwritten lists, payment proofs) are only served through `media` after access checks.
- Every endpoint needs a cross-tenant test: a user of shop A gets 404 for shop B's resources.

## 6. Client config system

Single source per client: `clients/<slug>/client.json` + assets (`logo.png`, `icon.png`, `google-services.json`).

| Part | Used by | Applied how |
|---|---|---|
| `slug`, `build`, `branding`, `locale` | Flutter build | `tool/gen_flavors.dart` generates the Android flavor + flavor assets; values read via `--dart-define-from-file` |
| `shop`, `delivery`, `payments`, `features`, `catalog` | `tenant` service DB | `client.js sync` upserts them; app fetches at runtime from `GET /shop/config` |

- One Zod schema in `backend/packages/config-schema`; Dart model mirrors it in `app/lib/core/config/`.
- Business-type presets (`grocery`, `clothing`, `bakery`, `electronics`, `pharmacy`, `general`) give defaults; `client.json` overrides.
- Slug format: `^[a-z][a-z0-9]*(_[a-z0-9]+)*$` (e.g. `sharma_kirana`). It is the folder name, `X-Shop-Key`, and Android flavor name.
- Commands:
  - `cd backend && npm run client -- validate [slug]` / `npm run client -- sync <slug>` / `npm run client -- list`
  - `npm run users -- create-owner <slug> <phone> [name]` / `set-role <slug> <phone> <ROLE>` / `list <slug>` (needs tenant service running)
  - `node backend/scripts/placeholder-images.mjs <slug>` creates placeholder logo/icon
  - On a server: `docker compose exec tenant node dist/client.js sync <slug>` and `docker compose exec identity node dist/users.js create-owner <slug> <phone> [name]` (see `docs/deploy.md`)
  - `npm run seed:catalog -- <slug> <owner phone>` (dev only, from backend/) fills a shop with demo categories, products and generated photos through the gateway; skips shops that already have products
  - `cd app && dart run tool/gen_flavors.dart` writes `config/clients/<slug>.json` (flat build defines), flavor assets, launcher-icon configs, `android/app/flavors.gradle`
  - `flutter run --flavor <slug> --dart-define-from-file=config/clients/<slug>.json --dart-define-from-file=config/env.dev.json`

## 7. Domain conventions

- **Money:** integer paise everywhere. Format only in UI.
- **IDs:** UUID v7 primary keys. Human order numbers from a per-shop counter in the `order` service.
- **Products always have ≥1 variant;** price, MRP, unit, stock live on the variant.
- **Stock:** `stock_qty` null = untracked. Reservation on order placement (`UPDATE ... WHERE stock_qty >= qty`), released on cancel/reject.
- **Snapshots:** orders copy item names, variant labels, prices, address, slot.
- **Soft delete** catalog entities (`deleted_at`). Products left out of a `PUT` lose their variants by soft delete (orders keep snapshots).
- **Catalog shape follows shop config:** `catalog.variantStyle` `single` (exactly one variant), `units` (label like "500 g" required), `options` (values only on `variantAxes`, unique combos, label defaults to "M / Red"). `customFields` values are validated against the shop's definitions (unknown keys rejected). Catalog reads them from tenant `GET /internal/shop/config` (cached 60 s).
- **Child rows reference parents with `(shop_id, id)` composite foreign keys** (catalog: category parent, product category, variant/image product), so the database itself refuses cross-shop links. Parents carry `@@unique([shopId, id])`.
- **Search:** `products.search_text` (lower-cased names in all languages, tags, text custom fields) with a hand-written trigram GIN index `(shop_id, search_text gin_trgm_ops)` (pg_trgm + btree_gin) in the catalog init migration. Prisma does not model it: when generating a new catalog migration, delete any `DROP INDEX "products_shop_id_search_text_trgm_idx"` Prisma adds. LIKE wildcards are stripped from queries.
- **Images:** admin uploads `multipart/form-data` (`file`, `kind`) to `POST /api/v1/admin/media`; media detects the format from bytes, applies EXIF rotation, strips metadata, writes WebP `-full` (1200 px) and `-thumb` (400 px) under `MEDIA_ROOT/public/<shopId>/<yyyy>/<mm>/`, max 8 MB / 40 MP. APIs return server-relative URLs (`/media/...`); the app resolves them against `API_BASE_URL`. Production: nginx serves `/media`. Dev: gateway proxies `GET /media/*` to media when `MEDIA_STATIC_URL` is set. Catalog stores copies of URLs it got from media `POST /internal/media/resolve`, which only returns the current shop's files.
- **Customers never see** stock counts, SKUs or `isActive`; they get `inStock` per variant and product.
- **Shop content translations:** `name` + optional `name_i18n` JSONB; fallback to `name`.
- **Order status:** `PLACED → CONFIRMED → PACKED → OUT_FOR_DELIVERY | READY_FOR_PICKUP → DELIVERED | PICKED_UP`; terminal `CANCELLED` (customer, before PACKED) and `REJECTED` (shop). Transition table in `order/src/modules/orders/status.ts`; every change written to history and emitted as `order.status_changed`.
- **Team:** the owner adds riders/staff by phone (`/api/v1/admin/team`, identity, OWNER only; gateway role gate too); they log in with OTP like anyone. Role changes revoke the user's sessions; the owner's own role is locked.
- **Delivery** (delivery service, `qc_delivery`): one `Delivery` row per order, snapshotting address/customer/total/COD amount at assignment (`order` `GET /internal/orders/:id`). Owner/staff assign or reassign a rider while the order is CONFIRMED/PACKED and not picked up (`POST /api/v1/admin/deliveries`; riders from identity `GET /internal/users/riders`). Rider: `GET/POST /api/v1/rider/deliveries[/:id/pickup|deliver]`. Pickup needs the order PACKED and moves it to OUT_FOR_DELIVERY through `POST /internal/orders/:id/status` in the rider's context (order's status machine allows RIDER for exactly PACKED→OUT_FOR_DELIVERY→DELIVERED); delivery needs the 4-digit code the customer sees (`GET /api/v1/deliveries/orders/:orderId`), attempts counted atomically before comparing, max 5, then the shop marks it delivered itself. Delivery transitions are conditional updates; the order-event consumer and the rider's own call can race and both end in the same state. Never show the code to rider or shop views.
- **Rider location:** rider app → realtime socket `rider.location` (≥ 4 s apart server-side, app sends every ≥ 10 s) → delivery `POST /internal/deliveries/location` (rider context) stores it in Redis (`qc:rider-loc:<shopId>:<riderId>`, TTL 120 s) only while the rider has a PICKED_UP delivery and returns who may see it → realtime emits to that customer and the shop admins. Customers see distance + ETA by haversine (×1.3 road factor, 18 km/h) and a free Google Maps link; no Maps SDK/API key yet.
- **Payments:** COD; UPI intent link (not auto-verifiable — customer submits UTR, owner marks paid); Razorpay provider later behind the same interface (`payment/src/providers`). One payment per order (`PENDING → SUBMITTED → PAID`, or `VOID` when the order is cancelled/rejected unpaid). Customers see only their own payments; UPI links keep a literal `@` in `pa=`.
- **Order placement saga** (`order/src/modules/orders/orders.service.ts`): idempotency key check → price from catalog (`/internal/catalog/variants/lookup`; never trust client prices; `expectedTotalPaise` mismatch → `PRICE_CHANGED`) → reserve stock (`/internal/catalog/stock/reserve`, conditional decrement, all or nothing, idempotent per order) → per-shop order number → payment record → order row + items + history in one transaction. Failures compensate (release stock, void payment). Status changes are conditional on the status read (`ORDER_STATUS_CHANGED` for a lost race) and write `order.status_changed` in the same transaction; `CANCELLED`/`REJECTED` release stock and void unpaid payments (sync fast path + event consumers).
- **Push notifications** (notification service): `planFor(event)` decides the audience (shop admins: new order, customer cancellation, UTR submitted; customer: status progress, rejection with reason, payment confirmed) and texts (`messages.ts`, en/gu/hi, per phone locale, localized shop name). Tokens come from identity's device registry (`PUT /api/v1/me/devices`, `POST /internal/devices/targets`, `/internal/devices/remove`; a token moves to whoever logs in on that phone; logout with `deviceToken` removes it; blocked users get nothing). `PUSH_PROVIDER=console` logs pushes; `fcm` needs `FCM_SERVICE_ACCOUNT(_FILE)`. Android channel `orders`, `tag` = order id (newer push replaces older), data `route` = app page to open.
- **Cart** lives on the phone (`cart_v1` in shared preferences) with a display snapshot; `POST /api/v1/orders/quote` (public) is the source of truth for prices, stock issues, delivery fee and minimum order. Pickup has no fee or minimum. Delivery checks pincode list and, when the address has coordinates, haversine radius.
- **Addresses** (identity): per user, first one is default, max 10, soft delete; orders snapshot them. Order reads the user + address through `GET /internal/users/:id/checkout`.
- **SMS:** `SmsProvider`; `SMS_PROVIDER=console` logs OTP in dev. Real providers need DLT-registered templates.
- **Auth:** 6-digit OTP stored as HMAC (`OTP_SECRET`), 5-min expiry, 5 attempts counted atomically before comparing, single use, only the newest code valid. Limits: 30 s resend cooldown, 5/hour per phone, 20/hour per client IP. Access JWT 15 min (RS256, claims `sub`, `shopId`, `role`, `typ: access`; `identity` signs, gateway verifies). Refresh token: opaque, hashed, 30 days, rotated on every use with a conditional update; presenting a rotated token revokes the whole family (session). Role changes and blocks take effect on the next refresh.
- **Dev OTP:** `SMS_PROVIDER=console` logs codes; `OTP_DEV_ECHO=true` also returns `debugCode` (the app prefills it outside production). Both are refused when `NODE_ENV=production`; `NODE_ENV=staging` (real server for pilots) allows them.
- **Client IP** reaches services only as the signed `x-internal-client-ip` header set by the gateway (`getContext().clientIp`). Never read `X-Forwarded-For` in services.
- **App ↔ auth:** never send an access token to `/api/v1/auth/*` (the gateway would reject an expired one during refresh). `AuthInterceptor` (queued) refreshes once on `401 TOKEN_EXPIRED` and retries; parallel requests reuse the new token, because a second refresh with a rotated token would end the session.

## 8. Backend conventions

- Service layout: `services/<name>/{src/{main.ts, app.ts, env.ts, db.ts, modules/<feature>/{<feature>.routes.ts, <feature>.service.ts}, consumers/, jobs/}, prisma/schema.prisma, prisma.config.ts, scripts/, test/}`. One shared `backend/Dockerfile` builds any service (`--build-arg SERVICE=<name>`).
- New service checklist: copy `services/tenant` structure, base app from `createServiceApp()` + `internalAuth()` + `finalizeApp()`, add its database to `deploy/postgres/init-databases.sh` (already lists all planned services), add a gateway route in `services/gateway/src/routes.ts`, add it to `deploy/docker-compose.yml`.
- Build: tsup bundles only `@qc/*` workspace packages (shipped as TS source); every npm package stays external (`skipNodeModulesBundle`). Prisma 7: `prisma-client` generator output in `src/generated/prisma` (gitignored), `@prisma/adapter-pg`.
- Never run destructive Prisma commands (`migrate reset`, `db push --force-reset`) as an agent. Tests use `migrate deploy` against `*_test` databases and clean their own rows.
- New migrations without prompts: `npx prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --script > prisma/migrations/<timestamp>_<name>/migration.sql`, review it (keep hand-written indexes/CHECKs; catalog's trigram index shows up as a DROP), then `npx prisma migrate deploy` (dev DB) and again with `DATABASE_URL=..._test`. `prisma migrate dev` can hang waiting for input in agent shells.
- Shared helpers in `@qc/common`: `cachedShopConfig(tenantClient, ttlMs)` (runtime shop settings per shop), `createInternalClient` (keeps 4xx `code` + `details`, hides 5xx details).
- Public routes under `/api/v1/...` (gateway path prefix maps to service); internal routes under `/internal/...`, never routed by the gateway.
- Controllers thin; logic in services; services use `db`, never `req`.
- Routes use `handler({ params, query, body }, fn)` from `@qc/common`: it validates with Zod, collects all issues into `VALIDATION_FAILED`, and wraps the result in `{ data }`. Env validated with `loadEnv()` at startup; fail fast.
- Errors: `AppError(code, status, message)` → `{ "error": { "code": "ORDER_NOT_CANCELLABLE", "message": "..." } }`. App maps `code` to localized text.
- Responses `{ "data": ... }`; lists `{ "data": [...], "nextCursor": "..." }`: return `toPage(rows, limit, cursorOf, map)` (fetch `limit + 1` rows) from a `handler`. Cursor = last row id; order by `[sortOrder, id]`.
- Every service test suite asserts `findRawPrismaOffenders(srcDir)` from `@qc/common` is empty. Use `uuidv7()` from common when an id is needed before insert.
- Logs are JSON (pino) with `requestId`, `shopId`, `service`. Every service exposes `/health` and `/ready`.
- Shared code goes in `packages/`; services never import from each other.

## 9. Flutter conventions

- Feature-first: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/`.
- Flutter ≥ 3.47: import `package:material_ui/material_ui.dart` (not `package:flutter/material.dart`, deprecated) and `cupertino_ui` for Cupertino; `flutter_localizations` only for `GlobalWidgetsLocalizations`.
- Role areas: customer features, `admin_*` features (OWNER/STAFF), `rider_*` features (RIDER). Rules live in the pure `authRedirect()` (`core/router/app_router.dart`, unit-tested): guests may browse `/`; `/account`, `/admin`, `/rider` need login; staff/riders land on their area. go_router redirects do not unwind pages pushed with `context.push`, so auth changes also navigate explicitly (router listener: logout/expiry → guest home; OTP screen → `Routes.homeFor(role)`).
- Catalog UI: `ProductGridSliver(ProductFilter(...))` (infinite grid, skeletons, load-more retry), `ServerImage` (cached image from a `/media` path), `PriceTag` (price, struck MRP, % off). Model is `ProductCategory` (Flutter exports its own `Category`). Admin forms adapt to `ShopSettings.catalog` (`VariantStyle`, axes, `CustomFieldDef`). Photo picking goes through `photoSourceProvider` (overridden in tests).
- Ordering UI: `cartProvider` (sync, persisted), `cartQuoteProvider` (debounced server quote), `CartBar` (sticky, on browsing screens), `AddToCartButton` (ADD → stepper; multi-variant products open a picker). Checkout keeps one idempotency key per checkout screen. Login from the cart passes `?from=/checkout`; the router's auth listener opens it after login (`pendingReturnToProvider`). External apps (UPI, dialer) go through `externalLauncherProvider`. Live updates: `orderLiveUpdatesProvider` (kept alive by `QcApp`) invalidates order/payment providers on socket events and after every reconnect; order screens poll (customer 30 s, owner 20 s) only while `ref.isLive` is false.
- Realtime + push: `realtimeChannelProvider` opens `SocketRealtimeChannel` (Socket.IO, `REALTIME_URL` define, defaults to `API_BASE_URL`; null in tests = off) for the signed-in user; the token comes from `socketTokenProvider` on every (re)connect. Push: `pushServiceProvider` (`NoPushService` unless the client has Firebase defines; `main()` starts `FirebasePushService`, initialized from `FIREBASE_*` defines generated from `clients/<slug>/google-services.json`, no google-services Gradle plugin). `pushRegistrationProvider` registers the token after login / on rotation / language change; tapped notifications open `data.route` through the router if the role may see it. Uses the classic FCM registration token (`getToken`, deprecated in firebase_messaging 17 in favour of installation ids; switch app and server together).
- Provider graph rule: `dioProvider`'s interceptor must not read `authApiProvider` (it depends on `dioProvider`; Riverpod throws `CircularDependencyError` at refresh time, so every request fails after the token expires). It calls `refreshSession(publicDio, token)`. `test/core/session_refresh_test.dart` runs the real graph with a fake HTTP server (`httpAdapterProvider`): use it for anything touching auth wiring.
- Android: `compileSdk = 37` (flutter_local_notifications), core library desugaring on, `POST_NOTIFICATIONS` permission, default FCM channel `orders` in the manifest; fine/coarse location + `FOREGROUND_SERVICE_LOCATION` for riders.
- Delivery UI: `features/delivery` (models, `HttpDeliveryRepository` behind role interfaces, `AdminRiderCard` + assign sheet, `CustomerDeliveryCard`), `features/rider_deliveries` (job list, job screen with OTP dialog, `locationSharingProvider` kept alive by `QcApp`: shares only while a job is PICKED_UP, through `LocationSource` (geolocator foreground service; falls back to the plain GPS provider when Google's fused provider refuses because "location accuracy" is off), `SharingBanner` tells the rider when permission/GPS is missing), `features/admin_team` (owner only; route redirect + tile hidden for staff). Live socket events `delivery.updated` / `rider.location` are handled in `orderLiveUpdatesProvider` (`riderLocationsProvider` holds the latest per order).
- Layout rules learned on 360 dp phones: theme FilledButtons are full width (`Size.fromHeight`), so give one inside a `Row` an explicit `minimumSize`; a `Column` inside `bottomNavigationBar` needs `mainAxisSize.min`; put long localized labels on their own line (Wrap/Column), not beside buttons. Widget tests call `usePhoneScreen(tester)`.
- Quick-commerce UX standards: skeleton loaders, optimistic cart updates, sticky cart bar, debounced instant search, cached images, pull-to-refresh, graceful offline state.
- No hard-coded strings: ARB files in `lib/l10n/` for en, gu, hi; add keys to all three in the same change. Access with `context.l10n`; map backend error codes in `core/l10n/l10n.dart#errorMessage`. Bundle Noto Sans fonts if Gujarati/Devanagari rendering is poor on target devices.
- Providers live in `lib/core/providers.dart` (core) or the feature's `presentation/` folder. `clientConfigProvider`, `envConfigProvider`, `sharedPreferencesProvider` are overridden in `main()` and in tests. Repositories sit behind interfaces so widget tests override them.
- No client-specific code or hard-coded colors: use `ClientConfig` (build-time) and `ShopSettings` (runtime provider). Flags via `featureProvider(Feature.x)`.

## 10. Testing

- Run backend: `cd backend && npm run infra:up && npm test` (all workspaces) and `npm run typecheck`.
- Tests that touch Redis Streams use Redis database 15 (`TEST_REDIS_URL`, default `redis://localhost:6380/15`) so they never consume events of services running in development. Dev ports: gateway 4000, tenant 4001, identity 4002, catalog 4003, media 4004, payment 4005, order 4006, realtime 4007, notification 4008, delivery 4009. Emulator GPS: `adb emu geo fix <lng> <lat>` (location must be on: `adb shell cmd location set-location-enabled true`).

- Per service: unit tests (status machine, pricing, stock, assignment), API tests with Supertest on real Postgres/Redis, mandatory cross-tenant tests.
- Contract tests for event schemas and internal endpoints in `packages/events`.
- App: controller/repository unit tests, widget tests for key screens.

## 11. Do not

- Do not add paid cloud services, Firebase services other than FCM, Kafka, or Kubernetes without discussion.
- Do not let one service query another service's schema.
- Do not publish events outside the outbox.
- Do not store money as floats.
- Do not trust `shopId`, prices or totals from the client; recompute server-side.
- Do not write per-client code branches.
- Do not commit `.env`, production `google-services.json`, keys, or `uploads/`.
