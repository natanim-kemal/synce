import { Test, TestingModule } from '@nestjs/testing';
import { HttpException } from '@nestjs/common';
import { HealthController } from './health.controller';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

describe('HealthController', () => {
  let controller: HealthController;

  const build = async (database: 'up' | 'down', storage: 'up' | 'down') => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        { provide: PrismaService, useValue: { $queryRaw: database === 'up' ? jest.fn().mockResolvedValue([{ '?column?': 1 }]) : jest.fn().mockRejectedValue(new Error('db down')) } },
        { provide: StorageService, useValue: { checkHealth: storage === 'up' ? jest.fn().mockResolvedValue(undefined) : jest.fn().mockRejectedValue(new Error('s3 down')) } },
      ],
    }).compile();
    return module.get<HealthController>(HealthController);
  };

  beforeEach(async () => {
    controller = await build('up', 'up');
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('reports ok when database and storage are reachable', async () => {
    const result = await controller.check();
    expect(result.status).toBe('ok');
    expect(result.checks).toEqual({ database: 'up', storage: 'up' });
  });

  it('throws 503 when the database is unreachable', async () => {
    controller = await build('down', 'up');
    await expect(controller.check()).rejects.toBeInstanceOf(HttpException);
  });

  it('throws 503 when storage is unreachable', async () => {
    controller = await build('up', 'down');
    await expect(controller.check()).rejects.toBeInstanceOf(HttpException);
  });
});
