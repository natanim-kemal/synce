#!/bin/bash
set -euo pipefail
cd /opt/synce

if ! docker buildx version >/dev/null 2>&1; then
  BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p')
  curl -sSL "https://github.com/docker/buildx/releases/download/$BUILDX_VERSION/buildx-$BUILDX_VERSION.linux-arm64" -o /tmp/docker-buildx
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  sudo mv /tmp/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
fi

REGION=eu-north-1
RDS_ENDPOINT=syncestack-db5d02a0a9-ymtgfbqi9d7e.cfiykkmik035.eu-north-1.rds.amazonaws.com
BUCKET=synce-pdf-books-179530538522

JWT=$(aws ssm get-parameter --name /synce/prod/jwt-secret --with-decryption --query Parameter.Value --output text --region "$REGION")
DBP=$(aws ssm get-parameter --name /synce/prod/db-password --with-decryption --query Parameter.Value --output text --region "$REGION")
SENTRY_DSN=$(aws ssm get-parameter --name /synce/prod/sentry-dsn --with-decryption --query Parameter.Value --output text --region "$REGION" 2>/dev/null || true)
if [ -z "${SENTRY_DSN:-}" ] || [ "$SENTRY_DSN" = "None" ]; then
  SENTRY_DSN=$(grep '^SENTRY_DSN=' server.env 2>/dev/null | cut -d= -f2- || true)
fi
{
  echo "JWT_SECRET=$JWT"
  echo "DATABASE_URL=postgresql://synce:$DBP@$RDS_ENDPOINT:5432/synce"
  echo "S3_REGION=$REGION"
  echo "S3_BUCKET_NAME=$BUCKET"
  if [ -n "${SENTRY_DSN:-}" ] && [ "$SENTRY_DSN" != "None" ]; then
    echo "SENTRY_DSN=$SENTRY_DSN"
    echo "SENTRY_ENVIRONMENT=production"
    echo "SENTRY_RELEASE=${SENTRY_RELEASE:-unknown}"
    echo "SENTRY_TRACES_SAMPLE_RATE=0.1"
  fi
} > server.env
unset JWT DBP SENTRY_DSN
chmod 600 server.env

cp nginx/templates/http.conf nginx/conf.d/synce.conf
sudo docker compose up -d --build server nginx
sleep 5
sudo docker compose run --rm server npx prisma migrate deploy
echo "STAGE-A-OK"
