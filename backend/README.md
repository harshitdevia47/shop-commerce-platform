# Backend (microservices)

npm-workspaces monorepo. See `../CLAUDE.md` for architecture, tenant rules and conventions.

```
packages/common         context, internal auth (HMAC), tenant-scoped Prisma extension, errors, handler, logger
packages/config-schema  client.json schema + business-type presets (shared with tools)
services/gateway        public entry: X-Shop-Key -> shop, JWT, rate limit, signed proxy
services/tenant         shops + runtime settings; GET /api/v1/shop/config
```

## Local development

```sh
npm install
npm run infra:up                              # Postgres :5433 + Redis :6380 (Docker)
npm run keys:dev                              # RS256 dev keys in .keys/
cp services/tenant/.env.example services/tenant/.env
cp services/gateway/.env.example services/gateway/.env
npm run migrate:deploy -w @qc/tenant
npm run client -- validate && npm run client -- sync sharma_kirana

npm run dev -w @qc/tenant                     # :4001
npm run dev -w @qc/gateway                    # :4000
curl localhost:4000/api/v1/shop/config -H 'X-Shop-Key: sharma_kirana'
```

## Checks

```sh
npm run typecheck
npm test            # needs infra:up (integration tests use qc_*_test databases)
```

## Production

`deploy/docker-compose.yml` runs every service from the shared `Dockerfile`
(`docker build --build-arg SERVICE=<name> .`) behind Nginx on one VPS.
