#!/bin/bash
# Publishes the API health metric that the CloudWatch alarm watches.
set -uo pipefail

HEALTH_URL="https://api.synce.natanim.dev/health"
VALUE=0
if curl -fsS --max-time 10 --resolve api.synce.natanim.dev:443:127.0.0.1 "$HEALTH_URL" > /dev/null 2>&1; then
  VALUE=1
fi

aws cloudwatch put-metric-data \
  --namespace "Synce/Api" \
  --metric-name "Health" \
  --value "$VALUE" \
  --unit Count \
  --region eu-north-1
