# Synce — AWS Deployment Design

Status: **draft for approval** · Region: **eu-north-1** (only allowed region) · Fresh start, no data migration.

## Goal

Personal/family PDF sync at `https://synce.natanim.dev`, minimal cost, deployed with infrastructure-as-code, clients = Android APK (sideload) + Windows.

## Decisions (locked with user)

| Decision | Choice | Why |
|---|---|---|
| Database | **RDS PostgreSQL** `db.t4g.micro`, single-AZ | Earns the $20 "Create an Aurora or RDS database" activity credit (~6 weeks of DB cost covered); managed backups/patching. EC2 learning is unaffected — the app, Docker, Nginx, TLS, SSH all still run on EC2. |
| App hosting | **EC2** `t4g.micro` (ARM, Amazon Linux 2023), Docker Compose (NestJS + Nginx/certbot) | Cheapest full-control box; user wants to learn EC2. |
| File storage | **S3** (private bucket, instance IAM role) | Already tested end-to-end against real S3 with the new storage-service config. |
| DNS | **Cloudflare A record** `api.synce.natanim.dev` → EC2 IP (DNS only) | `synce.natanim.dev` already hosts a marketing website — delegating that sub-zone to Route 53 would shadow it. App gets its own name; Route 53 zone removed from the stack. |
| IaC | **CDK (TypeScript)**, one stack | Per original agreement. |
| HTTPS | **Let's Encrypt** via certbot container on Nginx | ACM certs can't terminate on EC2; an ALB (~$16/mo) is rejected on cost. |
| Secrets | **SSM Parameter Store** (`SecureString`) | Kills the `.env`-in-git and `JWT_SECRET || 'secret'` fallback risks. |

## Architecture

```
Android / Windows client
        │ HTTPS
        ▼
api.synce.natanim.dev ── Cloudflare A record (DNS only) → EC2 EIP
        │
        ▼
EC2 t4g.micro  [ Docker Compose: Nginx+certbot ── NestJS ]
        │                    │
        │ IAM role           │ prisma
        ▼                    ▼
   S3 (PDFs, private,   RDS PostgreSQL db.t4g.micro
   presigned URLs)      (private, SG: EC2 only)
        ▲
        └── SSM Parameter Store: JWT_SECRET, DB creds
```

- Upload path stays as today (client → NestJS → S3 streaming). A presigned-PUT optimization is noted as a future item, not in scope now.
- Backups: RDS automated backups, **1-day retention** (the FREE plan caps retention below the standard 7 days — discovered at first deploy). Replaces the pg_dump cron that the Docker-Postgres plan needed.

## CDK stack contents

VPC (2 AZs, 1 public subnet + 2 private-isolated subnets — RDS requires a 2-AZ subnet group) · EC2 t4g.micro + EBS 12 GB gp3 + EIP + instance role (S3, SSM read, SSM Session Manager) · RDS db.t4g.micro 20 GB encrypted in private subnets · S3 bucket (private, SSL-enforced, RETAIN on delete) · no Route 53 (DNS lives in Cloudflare) · ACM is **not** used (certbot instead) · SSM parameters `/synce/prod/jwt-secret` + `/synce/prod/db-password` · Security groups: EC2 ← 80/443 world + 22 from operator IP only, RDS ← 5432 from EC2 SG only.

## Cost estimate (eu-north-1, monthly, list price)

| Item | ~$/mo |
|---|---|
| EC2 t4g.micro | 7 |
| EBS 12 GB gp3 | 1 |
| RDS db.t4g.micro + 20 GB | 14 |
| S3 + data transfer | ~1 |
| **Total** | **~23** |

Covered by: $100 account credits (expire 2027-05) + $20 DB activity credit + $20 budget-creation credit → roughly 5 months fully credited. If the FREE plan includes the 12-month RDS instance allowance, DB cost drops to $0 — confirm at deploy time with `aws freetier get-account-plan-state`.

## Security hardening (in scope, small)

1. `JWT_SECRET` required from SSM — remove `|| 'secret'` fallback (jwt.strategy.ts, auth.module.ts).
2. CORS: restrict `origin` in main.ts (native apps don't need CORS at all, but stop allowing `*`).
3. Rate-limit `/auth/register` + `/auth/login` (ThrottlerModule, ~5 req/min).
4. No secrets in `.env` on the server — env vars injected by compose from SSM at boot.

## Observability

| Signal | Mechanism | Alarm |
|---|---|---|
| Liveness | `GET /health` → DB (`SELECT 1`) + S3 (`HeadBucket`), 200 ok / 503 degraded | — |
| Uptime | `Synce/Api` `Health` metric (1/0) published every 5 min by cron on the EC2 | `synce-api-down` (2 consecutive periods) → SNS email |
| App logs | Docker `awslogs` driver → CloudWatch Logs `/synce/app`, 14-day retention | — |
| Errors | Metric filter on `ERROR` in `/synce/app` → `Synce/App` `Errors` | `synce-app-errors` → SNS email |
| Host | CloudWatch agent → `Synce/Host` cpu + memory | — |
| Exceptions | Sentry (`@sentry/nestjs`), enabled only when `SENTRY_DSN` is set | Sentry's own alerts |

SNS topic `synce-alerts` notifies `kemalnatanim@gmail.com`. Total cost under $1/month.

## Client changes (in scope)

1. `client/lib/data/api_client.dart`: base URL from `--dart-define` (`SYNCE_API_URL`), default keeps local dev working.
2. Build Android release APK and Windows app with `SYNCE_API_URL=https://api.synce.natanim.dev`.
3. Android already blocks cleartext HTTP — HTTPS domain satisfies it with zero extra config.

## Build & deploy steps (after approval)

1. `infra/` CDK app: `cdk deploy` → outputs: EC2 IP, RDS endpoint, bucket name, zone ID.
2. User adds the 2 NS records at their current DNS provider (I give exact values).
3. Create SSM secrets (JWT_SECRET, DB password).
4. EC2 bootstrap: Docker + compose file + server image (built on the EC2, it's ARM — no registry needed), `prisma migrate deploy`, certbot issues cert.
5. Create AWS budget (spend alert) — earns the budget activity credit.
6. Smoke test: register/login/upload/list/download/sync against `https://synce.natanim.dev`.
7. Build clients (APK + Windows), deliver for sideload/install.

## Explicitly not doing

ALB/CloudFront, Lambda/Fargate, multi-AZ, autoscaling, CloudWatch dashboards/alerts beyond basics, custom domain for S3, presigned-PUT upload rework, Docker registry (ECR) — image builds directly on the EC2.
