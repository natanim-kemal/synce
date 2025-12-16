import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';
import { StorageService } from './storage/storage.service';
import { createHash } from 'crypto';

@Injectable()
export class FilesService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
  ) { }

  async uploadFile(
    userId: string,
    file: Express.Multer.File,
    deviceId?: string,
  ) {
    // 0. Validate file exists
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    // 1. Validate file type and size
    if (file.mimetype !== 'application/pdf') {
      throw new BadRequestException('Only PDF files are supported');
    }
    if (file.size > 50 * 1024 * 1024) { // 50 MB
      throw new BadRequestException('File size exceeds 50 MB limit');
    }

    // 2. Calculate SHA-256 hash
    const hash = createHash('sha256').update(file.buffer).digest('hex');
    const storedName = `${hash}.pdf`;

    // 3. Check if file with same name already exists (name-based replacement)
    const existingFile = await this.prisma.file.findFirst({
      where: { userId, originalName: file.originalname, deletedAt: null },
    });

    if (existingFile) {
      // File with same name exists - delete old S3 file and soft-delete DB record
      await this.storage.deleteFile(existingFile.storedName);
      await this.prisma.file.update({
        where: { id: existingFile.id },
        data: { deletedAt: new Date() },
      });
    }

    // 4. Upload to S3
    const s3Exists = await this.storage.fileExists(storedName);
    if (!s3Exists) {
      await this.storage.uploadFile(storedName, file.buffer, 'application/pdf');
    }

    // 5. Save metadata to database
    return this.prisma.file.create({
      data: {
        userId,
        originalName: file.originalname,
        storedName,
        size: file.size,
        hash,
        deviceId,
      },
    });
  }

  async getDownloadUrl(userId: string, fileId: string) {
    const file = await this.prisma.file.findFirst({
      where: { id: fileId, userId, deletedAt: null },
    });

    if (!file) {
      throw new BadRequestException('File not found');
    }

    // Generate presigned URL (valid for 1 hour)
    return this.storage.getPresignedUrl(file.storedName, 3600);
  }

  async getUserFiles(userId: string) {
    return this.prisma.file.findMany({
      where: { userId, deletedAt: null },
      orderBy: { uploadedAt: 'desc' },
      select: {
        id: true,
        originalName: true,
        size: true,
        hash: true,
        uploadedAt: true,
        lastModified: true,
        version: true,
      },
    });
  }

  async deleteFile(userId: string, fileId: string) {
    // Soft delete
    return this.prisma.file.update({
      where: { id: fileId, userId },
      data: { deletedAt: new Date() },
    });
  }
}
