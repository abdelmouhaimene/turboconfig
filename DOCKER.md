# Docker Infrastructure for Turboconfig

This document explains the Docker setup for the Turboconfig monorepo.

## Architecture

- **Web**: Next.js app (Port 3000)
- **Dashboard**: Next.js app (Port 3001)
- **API**: NestJS app (Port 3002)
- **Database**: PostgreSQL 17
- **Cache/Queue**: Redis 7

## Development (Local)

In development, we only containerize the **infrastructure** (PostgreSQL and Redis). The apps themselves run natively on your machine to benefit from hot-reloading (HMR) and native debugging.

### 1. Start Infrastructure
```bash
docker compose -f docker-compose.dev.yml up -d
```
This starts PostgreSQL (port 5432) and Redis (port 6379) in the background.

### 2. Start Apps
```bash
pnpm install
pnpm dev
```

### Useful Commands
```bash
# View infrastructure logs
docker compose -f docker-compose.dev.yml logs -f

# Stop infrastructure
docker compose -f docker-compose.dev.yml down
```

## Production (Containerized)

In production, **all** services (apps + infrastructure) run in Docker containers via a multi-stage Dockerfile that leverages `turbo prune` to optimize image sizes and build caches.

### 1. Start Everything
```bash
docker compose up -d --build
```
This will build the API, Web, and Dashboard images and start them alongside PostgreSQL and Redis.

### Useful Commands
```bash
# View all logs
docker compose logs -f

# View specific app logs
docker compose logs -f api

# Stop everything
docker compose down
```

## Environment Variables

Check the `.env.example` files:
- `./.env.example` - Root Docker compose variables
- `./apps/api/.env.example` - API environment variables

## CI/CD Pipeline

A GitHub Actions pipeline is defined in `.github/workflows/ci.yml`.
It requires the following GitHub Secrets to push images to Docker Hub:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
