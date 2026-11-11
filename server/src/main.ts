import { NestFactory } from '@nestjs/core';
import * as Sentry from '@sentry/nestjs';
import { AppModule } from './app.module';

async function bootstrap() {
  const sentryEnabled = Boolean(process.env.SENTRY_DSN);
  if (sentryEnabled) {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.NODE_ENV || 'production',
      integrations: [Sentry.nestIntegration()],
      tracesSampleRate: 0,
    });
  }

  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: 'https://synce.natanim.dev',
    credentials: true,
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Server running on http://0.0.0.0:${port}`);
}
bootstrap();
