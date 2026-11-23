# One Dockerfile for every service:
#   docker build -f backend/Dockerfile --build-arg SERVICE=tenant -t qc-tenant backend
# Build context is the backend/ directory.

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.base.json ./
COPY packages ./packages
COPY services ./services
RUN npm ci --no-audit --no-fund
ARG SERVICE
RUN test -n "$SERVICE" && npm run build -w "@qc/${SERVICE}"
RUN npm prune --omit=dev --no-audit --no-fund

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
ARG SERVICE
WORKDIR /app
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/services/${SERVICE} ./services/${SERVICE}
WORKDIR /app/services/${SERVICE}
RUN rm -rf src test
USER node
EXPOSE 3000
# Services with a Prisma schema apply pending migrations before starting.
CMD ["sh", "-c", "if [ -f prisma/schema.prisma ]; then node /app/node_modules/prisma/build/index.js migrate deploy; fi && exec node --enable-source-maps dist/main.js"]
