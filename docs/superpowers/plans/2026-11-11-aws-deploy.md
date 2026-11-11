# Synce AWS Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Synce (NestJS + Flutter) to AWS: EC2 t4g.micro (Docker: Nginx+certbot+NestJS), RDS PostgreSQL db.t4g.micro, private S3 bucket, Route 53 sub-zone `synce.natanim.dev`, via CDK — plus client builds (Android APK, Windows).

**Architecture:** One CDK stack in eu-north-1 provisions VPC(2 AZ, no NAT), EC2 (public, EIP) + RDS (private-isolated) + S3 + Route53 zone. EC2 runs Docker Compose: Nginx (TLS via Let's Encrypt HTTP-01) proxies to the NestJS container; secrets come from SSM Parameter Store via instance role; PDFs go to S3 via presigned URLs (already E2E-tested against real S3).

**Tech Stack:** AWS CDK v2 (TypeScript, `npx aws-cdk`), Amazon Linux 2023 ARM, Docker Compose, Prisma, @nestjs/throttler, Flutter `--dart-define`.

**Spec:** `docs/aws-deployment-design.md` (signed off 2026-11-11).

## Global Constraints

- Region **eu-north-1 only**; every `aws`/`cdk` command uses `--profile aws-agent-toolkit` (refresh PATH per shell: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`).
- Fresh start — no data migration; nothing imported from local MinIO/Postgres.
- Never touch `modintel-*` Docker containers.
- Secrets never in git: SSM only (`/synce/prod/*`); verify `.gitignore` covers `.env`.
- cdk-diff before every deploy; construct IDs stable (renames replace stateful resources).
- S3 bucket: RETAIN on stack delete (data safety), block public access, no bucket policy needed (IAM role grants).

## Review Focus

- **RDS needs a 2-AZ subnet group even single-AZ** → VPC gets `maxAzs: 2` + 2 PRIVATE_ISOLATED subnets; pinned by successful `cdk deploy` (Task 2).
- **DNS delegation lag breaks certbot HTTP-01** → before certbot, `Resolve-DnsName -Type NS synce.natanim.dev` must return the zone's 4 NS (Task 4 step).
- **t4g is ARM** → server image is built **on** the EC2 (native arm64), never cross-compiled from Windows.
- **EC2 stop/start changes public IP** → EIP + Route53 ARecord targets the EIP (Task 2 constructs).
- **JWT_SECRET switch invalidates old tokens** → acceptable (fresh start); smoke test creates fresh users (Task 6).

---

### Task 1: Server hardening (JWT secret required, CORS, rate-limit)

**Files:**
- Modify: `server/src/auth/jwt.strategy.ts:11`, `server/src/auth/auth.module.ts:18` (remove `|| 'secret'` fallback; fail fast when `JWT_SECRET` unset)
- Modify: `server/src/main.ts` (CORS `origin: '*'` → `https://synce.natanim.dev`)
- Modify: `server/src/app.module.ts` (ThrottlerModule global 30/min), `server/src/auth/auth.controller.ts` (`@Throttle` 5/min)
- Modify: `server/package.json` (add `@nestjs/throttler`)

- [x] Step 1: `npm install @nestjs/throttler` in `server/`
- [x] Step 2: Apply the four edits above (lazy guard: `const secret = process.env.JWT_SECRET; if (!secret) throw new Error('JWT_SECRET is required')` in JwtStrategy; ConfigService variant in auth.module)
- [x] Step 3: Verify: `npx tsc --noEmit` clean; `npm test` passes (specs are smoke-level, no secret assertions); server boots with local `.env` (has JWT_SECRET) — `npm run build` then start/kill check
- [x] Step 4: Commit `server/` changes only (check `.gitignore` excludes `.env` first; add if missing)

### Task 2: CDK stack

**Files:**
- Create: `infra/` (CDK TS app: package.json, cdk.json, tsconfig, bin/synce.ts, lib/synce-stack.ts, .gitignore for node_modules/cdk.out)

**Interfaces:**
- Produces: stack outputs `Ec2PublicIp`, `RdsEndpoint`, `BucketName`, `NameServers` (list of 4 NS strings), `InstanceId`, `ZoneId`; SSM parameter names `/synce/prod/jwt-secret`, `/synce/prod/db-password` (consumed by Tasks 3–4)

- [x] Step 1: Scaffold `infra/` manually (no `cdk init` — smaller): package.json with `aws-cdk-lib@^2`, `constructs`, `tsx`; `cdk.json` app `npx tsx bin/synce.ts`; stack `env: { account: 179530538522, region: eu-north-1 }`
- [x] Step 2: Query available engines: `aws rds describe-db-engine-versions --engine postgres --profile aws-agent-toolkit --query "max(DBEngineVersions[].EngineVersion)"` → pin latest 16.x
- [x] Step 3: Author stack: VPC(`maxAzs: 2`, `natGateways: 0`, PUBLIC×1 + PRIVATE_ISOLATED×2); SGs (EC2: 80/443 world + 22 user-IP; RDS: 5432 from EC2 SG); EC2 `t4g.micro` AL2023-ARM AMI (SSM parameter lookup `al2023-ami-kernel-default-arm64`), keypair `ec2.KeyPair`, EIP + association, instance role (S3 full on bucket, `ssm:GetParameter*` on `/synce/prod/*`); RDS `db.t4g.micro`, 20 GB gp3, `PUBLICLY_ACCESSIBLE=false`, credentials from generated password; S3 bucket (S3-managed encryption, RETAIN); `route53.PublicHostedZone('synce.natanim.dev')`; `ARecord` targeting EIP; outputs above
- [x] Step 4: `cdk bootstrap aws://179530538522/eu-north-1 --profile aws-agent-toolkit` (skip if CDKToolkit stack exists)
- [x] Step 5: Verify: `npx aws-cdk synth --strict` clean → `npx aws-cdk diff` shows only expected changes
- [x] Step 6: `npx aws-cdk deploy --profile aws-agent-toolkit --require-approval never` → note outputs
- [x] Step 7: Commit `infra/`

### Task 3: SSM secrets + DNS delegation (user handoff)

- [x] Step 1: Generate strong secret + password locally (PowerRNG), store: `aws ssm put-parameter --name /synce/prod/jwt-secret --type SecureString --value ...` (same for db-password) — values never echoed to console
- [x] Step 2: Print the 4 NS records and give the user exact instructions to add them at their `natanim.dev` DNS provider; **user action, non-blocking** — proceed to Task 4 steps that don't need DNS

### Task 4: EC2 bootstrap + TLS

- [x] Step 1: Wait for instance `ok`/`2/2 checks`; keypair `.pem` saved to `infra/synce-key.pem` (chmod 400 equivalent via icacls)
- [x] Step 2: SSH user-data check: docker installed via `user-data` (docker + compose plugin), else install now
- [x] Step 3: `scp` to EC2: `deploy/` bundle (docker-compose.yml, nginx/synce.conf, server source tarball excluding node_modules/dist/test) — bundle built from repo, not new code
- [x] Step 4: On EC2: fetch SSM params into `deploy/server.env` (instance role, no keys on disk); build server image (`node:22-alpine`); `docker compose up -d nginx` (HTTP only); `docker compose run --rm server npx prisma migrate deploy`; `docker compose up -d server`
- [x] Step 5: Verify DNS live: `Resolve-DnsName synce.natanim.dev` → EIP; NS check from Review Focus
- [x] Step 6: certbot HTTP-01: `docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d synce.natanim.dev --email natanim@... --agree-tos --no-eff-email`; enable 443 server block; `docker compose exec nginx nginx -s reload`; certbot renew loop in compose
- [x] Step 7: Verify: `https://synce.natanim.dev/` returns 200 from the internet path

### Task 5: Budget (activity credit)

- [x] Step 1: `aws budgets create-budget --account-id 179530538522 --budget '{BudgetName:"synce-total",BudgetType:"COST",BudgetLimit:{Amount:"30",Unit:"USD"},TimeUnit:"MONTHLY"}' --profile aws-agent-toolkit` (fallback: console instructions to user)
- [x] Step 2: Note in session log that the 2 activity credits (RDS, budget) should appear in the credits dashboard

### Task 6: Production smoke test

- [x] Step 1: Re-run the 11-check E2E (register/login/non-PDF 400/upload/list/presigned/download/sync/delete/sync-deletion/401) against `https://synce.natanim.dev` — reuse Task 6 script pattern from E2E session (temp PDF, curl, cleanup after)
- [x] Step 2: Scrub smoke-test user from prod DB (psql via `docker compose exec server npx prisma db execute` or psql container); delete smoke-test object from S3

### Task 7: Client builds

**Files:**
- Modify: `client/lib/data/api_client.dart` (baseUrl → `const String.fromEnvironment('SYNCE_API_URL', defaultValue: current value)`)

- [ ] Step 1: Apply dart-define change; `flutter analyze` clean
- [ ] Step 2: `flutter build apk --release --dart-define=SYNCE_API_URL=https://synce.natanim.dev` → report APK path
- [ ] Step 3: `flutter build windows --release --dart-define=SYNCE_API_URL=https://synce.natanim.dev` → report exe path
- [ ] Step 4: Commit client change

**Handoff to user:** sideload APK on Android, install/zip Windows build, confirm NS records added.
