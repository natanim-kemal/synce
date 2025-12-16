import {
  Controller,
  Get,
  Post,
  Param,
  Delete,
  Body,
  UseInterceptors,
  UploadedFile,
  UseGuards,
  Request,
} from '@nestjs/common';
import { FilesService } from './files.service';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard } from '@nestjs/passport';

@Controller('files')
@UseGuards(AuthGuard('jwt'))
export class FilesController {
  constructor(private readonly filesService: FilesService) { }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  uploadFile(
    @UploadedFile() file: Express.Multer.File,
    @Body('deviceId') deviceId: string,
    @Request() req
  ) {
    return this.filesService.uploadFile(req.user.userId, file, deviceId || 'unknown');
  }

  @Get()
  findAll(@Request() req) {
    return this.filesService.getUserFiles(req.user.userId);
  }

  @Get('download/:id')
  download(@Param('id') id: string, @Request() req) {
    return this.filesService.getDownloadUrl(req.user.userId, id);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req) {
    return this.filesService.deleteFile(req.user.userId, id);
  }
}
