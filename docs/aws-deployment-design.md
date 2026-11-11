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
| DNS | **Route 53 sub-zone** `synce.natanim.dev`, delegated | User adds 2 NS records at their current DNS provider once; everything after is CDK-managed. |
| IaC | **CDK (TypeScript)**, one stack | Per original agreement. |
| HTTPS | **Let's Encrypt** via certbot container on Nginx | ACM certs can't terminate on EC2; an ALB (~$16/mo) is rejected on cost. |
| Secrets | **SSM Parameter Store** (`SecureString`) | Kills the `.env`-in-git and `JWT_SECRET || 'secret'` fallback risks. |

## Architecture

```
Android / Windows client
        │ HTTPS
        ▼
synce.natanim.dev ── Route 53 sub-zone (NS delegated from natanim.dev)
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

VPC (1 AZ, 1 public subnet + 1 private subnet) · EC2 t4g.micro + EBS 12 GB gp3 + instance role (S3, SSM read) · RDS db.t4g.micro 20 GB in private subnet · S3 bucket (private, versioning off — dedup already handles identity) · Route 53 hosted zone `synce.natanim.dev` · ACM is **not** used (certbot instead) · SSM parameters (created out-of-band or via CDK) · Security groups: EC2 ← 80/443 world, EC2 ← 22 from user IP only, RDS ← 5432 from EC2 SG only.

## Cost estimate (eu-north-1, monthly, list price)

| Item | ~$/mo |
|---|---|
| EC2 t4g.micro | 7 |
| EBS 12 GB gp3 | 1 |
| RDS db.t4g.micro + 20 GB | 14 |
| Route 53 zone | 0.50 |
| S3 + data transfer | ~1 |
| **Total** | **~23** |

Covered by: $100 account credits (expire 2027-05) + $20 DB activity credit + $20 budget-creation credit → roughly 5 months fully credited. If the FREE plan includes the 12-month RDS instance allowance, DB cost drops to $0 — confirm at deploy time with `aws freetier get-account-plan-state`.

## Security hardening (in scope, small)

1. `JWT_SECRET` required from SSM — remove `|| 'secret'` fallback (jwt.strategy.ts, auth.module.ts).
2. CORS: restrict `origin` in main.ts (native apps don't need CORS at all, but stop allowing `*`).
3. Rate-limit `/auth/register` + `/auth/login` (ThrottlerModule, ~5 req/min).
4. No secrets in `.env` on the server — env vars injected by compose from SSM at boot.

## Client changes (in scope)

1. `client/lib/data/api_client.dart`: base URL from `--dart-define` (`SYNCE_API_URL`), default keeps local dev working.
2. Build Android release APK and Windows app with `SYNCE_API_URL=https://synce.natanim.dev`.
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
