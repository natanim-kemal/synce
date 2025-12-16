import { Module } from '@nestjs/common';
import { FilesService } from './files.service';
import { FilesController } from './files.controller';
import { StorageModule } from './storage/storage.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [StorageModule, PrismaModule],
  controllers: [FilesController],
  providers: [FilesService],
})
export class FilesModule { }
