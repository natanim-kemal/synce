import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SyncService {
    constructor(private prisma: PrismaService) { }

    async getChanges(userId: string, since: Date) {
        const [newFiles, updatedFiles, deletedFiles] = await Promise.all([
            // New files (uploaded after timestamp)
            this.prisma.file.findMany({
                where: {
                    userId,
                    uploadedAt: { gt: since },
                    deletedAt: null,
                },
            }),

            // Updated files (modified after timestamp, but created before)
            this.prisma.file.findMany({
                where: {
                    userId,
                    lastModified: { gt: since },
                    uploadedAt: { lte: since },
                    deletedAt: null,
                },
            }),

            // Deleted files
            this.prisma.file.findMany({
                where: {
                    userId,
                    deletedAt: { gt: since },
                },
                select: { id: true, originalName: true, deletedAt: true },
            }),
        ]);

        return {
            serverTimestamp: new Date(),
            changes: {
                new: newFiles,
                updated: updatedFiles,
                deleted: deletedFiles.map(f => ({ id: f.id, name: f.originalName })),
            },
        };
    }
}
