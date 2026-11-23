# Deploying to a VPS (staging or production)

One Linux VPS (4 vCPU / 8 GB, Ubuntu 24.04 LTS) runs everything with Docker Compose.
Only nginx is reachable from the internet; services talk on the internal Docker network.

## 1. Server setup (once)

```bash
# as root
adduser deploy && usermod -aG sudo deploy
apt update && apt install -y docker.io docker-compose-v2 git ufw
usermod -aG docker deploy
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

Client folders (`clients/<slug>/client.json`) are mounted into the tenant container read-only.

```bash
docker compose exec tenant node dist/client.js validate
docker compose exec tenant node dist/client.js sync sharma_kirana
docker compose exec identity node dist/users.js create-owner sharma_kirana 9876543210 "Ramesh Sharma"
```

## 4. TLS (Let's Encrypt)

1. Point the domain's A record at the server.
2. `docker compose stop nginx && sudo apt install -y certbot && sudo certbot certonly --standalone -d api.example.in`
3. Copy `fullchain.pem` and `privkey.pem` to `deploy/nginx/certs/` (gitignored), add a `listen 443 ssl`
   server block to `deploy/nginx/nginx.conf` (copy the `/media/`, `/socket.io/` and `/` locations into it),
   make port 80 redirect to https, `docker compose up -d nginx`. Renew monthly with cron.
4. Build the app with a `config/env.prod.json` (`API_BASE_URL=https://api.example.in`, `ENV=prod`).

## 5. Update

```bash
git pull && docker compose up -d --build
```

## 6. Backups

Daily database dump copied off the server (cron as `deploy`):

```bash
docker compose exec -T postgres pg_dumpall -U qc | gzip > ~/backups/qc-$(date +%F).sql.gz
```

Uploaded images live in the `qc_media` and `qc_media_private` volumes:

```bash
docker run --rm -v qc_media:/data -v ~/backups:/out alpine tar czf /out/media-$(date +%F).tgz -C /data .
```

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

## 8. Events (how services stay in sync)

Order and payment write events to their own `outbox_events` table in the same transaction as the change;
a relay publishes them to Redis Streams (`qc:events:order`, `qc:events:payment`). Catalog (stock release),
payment (void), notification (push) and realtime (live screens) consume them. Events that keep failing land in
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
