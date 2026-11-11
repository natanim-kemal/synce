#!/bin/bash
# Bootstrap the synce stack on the EC2. Run from /opt/synce as:
#   sudo RDS_ENDPOINT=<rds-host> BUCKET=<bucket> EMAIL=<letsencrypt-email> bash setup.sh
set -euo pipefail

: "${RDS_ENDPOINT:?RDS_ENDPOINT required}"
: "${BUCKET:?BUCKET required}"
: "${EMAIL:?EMAIL required}"
REGION=eu-north-1

# 1. Secrets from SSM via the instance role -> server.env (0600, never in git)
JWT=$(aws ssm get-parameter --name /synce/prod/jwt-secret --with-decryption --query Parameter.Value --output text --region "$REGION")
DBPASS=$(aws ssm get-parameter --name /synce/prod/db-password --with-decryption --query Parameter.Value --output text --region "$REGION")
{
  echo "JWT_SECRET=$JWT"
  echo "DATABASE_URL=postgresql://synce:$DBPASS@$RDS_ENDPOINT:5432/synce"
  echo "S3_REGION=$REGION"
  echo "S3_BUCKET_NAME=$BUCKET"
} > server.env
unset JWT DBPASS
chmod 600 server.env

# 2. HTTP-only nginx first (so certbot's webroot challenge is served)
cp nginx/templates/http.conf nginx/conf.d/synce.conf
docker compose up -d --build server nginx
sleep 5

# 3. Schema
docker compose run --rm server npx prisma migrate deploy

# 4. Certificate, then enable HTTPS vhost
docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d synce.natanim.dev \
  --email "$EMAIL" --agree-tos --no-eff-email --non-interactive
cp nginx/templates/https.conf nginx/conf.d/synce.conf
docker compose exec nginx nginx -s reload

# 5. Renewal reload cron (twice daily, after the 12h certbot loop)
echo '0 3,15 * * * docker compose -f /opt/synce/docker-compose.yml exec -T nginx nginx -s reload' | tee /etc/cron.d/synce-nginx-reload

echo "setup complete"
