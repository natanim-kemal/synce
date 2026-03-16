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

        const timestamp = new Date(since);
        if (isNaN(timestamp.getTime())) {
            throw new BadRequestException('Invalid timestamp');
        }

        return this.syncService.getChanges(req.user.userId, timestamp, parsedLimit, cursor || undefined);
    }
}
