import { Controller, Get, Query, UseGuards, Request, BadRequestException } from '@nestjs/common';
import { SyncService } from './sync.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('sync')
@UseGuards(AuthGuard('jwt'))
export class SyncController {
    constructor(private readonly syncService: SyncService) { }

    @Get('changes')
    getChanges(
        @Query('since') since: string,
        @Query('cursor') cursor: string,
        @Query('limit') limit: string,
        @Request() req
    ) {
        const parsedLimit = limit ? parseInt(limit, 10) : 100;

        if (!since) {
            return this.syncService.getChanges(req.user.userId, new Date(0), parsedLimit, cursor || undefined);
        }

        const hasOffset = /(?:z|[+-]\d{2}:?\d{2})$/i.test(since.trim());
        const timestamp = new Date(hasOffset ? since.trim() : `${since.trim()}Z`);
        if (isNaN(timestamp.getTime())) {
            throw new BadRequestException('Invalid timestamp');
        }

        const effective = timestamp.getTime() > Date.now() ? new Date() : timestamp;

        return this.syncService.getChanges(req.user.userId, effective, parsedLimit, cursor || undefined);
    }
}
