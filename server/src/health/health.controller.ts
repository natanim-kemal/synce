import { Controller, Get, HttpException, HttpStatus } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

type CheckStatus = 'up' | 'down';

@Controller('health')
export class HealthController {
    constructor(
        private prisma: PrismaService,
        private storage: StorageService,
    ) { }

    @Get()
    async check() {
        const checks = {
            database: await this.checkDatabase(),
            storage: await this.checkStorage(),
        };
        const healthy = Object.values(checks).every((status) => status === 'up');
        if (!healthy) {
            throw new HttpException(
                { status: 'degraded', checks, timestamp: new Date().toISOString() },
                HttpStatus.SERVICE_UNAVAILABLE,
            );
        }
        return { status: 'ok', checks, timestamp: new Date().toISOString() };
    }

    private async checkDatabase(): Promise<CheckStatus> {
        try {
            await this.prisma.$queryRaw`SELECT 1`;
            return 'up';
        } catch {
            return 'down';
        }
    }

    private async checkStorage(): Promise<CheckStatus> {
        try {
            await this.storage.checkHealth();
            return 'up';
        } catch {
            return 'down';
        }
    }
}
