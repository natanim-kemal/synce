import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SyncService {
    constructor(private prisma: PrismaService) { }

    async getChanges(userId: string, since: Date, limit: number = 100, cursor?: string) {
        const cursorObj = cursor ? { id: cursor } : undefined;
        
        const [newFiles, updatedFiles, deletedFiles] = await Promise.all([
            this.prisma.file.findMany({
                where: {
                    userId,
                    uploadedAt: { gt: since },
                    deletedAt: null,
                },
                take: limit,
                cursor: cursorObj,
                skip: cursor ? 1 : 0,
                orderBy: { uploadedAt: 'asc' },
            }),

            this.prisma.file.findMany({
                where: {
                    userId,
                    lastModified: { gt: since },
                    uploadedAt: { lte: since },
                    deletedAt: null,
                },
                take: limit,
                orderBy: { lastModified: 'asc' },
            }),

            this.prisma.file.findMany({
                where: {
                    userId,
                    deletedAt: { gt: since },
                },
                select: { id: true, originalName: true, deletedAt: true },
                take: limit,
                orderBy: { deletedAt: 'asc' },
            }),
        ]);

        const lastFile = newFiles.length > 0 ? newFiles[newFiles.length - 1] : null;

        return {
            serverTimestamp: new Date(),
            nextCursor: lastFile?.id || null,
            changes: {
                new: newFiles,
                updated: updatedFiles,
                deleted: deletedFiles.map(f => ({ id: f.id, name: f.originalName })),
            },
        };
    }
}
