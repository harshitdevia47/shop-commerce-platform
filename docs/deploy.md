# Deploying to a VPS (staging or production)

One Linux VPS runs everything with Docker Compose. **2 vCPU / 4 GB RAM, 80 GB disk, Ubuntu 24.04 LTS** is
enough to start: measured on the full stack, all eleven services + Postgres + Redis + nginx use about
650 MB when idle (each Node service 30–60 MB). Move to 8 GB when Postgres needs more memory for many shops.
All services run from ONE Docker image (`qc-backend`, about 760 MB), built once.
Only nginx is reachable from the internet; services talk on the internal Docker network.

## 1. Server setup (once)

```bash
# as root
adduser deploy && usermod -aG sudo deploy
apt update && apt install -y docker.io docker-compose-v2 git ufw
usermod -aG docker deploy
# 2 GB swap: a safety net for the image build on a 4 GB server
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw enable
```

Log in as `deploy`, then:

```bash
git clone <repo-url> qc && cd qc/deploy
cp .env.example .env            # fill in every value (see below)
mkdir -p secrets
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out secrets/jwt-private.pem
openssl pkey -in secrets/jwt-private.pem -pubout -out secrets/jwt-public.pem
chmod 600 secrets/*.pem .env
```

`.env` values:

| Key | Staging | Production |
|---|---|---|
| `NODE_ENV` | `staging` | `production` |
| `POSTGRES_PASSWORD`, `INTERNAL_HMAC_SECRET`, `OTP_SECRET` | `openssl rand -hex 32` each | new values, never reuse staging ones |
| `SMS_PROVIDER` | `console` (OTP printed in `docker compose logs identity`) | a real DLT-registered provider (Phase 8); `console` is refused |
| `OTP_DEV_ECHO` | `true` only for internal testers | must be `false` (refused otherwise) |
| `PUSH_PROVIDER` | `console` (pushes printed in `docker compose logs notification`) until Firebase is set up (section 7) | `fcm` |

## 2. Start

```bash
docker compose up -d --build
docker compose ps                         # every service running
curl -s localhost/health                  # {"status":"ok","service":"gateway"}
```

Each service applies its own pending Prisma migrations on start (`migrate deploy`, never destructive).

## 3. Add shops and owners

Normally from the laptop: `cd backend && npm run new-shop` creates the shop, its owner and its
subscription on the server through the platform service (section 6e; needs `backend/.env.platform`).
By hand on the server:

Client folders (`clients/<slug>/client.json`) are mounted into the tenant container read-only.

```bash
docker compose exec tenant node dist/client.js validate
docker compose exec tenant node dist/client.js sync sharma_kirana
docker compose exec identity node dist/users.js create-owner sharma_kirana 9876543210 "Ramesh Sharma"
```

## 4. TLS (Let's Encrypt)

1. Point the domain's A record (e.g. `api.example.in`) at the server; the stack is running with the plain
   HTTP config (it already serves `/.well-known/acme-challenge/` from the `certbot-webroot` volume).
2. Get the certificate (no downtime):

   ```bash
   docker run --rm -v qc_certbot-webroot:/var/www/certbot -v "$PWD/nginx/certs:/etc/letsencrypt" \
     certbot/certbot:v4.1.1 certonly --webroot -w /var/www/certbot -d api.example.in \
     --email you@example.in --agree-tos -n
   ```
3. `cp nginx/nginx.tls.conf nginx/nginx.conf`, replace `api.example.in` with your domain,
   `docker compose up -d nginx`. Port 80 now redirects to HTTPS (HSTS on).
4. Renewal (cron as `deploy`, daily; certbot only renews within 30 days of expiry):

   ```
   30 3 * * * cd ~/qc/deploy && docker run --rm -v qc_certbot-webroot:/var/www/certbot -v "$PWD/nginx/certs:/etc/letsencrypt" certbot/certbot:v4.1.1 renew -q && docker compose exec -T nginx nginx -s reload
   ```
5. Build the apps with `config/env.prod.json` = `{"ENV": "prod", "API_BASE_URL": "https://api.example.in"}`.
   Production builds refuse any `http://` address (Flutter's HTTP client ignores Android's cleartext policy).

## 5. Update

```bash
git pull
docker compose build      # builds the one backend image (a few minutes; every service uses it)
docker compose up -d
```

Each service applies its own pending migrations on start. Old images pile up after updates:
`docker image prune -f` frees the space.

## 6. Backups and restore check

`scripts/backup.sh` dumps every database, both photo volumes (public and private) and Redis (undelivered
events), checks the dump is not empty, writes checksums, keeps `BACKUP_KEEP_DAYS` (14) days locally and,
when `RCLONE_REMOTE` is set in `.env` (e.g. Backblaze B2 / S3 via `rclone config`), copies each run off
the server. `scripts/restore-check.sh` restores the latest dump into a throwaway Postgres and counts
shops/users/orders: a backup is only proven once it has been restored.

```
15 2 * * *  cd ~/qc/deploy && ./scripts/backup.sh >> ~/backups/backup.log 2>&1
45 2 * * 0  cd ~/qc/deploy && ./scripts/restore-check.sh >> ~/backups/backup.log 2>&1
```

Full restore on a new server: install as in section 1, `docker compose up -d postgres redis`,
`gunzip -c postgres.sql.gz | docker compose exec -T postgres psql -U qc -d postgres`, untar the photo
archives into the `qc_media` / `qc_media_private` volumes, then `docker compose up -d`.

## 6a. Monitoring

`docker compose --profile monitoring up -d uptime-kuma`, then `ssh -L 3001:localhost:3001 deploy@server`
and open http://localhost:3001. Add monitors (it runs inside the Docker network):

- HTTPS `https://api.example.in/health` and `https://admin.example.in/health` (public, every 60 s; certificate expiry alert on)
- HTTP `http://<service>:3000/ready` for tenant, identity, catalog, media, order, payment, delivery,
  notification, reporting, platform (database reachability)
- TCP `postgres:5432`, `redis:6379`

Point notifications at email (Settings → Notifications → SMTP: `smtp.gmail.com`, port 465, your Gmail and
the same app password as section 6e), or Telegram. Also watch the dead-letter stream (section 10) and disk space
(`df -h`, Docker images: `docker system df`; prune old images after updates with `docker image prune`).

## 6b. Login codes (OTP) for production

**WhatsApp (chosen; no DLT).** Uses Meta's WhatsApp Business Cloud API directly (no reseller).

1. business.facebook.com: create a Meta Business account and complete **business verification**
   (business name, address, a document such as GST / Udyam / shop licence; a few days).
2. developers.facebook.com → create an app (type Business) → add **WhatsApp**. Add a phone number that is
   **not** used in the WhatsApp app (a new SIM or landline), verify it, and get the display name approved
   (e.g. your platform's name).
3. WhatsApp Manager → Message templates → create template `login_code`, category **Authentication**,
   with a **Copy code** button, in English, Gujarati and Hindi (same name, three languages). Meta writes the
   text ("123456 is your verification code."); approval is usually quick.
4. Business settings → System users → add an admin system user, give it the app with
   `whatsapp_business_messaging`, generate a **permanent token**.
5. Add a payment method in WhatsApp Manager (authentication messages are charged per message; see Meta's
   current India rate card).
6. On the server: token in `secrets/sms/whatsapp-token` (`chmod 600`); in `.env`:
   `SMS_PROVIDER=whatsapp`, `WHATSAPP_PHONE_NUMBER_ID=<id>`, `WHATSAPP_OTP_TEMPLATE=login_code`,
   `WHATSAPP_ACCESS_TOKEN_FILE=/run/sms/whatsapp-token`; `docker compose up -d identity`.

The app shows "Sent on WhatsApp to +91…" and asks for the code in the app's language. Customers without
WhatsApp cannot receive it: an SMS fallback (a provider's shared OTP route, or MSG91 after DLT) can be added
behind the same switch.

**SMS via MSG91 (needs DLT).** Register the business and a sender ID on a DLT portal, an OTP template, then a
Flow template in MSG91 with variable `otp`; key in `secrets/sms/msg91-auth-key`; `.env`: `SMS_PROVIDER=msg91`,
`MSG91_OTP_TEMPLATE_ID=<flow id>`, `MSG91_AUTH_KEY_FILE=/run/sms/msg91-auth-key`.

## 6c. Online payments (Razorpay)

Each shop uses its own Razorpay account (money goes to the shop).

1. Shop completes Razorpay KYC; in the Razorpay dashboard create API keys and a webhook:
   URL `https://api.example.in/api/v1/webhooks/razorpay/<slug>`, events `payment.captured` and `order.paid`,
   with a webhook secret.
2. On the server: `secrets/razorpay/<slug>.json` (`chmod 600`):
   `{"keyId": "rzp_live_...", "keySecret": "...", "webhookSecret": "..."}`; `docker compose up -d payment`.
3. In `clients/<slug>/client.json` set `"payments": { ..., "razorpay": { "enabled": true } }` and sync.

The app opens Razorpay Checkout right after the order is placed; the payment is marked paid only after the
server verifies Razorpay's signature (or the signed webhook arrives if the app was closed). Refunds for
cancelled paid orders are done in the Razorpay dashboard. Test first with `rzp_test_` keys.

## 6d. Privacy policy and terms

Every shop has two public pages, filled in with that shop's name, address and enabled options:

- `https://api.your-domain.in/legal/<slug>/privacy` (Play Console → App content → Privacy policy)
- `https://api.your-domain.in/legal/<slug>/terms`

The apps link to them on the login screen and in Account. Set the operator details in `.env`
(`LEGAL_OPERATOR_NAME`, `LEGAL_CONTACT_EMAIL`, `LEGAL_CITY` for courts, `LEGAL_EFFECTIVE_DATE`), then
`docker compose up -d tenant`. Change `LEGAL_EFFECTIVE_DATE` whenever the text changes. The text lives in
`backend/services/tenant/src/modules/legal/legal.pages.ts` and describes what the platform collects: update
it when that changes, and have it reviewed by a lawyer before launch.

## 6e. Platform admin: Shop Admin app (subscriptions)

The platform owner's own Android app (`platform_app/`, "Shop Admin") talks to the platform service at
`https://admin.<domain>`: which shops paid, Mark paid (UPI), Extend 7 days, Pause / Resume online orders,
app numbers per shop. At 09:00 IST it gets a **phone notification** for each shop that became 7 days
overdue (email only while no phone is registered). Nothing is paused automatically.

1. **DNS + certificate:** A record `admin.<domain>` → the server; `certbot ... -d admin.example.in`
   (section 4); in `nginx/nginx.conf` (copied from `nginx.tls.conf`) replace `admin.example.in`.
2. **Database** (only on servers created before the admin existed):
   `docker compose exec postgres psql -U qc -d postgres -c "CREATE DATABASE qc_platform"`
3. **Gmail app password** (login codes, and alerts while no phone is registered): Google Account →
   Security → 2-Step Verification on → "App passwords" → create "shop admin" → the 16 letters into
   `deploy/secrets/mail/gmail-app-password` (no spaces, `chmod 600`).
4. **`.env`:** `ADMIN_EMAILS` (your Gmail), `LOGIN_CODE_SECRET` (`openssl rand -hex 32`),
   `MAIL_PROVIDER=gmail`, `MAIL_USER`, `MAIL_APP_PASSWORD_FILE=/run/mail/gmail-app-password`,
   `PLATFORM_UPI_ID` (where shops pay you), `PLATFORM_DEFAULT_FEE_RUPEES`. Phone notifications use the
   same `PUSH_PROVIDER=fcm` + Firebase service account as section 7.
5. **Laptop → server for `npm run new-shop`:** `node backend/scripts/platform-token.mjs`; hash →
   `PLATFORM_API_TOKEN_HASH` in `deploy/.env`; on the laptop `backend/.env.platform` with
   `PLATFORM_URL=https://admin.<domain>`, `PLATFORM_TOKEN=<token>`, `PLATFORM_DEFAULT_FEE_RUPEES=999`.
6. `docker compose up -d platform nginx`.
7. **The app:** in the Firebase project (section 7) add an Android app `in.qcommerce.platformadmin`,
   download its `google-services.json` into `platform_app/` (gitignored), then on the laptop:

   ```bash
   cd platform_app
   dart run tool/firebase_defines.dart          # writes config/firebase.json
   echo '{"ENV":"prod","ADMIN_API_URL":"https://admin.<domain>"}' > config/env.prod.json
   flutter build apk --release --dart-define-from-file=config/env.prod.json --dart-define-from-file=config/firebase.json
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
   Log in with your Gmail and the code; allow notifications. Shops created before show **Not set up**:
   open each and set its fee and due day.

Development: `cd platform_app && flutter run --dart-define-from-file=config/env.dev.json` with
`adb reverse tcp:4011 tcp:4011` (the platform service on the laptop; `MAIL_PROVIDER=console` prints the
login code in its log).

How it reaches the shop apps: the platform service sets the shop's `subscription` in tenant (`ok`, `due`
with amount/date/UPI ID, `paused`) after every action and once an hour. `due` shows the owner a reminder
card with Pay by UPI; `paused` makes the order service refuse new orders (`SHOP_SUSPENDED`) and customers
see "Please call the shop". Mark paid resumes and moves the due date ahead.

## 7. Push notifications (Firebase Cloud Messaging)

FCM is the only Firebase service used. One Firebase project serves every shop app.

1. In the Firebase console create a project (Analytics off), then add an Android app per shop with the
   shop's `build.androidPackage` from `client.json`. Download its `google-services.json` into
   `clients/<slug>/` (gitignored).
2. `cd app && dart run tool/gen_flavors.dart`: the app's Firebase values become build defines
   (no google-services Gradle plugin). Builds without the file simply have no push.
3. Project settings → Service accounts → Generate new private key. Copy it to the server as
   `deploy/secrets/fcm/service-account.json` (`chmod 600`), then in `.env`:
   `PUSH_PROVIDER=fcm` and `FCM_SERVICE_ACCOUNT_FILE=/run/fcm/service-account.json`.
   `docker compose up -d notification`.

Who gets what: new orders, customer cancellations and UPI references go to the shop's owner and staff;
order progress and payment confirmations go to the customer. Each phone gets the text in its app language.

## 8. Riders

The owner adds riders in the app (Dashboard → Team) by phone number; riders install the same shop app and
log in with OTP. From a server shell: `docker compose exec identity node dist/users.js set-role <slug> <phone> RIDER`.
Rider phones share their location only while carrying an order; Android shows a "Sharing your location"
notification during that time.

## 9. Shop options

Per shop in `clients/<slug>/client.json` (then `client.js sync <slug>`):

- `features.deliverySlots` with `delivery.slots` (windows like `{"start": "09:00", "end": "12:00"}`, `daysAhead`,
  `capacityPerSlot`, `cutoffMinutes`).
- `features.handwrittenListUpload` / `features.prescriptionUpload`: customers send photos; the shop sets the amount of
  a list order when accepting it.
- `features.returns` with `returns: { "windowDays": 7, "allowExchange": true }`.

Customer photos are private files in the `qc_media_private` volume (back it up with the public one). nginx never
serves them; the media service checks who asks.

## 10. Events (how services stay in sync)

Order and payment write events to their own `outbox_events` table in the same transaction as the change;
a relay publishes them to Redis Streams (`qc:events:order`, `qc:events:payment`, `qc:events:delivery`). Catalog (stock release),
payment (void), delivery (cancel/sync), notification (push) and realtime (live screens) consume them. Events that keep failing land in
`qc:events:dead`:

```bash
docker compose exec redis redis-cli XLEN qc:events:dead
docker compose exec redis redis-cli XRANGE qc:events:dead - + COUNT 5
docker compose exec redis redis-cli XINFO GROUPS qc:events:order   # lag per consumer
```

Redis keeps the streams on disk (`appendonly yes`); back up the `qc_redisdata` volume with the database if
you want undelivered events to survive a server loss.

## Local smoke test of the production stack

```bash
cd deploy && cp .env.example .env   # NODE_ENV=staging, random secrets, keys in secrets/
docker compose -p qc-smoke up -d --build
```

Nginx binds port 80; use an override file with `ports: !override ["8088:80"]` if 80 is taken.

## Security notes

- Only nginx is published (80/443); Postgres, Redis and every service stay on the internal network.
  Uptime Kuma binds to localhost only.
- Secrets live in `deploy/.env` and `deploy/secrets/` (gitignored, `chmod 600`): JWT keys, FCM service
  account, MSG91 key, Razorpay keys. Rotate the internal HMAC secret and JWT keys if a server is compromised
  (all users log in again).
- `npm audit --omit=dev` (2026-11-24): one high-severity ReDoS in `effect`, used only by the Prisma CLI to
  read our own config files (no user input reaches it); clears with the next Prisma release. Dev-only tools
  (vitest/esbuild) are not in the images.
