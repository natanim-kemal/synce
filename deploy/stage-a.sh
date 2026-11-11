#!/bin/bash
set -euo pipefail
cd /opt/synce

REGION=eu-north-1
RDS_ENDPOINT=syncestack-db5d02a0a9-ymtgfbqi9d7e.cfiykkmik035.eu-north-1.rds.amazonaws.com
BUCKET=synce-pdf-books-179530538522

JWT=$(aws ssm get-parameter --name /synce/prod/jwt-secret --with-decryption --query Parameter.Value --output text --region "$REGION")
DBP=$(aws ssm get-parameter --name /synce/prod/db-password --with-decryption --query Parameter.Value --output text --region "$REGION")
printf 'JWT_SECRET=%s\nDATABASE_URL=postgresql://synce:%s@%s:5432/synce\nS3_REGION=%s\nS3_BUCKET_NAME=%s\n' \
  "$JWT" "$DBP" "$RDS_ENDPOINT" "$REGION" "$BUCKET" > server.env
unset JWT DBP
chmod 600 server.env

cp nginx/templates/http.conf nginx/conf.d/synce.conf
sudo docker compose up -d --build server nginx
sleep 5
sudo docker compose run --rm server npx prisma migrate deploy
echo "STAGE-A-OK"
