import * as Sentry from '@sentry/nestjs';

Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENVIRONMENT ?? 'production',
    release: process.env.SENTRY_RELEASE,
    tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? 0.1),
    beforeSend(event) {
        const response = event.contexts?.response as { status_code?: number } | undefined;
        const raw = event.exception?.values?.[0]?.value;
        const status = response?.status_code ?? (typeof raw === 'number' ? raw : undefined);
        if (status !== undefined && status < 500) {
            return null;
        }
        return event;
    },
});
