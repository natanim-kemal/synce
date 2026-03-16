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
    email?: string,
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
    const folder = email || userId;
    const storedName = `${folder}/${hash}.pdf`;

    // 3. Check if file with same content (hash) already exists
    // First check by hash - if same content exists, reuse it
    const existingByHash = await this.prisma.file.findFirst({
      where: { userId, hash: hash, deletedAt: null },
    });

    if (existingByHash) {
      // Same content already exists - check if it's the same file or a different name
      const existingByName = await this.prisma.file.findFirst({
        where: { userId, originalName: file.originalname, deletedAt: null },
      });

      if (existingByName && existingByName.id === existingByHash.id) {
        // Same file with same name - just update metadata
        return this.prisma.file.update({
          where: { id: existingByHash.id },
          data: {
            size: file.size,
            deviceId: deviceId,
            lastModified: new Date(),
          },
        });
      }

      // Different name but same content - create new record pointing to same stored file
      return this.prisma.file.create({
        data: {
          userId,
          originalName: file.originalname,
          storedName: existingByHash.storedName, // Reuse existing stored file
          size: file.size,
          hash,
          deviceId,
          version: 1,
        },
      });
    }

    // 4. Check if file with same name exists (new content)
    const existingFile = await this.prisma.file.findFirst({
      where: { userId, originalName: file.originalname, deletedAt: null },
    });

    if (existingFile) {
      // Different content for same name - it's an update
      // Upload new file to storage
      const s3Exists = await this.storage.fileExists(storedName);
      if (!s3Exists) {
        await this.storage.uploadFile(storedName, file.buffer, 'application/pdf');
      }
      // Cleanup old storage file if it's different
      if (existingFile.storedName !== storedName) {
        await this.storage.deleteFile(existingFile.storedName);
      }

      // Update existing record
      return this.prisma.file.update({
        where: { id: existingFile.id },
        data: {
          size: file.size,
          hash: hash,
          storedName: storedName,
          deviceId: deviceId,
          version: { increment: 1 },
          lastModified: new Date(),
        },
      });
    }

    // 5. Case: New file - Upload to storage
    const s3Exists = await this.storage.fileExists(storedName);
    if (!s3Exists) {
      await this.storage.uploadFile(storedName, file.buffer, 'application/pdf');
    }

    // 6. Save new record to database
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
    return this.prisma.file.updateMany({
      where: { id: fileId, userId },
      data: { deletedAt: new Date() },
    });
  }
}
