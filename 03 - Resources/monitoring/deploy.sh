#!/usr/bin/env bash
# Deploy monitoring stack additions to hermes-pi.
#
# Usage:  ./deploy.sh [pi-host]
# Default host: hermes-pi
#
# This script:
#   1. scp's monitoring/ directory + updated docker-compose to the Pi
#   2. Brings up cadvisor + blackbox-exporter
#   3. Reloads Prometheus (picks up new scrape jobs + alert rules)
#   4. Restarts Grafana (provisioning kicks in)
#   5. Verifies all targets are UP

set -euo pipefail

PI_HOST="${1:-hermes-pi}"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # 03 - Resources/

echo "==> Deploying to $PI_HOST"

echo "==> Copying monitoring/ + docker-compose-services.yml"
rsync -avz --delete \
  "$LOCAL_DIR/monitoring/" \
  "$PI_HOST:~/monitoring/"

scp "$LOCAL_DIR/docker-compose-services.yml" "$PI_HOST:~/docker-compose-services.yml"

echo "==> Verifying .env on Pi"
ssh "$PI_HOST" 'test -f ~/docker-compose-services.env || { echo "MISSING ~/docker-compose-services.env — see SECURITY-CHECKLIST.md"; exit 1; }'

echo "==> Pulling new images"
ssh "$PI_HOST" 'cd ~ && docker compose --env-file docker-compose-services.env -f docker-compose-services.yml pull cadvisor blackbox-exporter'

echo "==> Bringing up new services"
ssh "$PI_HOST" 'cd ~ && docker compose --env-file docker-compose-services.env -f docker-compose-services.yml up -d cadvisor blackbox-exporter'

echo "==> Reloading Prometheus config"
ssh "$PI_HOST" 'curl -fsS -X POST http://127.0.0.1:9090/-/reload || docker restart prometheus'

echo "==> Restarting Grafana to pick up provisioning"
ssh "$PI_HOST" 'docker restart grafana'

echo "==> Waiting 15s for services to come up"
sleep 15

echo "==> Verifying targets"
ssh "$PI_HOST" 'curl -fsS http://127.0.0.1:9090/api/v1/targets?state=active | python3 -c "
import json, sys
d = json.load(sys.stdin)
for t in d[\"data\"][\"activeTargets\"]:
    print(f\"  [{t[\\\"health\\\"]:7}] {t[\\\"labels\\\"][\\\"job\\\"]:20} {t[\\\"scrapeUrl\\\"]}\")
"'

echo "==> Done. Open Grafana via SSH tunnel:"
echo "    ssh -L 3000:127.0.0.1:3000 $PI_HOST"
echo "    then visit http://localhost:3000  (folder: Hermes Pi)"
