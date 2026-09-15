# =======================================================================
# Stage 1: Base - Setup Alpine with Node and Corepack (for pnpm)
# =======================================================================
FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# =======================================================================
# Stage 2: Pruner - Isolate the target app and its dependencies
# =======================================================================
FROM base AS pruner
WORKDIR /app
# Pass the app name as a build argument (e.g., "api", "web", "dashboard")
ARG APP_NAME
COPY . .
# Prune the workspace to only include what's needed for the target app
RUN npx turbo@^2.10.12 prune --scope=${APP_NAME} --docker

# =======================================================================
# Stage 3: Installer - Install dependencies (cache optimized)
# =======================================================================
FROM base AS installer
WORKDIR /app

# Install dependencies based on the pruned lockfile
COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

# =======================================================================
# Stage 4: Builder - Build the application
# =======================================================================
FROM base AS builder
WORKDIR /app
ARG APP_NAME

# Copy the installed node_modules from installer
COPY --from=installer /app/ .
# Copy the actual source code (pruned)
COPY --from=pruner /app/out/full/ .

# Build the specific app
RUN pnpm run build --filter=${APP_NAME}...

# =======================================================================
# Stage 5: Runner for Next.js (web, dashboard)
# =======================================================================
FROM base AS runner-nextjs
WORKDIR /app
ARG APP_NAME

ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.1"

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs
USER nextjs

COPY --from=builder /app/apps/${APP_NAME}/public ./public
# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/apps/${APP_NAME}/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/${APP_NAME}/.next/static ./apps/${APP_NAME}/.next/static

# Start the standalone Next.js server
CMD node apps/${APP_NAME}/server.js

# =======================================================================
# Stage 6: Runner for NestJS (api)
# =======================================================================
FROM base AS runner-nestjs
WORKDIR /app
ARG APP_NAME

ENV NODE_ENV=production

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

# We need the production node_modules and the built dist for the api
COPY --from=builder --chown=nestjs:nodejs /app/apps/${APP_NAME}/package.json ./apps/${APP_NAME}/package.json
COPY --from=builder --chown=nestjs:nodejs /app/apps/${APP_NAME}/dist ./apps/${APP_NAME}/dist
COPY --from=installer --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=installer --chown=nestjs:nodejs /app/apps/${APP_NAME}/node_modules ./apps/${APP_NAME}/node_modules

USER nestjs

# Start the NestJS application
CMD node apps/${APP_NAME}/dist/main
