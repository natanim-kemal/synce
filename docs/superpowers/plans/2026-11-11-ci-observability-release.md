# Synce CI, Observability & Release Distribution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CI that builds/tests/releases the apps, observability that tells us when the API breaks, and public download links on synce.natanim.dev backed by GitHub Releases.

**Architecture:** GitHub Actions on `natanim-kemal/synce` (public repo → free minutes). `ci.yml` on push/PR; `release.yml` on tag `v*` builds APK (ubuntu) + Windows zip (windows runner) and publishes a GitHub Release. Server observability: `/health` endpoint + Sentry (errors) + CloudWatch agent (logs) + custom `ApiHealth` metric with alarms. `synce-site` (Vercel) download buttons resolve the latest release via the GitHub API.

**Tech Stack:** GitHub Actions, Flutter 3.47.1, Gradle 8.14 / AGP 8.11.1, NestJS + Sentry SDK, CloudWatch agent + SNS email, Next.js 16 (synce-site).

**Spec:** chat approval 2026-11-11 (observability = CloudWatch + Sentry; site links auto-follow latest release).

## Global Constraints

- Region eu-north-1 only; AWS CLI/CDK use `--profile aws-agent-toolkit` (re-run `aws login` if the session token expires).
- Commits: one file per commit, lowercase, short message, no comments added to committed files.
- Secrets never in git: Sentry DSN + AWS keys live in SSM Parameter Store on the EC2; the Android keystore lives in GitHub Actions secrets.
- No paid GitHub Actions runners; public repo minutes are free.
- Keep monthly cost under the $30 budget: observability target < $1/mo.

## Review Focus

- **Release APK must be signed with a real key** → `flutter install` of a release build fails with "app not installed" if the signature changes later; keystore is backed up locally and in GH secrets.
- **`applicationId` change is irreversible for existing installs** → do it before the first public release, not after.
- **Health endpoint must not leak secrets** → `/health` returns status only, never DSN/hostnames/versions.
- **Sentry DSN missing must not break boot** → init guarded by env presence.
- **CloudWatch log group needs a retention set** → unlimited retention bills up; 14 days.
- **Site release fetch can fail/rate-limit** → static fallback URLs must still work.

---

### Task A: Android release identity + signing

**Files:**
- Modify: `client/android/app/build.gradle` (namespace + applicationId → `dev.natanim.synce`, release signingConfig from key.properties, minSdk/targetSdk kept)
- Modify: `client/android/settings.gradle` (nothing beyond AGP bump already done)
- Move: `client/android/app/src/main/kotlin/com/example/client/MainActivity.kt` → `.../kotlin/dev/natanim/synce/MainActivity.kt` (package `dev.natanim.synce`)
- Create (gitignored, local only): `client/android/key.properties`, `client/android/synce-release.jks`
- Modify: `client/android/.gitignore` (ignore `key.properties`, `*.jks`)

- [x] Step 1: Generate keystore: `keytool -genkeypair -v -keystore client/android/synce-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias synce` (store password in SSM + GitHub secret; keep local copy, gitignored)
- [x] Step 2: Edit `build.gradle`: namespace/applicationId `dev.natanim.synce`; release buildType reads `key.properties` (signingConfigs.release), falls back to debug signing when the file is absent (so CI without secrets still builds)
- [x] Step 3: Move MainActivity.kt to the new package dir; verify `flutter build apk --release` succeeds
- [x] Step 4: Commit `client/android/app/build.gradle`, the moved MainActivity, `client/android/.gitignore` (one file per commit)

### Task B: GitHub Actions

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

- [x] Step 1: `ci.yml` — jobs: `server` (node 22, `npm ci` in server/, `npx prisma generate`, `npm run build`, `npm test`), `client` (subosito/flutter-action, flutter 3.47.1, `flutter pub get`, `flutter analyze`, `flutter test`); trigger: push + PR on main
- [x] Step 2: `release.yml` — trigger: tags `v*`; job `android` (ubuntu-latest, flutter-action, `flutter build apk --release --build-name=$TAG --build-number=$BUILD --dart-define=SYNCE_API_URL=... --dart-define=...` with keystore secrets) → upload artifact; job `windows` (windows-latest, `flutter build windows --release` → zip) → upload artifact; job `release` (needs both, `gh release create "$TAG" --generate-notes` with assets + SHA256 sums)
- [x] Step 3: Add release secrets: `SYNCE_KEYSTORE_BASE64`, `SYNCE_KEYSTORE_PASSWORD`, `SYNCE_KEY_ALIAS`, `SYNCE_KEY_PASSWORD`
- [x] Step 4: Push a test tag `v0.1.0-rc.1`, verify both jobs pass and the release assets exist

### Task C: Server observability

**Files:**
- Create: `server/src/health/health.controller.ts` + `health.module.ts` (public `GET /health` → DB `$queryRaw SELECT 1` + S3 HeadBucket, returns `{status, checks}`)
- Modify: `server/src/app.module.ts` (import HealthModule)
- Modify: `server/src/main.ts` (Sentry init guarded by `SENTRY_DSN`)
- Modify: `server/package.json` (`@sentry/node`)
- Modify: `infra/lib/synce-stack.ts` (CloudWatch log group + metric alarms + SNS topic + alarm actions)
- Create: `deploy/cloudwatch-agent.json`, `deploy/health-check.sh` (cron → `put-metric-data`)

- [x] Step 1: `/health` endpoint + unit test; verify locally against the deployed API
- [x] Step 2: Sentry: `npm i @sentry/node`; init in main.ts (`Sentry.init({dsn: process.env.SENTRY_DSN})`) + `Sentry.captureException` in the global exception filter; add `SENTRY_DSN` to the EC2 `server.env` (value from SSM `/synce/prod/sentry-dsn`)
- [x] Step 3: CloudWatch agent on the EC2 (rpm install) shipping `/var/lib/docker/containers/*/*.log` → log group `/synce/app` (14-day retention)
- [x] Step 4: `health-check.sh` on the EC2 via cron every 5 min → `aws cloudwatch put-metric-data` namespace `Synce/Api` metric `Health` (0/1)
- [x] Step 5: CDK: SNS topic + email subscription, alarm `ApiHealth == 0` (2 consecutive periods), alarm on log metric filter `ERROR` count; log group + retention in stack
- [x] Step 6: Deploy the stack, verify alarms exist and a deliberate failure trips them, then undo

### Task D: Site release links

**Files (in `natanim-kemal/synce-site`, separate repo):**
- Modify: the download-section component — fetch `https://api.github.com/repos/natanim-kemal/synce/releases/latest`, pick `synce-android-*.apk` / `synce-windows-*.zip`, fallback to static URLs

- [x] Step 1: Clone `synce-site` locally
- [x] Step 2: Implement the fetch + fallback in the download section; keep the existing styling
- [x] Step 3: Push → Vercel auto-deploys → verify the buttons resolve real asset URLs on synce.natanim.dev
- [x] Step 4: Fix the site's "End-to-end encryption" claim (the app does TLS in transit + S3 encryption, not E2E)

### Task E: First public release

- [ ] Step 1: Tag `v0.1.0` → CI publishes release with APK + Windows zip
- [ ] Step 2: Verify the site download buttons point at the new assets
- [x] Step 3: Sideload the APK on a device, run the app against `https://api.synce.natanim.dev`
