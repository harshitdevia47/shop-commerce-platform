# CLAUDE.md

Multi-tenant quick-commerce ordering platform (Zepto/Blinkit-style architecture) for local shops in small Indian cities. One backend platform (microservices) and one Flutter codebase serve every client shop. Each client gets a separately branded APK built from the same code.

> **Status:** Phase 0 (foundations) done 2026-11-23: shared packages, gateway, tenant service, client config pipeline, Flutter skeleton. Next: Phase 1 (identity service + login).

## 1. Repository layout

```
/
├── CLAUDE.md
├── app/                 Flutter app — roles: CUSTOMER, OWNER, STAFF, RIDER
├── backend/             npm-workspaces monorepo of Node.js + TypeScript microservices
│   ├── packages/        shared libraries (common, config-schema; events in Phase 4)
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

**Backend (every service):** Node.js LTS, TypeScript strict, Express, Prisma, PostgreSQL, Zod, pino. Shared: Redis (cache, rate limits, live rider locations, Socket.IO adapter, event streams). Socket.IO (realtime service only), firebase-admin for FCM only (notification service only), sharp + multer (media service only). Tests: Vitest + Supertest + real Postgres/Redis via docker compose.

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
- **Async:** domain events on Redis Streams via `packages/events`. Every service publishes with the **transactional outbox** pattern (`outbox_events` table written in the same DB transaction, relay worker publishes). Consumers are idempotent (`processed_events` table keyed by event id).
- Event names are `<domain>.<past-tense>`: `order.placed`, `order.status_changed`, `payment.marked_paid`, `delivery.assigned`, `delivery.location_updated`, `product.stock_changed`. Event payload schemas live in `packages/events` (Zod) and always include `eventId`, `shopId`, `occurredAt`, `version`.
- Order placement saga: order validates quote → catalog reserves stock → order created (+ outbox) → payment record created → on failure/cancel, compensating `release-stock`.

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
- Socket.IO rooms are shop-namespaced: `shop:<shopId>:admins`, `user:<userId>`, `order:<orderId>` (join allowed only for that order's customer, shop staff, and assigned rider).
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
  - `cd backend && npm run client -- validate [slug]` / `npm run client -- sync <slug>` / `npm run client -- list` (`create-owner` arrives with identity in Phase 1)
  - `node backend/scripts/placeholder-images.mjs <slug>` creates placeholder logo/icon
  - `cd app && dart run tool/gen_flavors.dart` writes `config/clients/<slug>.json` (flat build defines), flavor assets, launcher-icon configs, `android/app/flavors.gradle`
  - `flutter run --flavor <slug> --dart-define-from-file=config/clients/<slug>.json --dart-define-from-file=config/env.dev.json`

## 7. Domain conventions

- **Money:** integer paise everywhere. Format only in UI.
- **IDs:** UUID v7 primary keys. Human order numbers from a per-shop counter in the `order` service.
- **Products always have ≥1 variant;** price, MRP, unit, stock live on the variant.
- **Stock:** `stock_qty` null = untracked. Reservation on order placement (`UPDATE ... WHERE stock_qty >= qty`), released on cancel/reject.
- **Snapshots:** orders copy item names, variant labels, prices, address, slot.
- **Soft delete** catalog entities (`deleted_at`).
- **Shop content translations:** `name` + optional `name_i18n` JSONB; fallback to `name`.
- **Order status:** `PLACED → CONFIRMED → PACKED → OUT_FOR_DELIVERY | READY_FOR_PICKUP → DELIVERED | PICKED_UP`; terminal `CANCELLED` (customer, before PACKED) and `REJECTED` (shop). Transition table in `order/src/modules/orders/status.ts`; every change written to history and emitted as `order.status_changed`.
- **Delivery:** shop's own riders (RIDER role). Owner assigns (auto-assign later). Rider marks picked up → `OUT_FOR_DELIVERY`; delivery confirmed with a 4-digit OTP shown to the customer. Rider app sends location every ~10 s only while a delivery is active (Android foreground service); latest location kept in Redis with TTL, not in Postgres.
- **Payments:** COD; UPI intent link (not auto-verifiable — customer submits UTR, owner marks paid); Razorpay provider later behind the same interface.
- **SMS:** `SmsProvider`; `SMS_PROVIDER=console` logs OTP in dev. Real providers need DLT-registered templates.
- **Auth:** 6-digit OTP, hashed, 5-min expiry, 5 attempts, rate limited per phone + IP (Redis). Access JWT 15 min (RS256: `identity` signs, gateway verifies with public key). Refresh 30 days, hashed, rotated; reuse revokes the family.

## 8. Backend conventions

- Service layout: `services/<name>/{src/{main.ts, app.ts, env.ts, db.ts, modules/<feature>/{<feature>.routes.ts, <feature>.service.ts}, consumers/, jobs/}, prisma/schema.prisma, prisma.config.ts, scripts/, test/}`. One shared `backend/Dockerfile` builds any service (`--build-arg SERVICE=<name>`).
- New service checklist: copy `services/tenant` structure, base app from `createServiceApp()` + `internalAuth()` + `finalizeApp()`, add its database to `deploy/postgres/init-databases.sh` (already lists all planned services), add a gateway route in `services/gateway/src/routes.ts`, add it to `deploy/docker-compose.yml`.
- Build: tsup bundles only `@qc/*` workspace packages (shipped as TS source); every npm package stays external (`skipNodeModulesBundle`). Prisma 7: `prisma-client` generator output in `src/generated/prisma` (gitignored), `@prisma/adapter-pg`.
- Never run destructive Prisma commands (`migrate reset`, `db push --force-reset`) as an agent. Tests use `migrate deploy` against `*_test` databases and clean their own rows.
- Public routes under `/api/v1/...` (gateway path prefix maps to service); internal routes under `/internal/...`, never routed by the gateway.
- Controllers thin; logic in services; services use `db`, never `req`.
- Routes use `handler({ params, query, body }, fn)` from `@qc/common`: it validates with Zod, collects all issues into `VALIDATION_FAILED`, and wraps the result in `{ data }`. Env validated with `loadEnv()` at startup; fail fast.
- Errors: `AppError(code, status, message)` → `{ "error": { "code": "ORDER_NOT_CANCELLABLE", "message": "..." } }`. App maps `code` to localized text.
- Responses `{ "data": ... }`; lists `{ "data": [...], "nextCursor": "..." }`.
- Logs are JSON (pino) with `requestId`, `shopId`, `service`. Every service exposes `/health` and `/ready`.
- Shared code goes in `packages/`; services never import from each other.

## 9. Flutter conventions

- Feature-first: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/`.
- Role areas: customer features, `admin_*` features (OWNER/STAFF), `rider_*` features (RIDER). Router `redirect` gates by role.
- Quick-commerce UX standards: skeleton loaders, optimistic cart updates, sticky cart bar, debounced instant search, cached images, pull-to-refresh, graceful offline state.
- No hard-coded strings: ARB files in `lib/l10n/` for en, gu, hi; add keys to all three in the same change. Access with `context.l10n`; map backend error codes in `core/l10n/l10n.dart#errorMessage`. Bundle Noto Sans fonts if Gujarati/Devanagari rendering is poor on target devices.
- Providers live in `lib/core/providers.dart` (core) or the feature's `presentation/` folder. `clientConfigProvider`, `envConfigProvider`, `sharedPreferencesProvider` are overridden in `main()` and in tests. Repositories sit behind interfaces so widget tests override them.
- No client-specific code or hard-coded colors: use `ClientConfig` (build-time) and `ShopSettings` (runtime provider). Flags via `featureProvider(Feature.x)`.

## 10. Testing

- Run backend: `cd backend && npm run infra:up && npm test` (all workspaces) and `npm run typecheck`.

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
