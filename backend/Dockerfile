# ONE image for every service (build context: backend/):
#   docker build -f backend/Dockerfile -t qc-backend backend
# Each container runs the service whose folder is its working directory
# (docker-compose sets `working_dir: /app/services/<name>`).
#
# One image instead of one per service: a single npm install + build (a 4 GB server can build it),
# and node_modules is stored once on disk instead of eleven times.

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.base.json ./
COPY packages ./packages
COPY services ./services
RUN npm ci --no-audit --no-fund
RUN npm run build
RUN npm prune --omit=dev --no-audit --no-fund \
 && rm -rf services/*/src services/*/test packages/*/test \
 && npm cache clean --force

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/packages ./packages
COPY --from=build --chown=node:node /app/services ./services
# Writable mount points for services that store files (media); named volumes inherit this ownership.
RUN mkdir -p /data/public /data/private && chown -R node:node /data
USER node
EXPOSE 3000
# Services with a Prisma schema apply pending migrations before starting.
CMD ["sh", "-c", "if [ -f prisma/schema.prisma ]; then node /app/node_modules/prisma/build/index.js migrate deploy; fi && exec node --enable-source-maps dist/main.js"]
