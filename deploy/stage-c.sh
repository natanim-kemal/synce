#!/bin/bash
set -euo pipefail
cd /opt/synce

cp nginx/templates/http.conf nginx/conf.d/synce.conf
sudo docker compose exec -T nginx nginx -s reload

sudo docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d api.synce.natanim.dev \
  --email kemalnatanim@gmail.com --agree-tos --no-eff-email --non-interactive

cp nginx/templates/https.conf nginx/conf.d/synce.conf
sudo docker compose exec -T nginx nginx -s reload

sudo docker compose up -d certbot

echo '0 3,15 * * * docker compose -f /opt/synce/docker-compose.yml exec -T nginx nginx -s reload' | sudo tee /etc/cron.d/synce-nginx-reload

echo "STAGE-C-OK"
