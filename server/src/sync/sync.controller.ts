import { Controller, Get, Query, UseGuards, Request, BadRequestException } from '@nestjs/common';
import { SyncService } from './sync.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('sync')
@UseGuards(AuthGuard('jwt'))
export class SyncController {
    constructor(private readonly syncService: SyncService) { }

    @Get('changes')
    getChanges(@Query('since') since: string, @Request() req) {
        if (!since) {
            // If no timestamp, assume sync from beginning of time (epoch)
            // or throw error depending on requirements. Let's start from 0.
            return this.syncService.getChanges(req.user.userId, new Date(0));
        }

        const timestamp = new Date(since);
        if (isNaN(timestamp.getTime())) {
            throw new BadRequestException('Invalid timestamp');
        }

        return this.syncService.getChanges(req.user.userId, timestamp);
    }
}
