import { Controller, Get, Inject } from '@nestjs/common';
import { HealthCheckService, HealthCheck, TypeOrmHealthIndicator } from '@nestjs/terminus';
import Redis from 'ioredis';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    @Inject('REDIS_CLIENT') private redisClient: Redis.Redis,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      async () => {
        try {
          await this.redisClient.ping();
          return { redis: { status: 'up' as const } };
        } catch (e) {
          return { redis: { status: 'down' as const, message: (e as Error).message } };
        }
      }
    ]);
  }
}
