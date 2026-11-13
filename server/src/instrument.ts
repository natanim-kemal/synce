import * as Sentry from '@sentry/nestjs';

Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENVIRONMENT ?? 'production',
    release: process.env.SENTRY_RELEASE,
    tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? 0.1),
    ignoreErrors: [
        { statusCode: [400, 401, 403, 404, 409, 413, 422, 429] },
    ],
});
