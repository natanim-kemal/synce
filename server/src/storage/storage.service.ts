import { Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand, HeadObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class StorageService {
    private s3Client: S3Client;
    private bucketName = process.env.S3_BUCKET_NAME || 'pdf-books';

    constructor() {
        this.s3Client = new S3Client({
            // Omit endpoint for real AWS; set S3_ENDPOINT (and S3_FORCE_PATH_STYLE=true) for MinIO.
            ...(process.env.S3_ENDPOINT ? { endpoint: process.env.S3_ENDPOINT } : {}),
            region: process.env.S3_REGION || 'eu-north-1',
            // Static keys only for MinIO/local; real AWS uses the instance IAM role (default chain).
            ...(process.env.S3_ACCESS_KEY
                ? { credentials: { accessKeyId: process.env.S3_ACCESS_KEY, secretAccessKey: process.env.S3_SECRET_KEY || '' } }
                : {}),
            forcePathStyle: process.env.S3_FORCE_PATH_STYLE === 'true',
        });
    }

    async uploadFile(key: string, body: Buffer, contentType: string) {
        await this.s3Client.send(
            new PutObjectCommand({
                Bucket: this.bucketName,
                Key: key,
                Body: body,
                ContentType: contentType,
            }),
        );
    }

    async fileExists(key: string): Promise<boolean> {
        try {
            await this.s3Client.send(
                new HeadObjectCommand({
                    Bucket: this.bucketName,
                    Key: key,
                }),
            );
            return true;
        } catch {
            return false;
        }
    }

    async getPresignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
        const command = new GetObjectCommand({
            Bucket: this.bucketName,
            Key: key,
        });
        return getSignedUrl(this.s3Client, command, { expiresIn });
    }

    async deleteFile(key: string): Promise<void> {
        await this.s3Client.send(
            new DeleteObjectCommand({
                Bucket: this.bucketName,
                Key: key,
            }),
        );
    }
}
