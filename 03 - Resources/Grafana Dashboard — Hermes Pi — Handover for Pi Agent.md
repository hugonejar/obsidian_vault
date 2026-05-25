# Grafana Dashboard — Hermes Pi — Handover for Pi Agent

> **Target:** Agent running on Raspberry Pi (`hermes-pi`, `192.168.31.246`, `/home/hermes-pi/`)
> **Goal:** Complete the Grafana dashboard stack: deploy new services, import dashboards, enable provisioning, configure alerting
> **Parent plan:** `01 - Projects/Grafana Dashboard — Hermes Pi.md`

---

## 0. Current state

### Already running (confirmed)
- **Pi-hole v6** — Docker, host network, `:53` (DNS), `:80` (admin)
- **Pi-hole Exporter** — systemd service, `pihole_exporter.py`, `:9607/metrics`
- **Node Exporter** — Docker, host network, `:9100/metrics`
- **Prometheus** — Docker, host network, `:9090`
- **Grafana** — Docker, bridge, `127.0.0.1:3000`
- **Hermes Gateway** — Docker, bridge, `127.0.0.1:8642`
- **Hermes Dashboard** — Docker, bridge, `127.0.0.1:9119`

### Already in docker-compose.yml (from vault) but NOT yet deployed to Pi
- **cAdvisor** — `gcr.io/cadvisor/cadvisor:v0.49.1`, host network, `127.0.0.1:8080`
- **Blackbox Exporter** — `prom/blackbox-exporter:v0.25.0`, `127.0.0.1:9115`

### Files already built in vault (need to be copied to Pi)
- `monitoring/blackbox.yml` — probe modules (http_2xx, http_2xx_or_401, tcp_connect, icmp)
- `monitoring/prometheus/prometheus.yml` — scrape jobs for node, cadvisor, pihole, prometheus, blackbox-http, blackbox-tcp, plus alert rules
- `monitoring/prometheus/rules/hermes-pi-alerts.yml` — 12 alert rules (critical/warning)
- `monitoring/grafana/provisioning/datasources/prometheus.yml` — Prometheus datasource
- `monitoring/grafana/provisioning/dashboards/providers.yml` — dashboard provisioning
- `monitoring/grafana/dashboards/hermes-pi-overview.json` — custom overview dashboard
- `monitoring/deploy.sh` — deployment script

---

## 1. Deploy new services

### 1.1 Copy files to Pi

From the Mac's vault (`/Users/hugonlopes/code/obsidian_vault/03 - Resources/`), run:

```bash
# On the Mac:
PI="pi@192.168.31.246"

rsync -avz --delete \
  /Users/hugonlopes/code/obsidian_vault/03\ -\ Resources/monitoring/ \
  "$PI:~/monitoring/"

scp /Users/hugonlopes/code/obsidian_vault/03\ -\ Resources/docker-compose-services.yml \
  "$PI:~/docker-compose-services.yml"
```

### 1.2 Ensure .env exists on Pi

```bash
# On the Pi — fail if missing:
test -f ~/docker-compose-services.env || echo "MISSING .env file"
```

Required vars in `~/docker-compose-services.env`:
```
PIHOLE_PASSWORD=<generated>
GRAFANA_PASSWORD=<generated>
HERMES_API_KEY=<generated>
OPENROUTER_API_KEY=<key from openrouter.ai>
```

### 1.3 Pull and start new services

```bash
# On the Pi:
cd ~
docker compose --env-file docker-compose-services.env \
  -f docker-compose-services.yml \
  pull cadvisor blackbox-exporter

docker compose --env-file docker-compose-services.env \
  -f docker-compose-services.yml \
  up -d cadvisor blackbox-exporter
```

### 1.4 Reload Prometheus config

```bash
# On the Pi:
curl -fsS -X POST http://127.0.0.1:9090/-/reload || docker restart prometheus
```

### 1.5 Restart Grafana for provisioning

```bash
# On the Pi:
docker restart grafana
```

### 1.6 Verify targets are UP

```bash
# On the Pi — all should show "up" health:
curl -fsS http://127.0.0.1:9090/api/v1/targets?state=active | python3 -c "
import json, sys
d = json.load(sys.stdin)
for t in d['data']['activeTargets']:
    print(f\"  [{t['health']:7}] {t['labels']['job']:20} {t['scrapeUrl']}\")
"
```

Expected output:
```
  [up    ] node                  http://localhost:9100/metrics
  [up    ] cadvisor              http://localhost:8080/metrics
  [up    ] pihole                http://localhost:9607/metrics
  [up    ] prometheus            http://localhost:9090/metrics
  [up    ] blackbox-http         http://localhost:9115/probe
  [up    ] blackbox-tcp          http://localhost:9115/probe
```

---

## 2. Import community dashboards

Access Grafana via SSH tunnel from Mac:
```bash
ssh -L 3000:127.0.0.1:3000 pi@192.168.31.246
# Then open http://localhost:3000 in browser
```

### Dashboards to import (via Grafana UI → Dashboards → New → Import):

| Dashboard | ID | Notes |
|-----------|-----|-------|
| Node Exporter Full | **1860** | Set Prometheus datasource |
| Docker / cAdvisor | **14282** | Works out-of-the-box |
| Blackbox Exporter | **7587** | Set Prometheus datasource |
| Prometheus Stats | **2** (official) | Set Prometheus datasource |

After importing each, set the datasource to the Prometheus one (already provisioned as default).

Alternatively, you can download the JSON from `https://grafana.com/api/dashboards/<ID>/revisions/latest/download` and save to `~/monitoring/grafana/dashboards/community/` for provisioning.

---

## 3. Custom dashboard — already built

The `hermes-pi-overview.json` is already provisioned. After Grafana restarts, it should appear in the "Hermes Pi" folder.

### Structure:
- **Row 0 — Status Geral** (6 stat panels): Pi Uptime, Containers Running, Pi-hole % Blocked, Hermes API, OMLX (Mac), CPU Temp
- **Row 1 — Host (Pi 5)**: CPU %, Memory, Disk %, Network throughput
- **Row 2 — Containers**: CPU % per container, Memory per container (working set), Container status table
- **Row 3 — Pi-hole DNS**: Queries/sec, Cached vs forwarded, Active clients, Gravity domains, Unique domains
- **Row 4 — Hermes + OMLX**: Probe latency, Hermes container CPU + RAM

### Dashboard links (bottom-left menu):
- Node Exporter Full → `/d/rYdddlPWk/node-exporter-full`
- Docker / cAdvisor → `/d/pMEd7m0Mz/docker-and-system-monitoring`
- Blackbox Probes → `/d/xtkCtBkiz/prometheus-blackbox-exporter`
- Prometheus Stats → `/d/prometheus-stats`

---

## 4. Export JSONs to provisioning (for git versioning)

After customising any dashboard in the UI, sync it back to provisioning:

```bash
# List dashboards on Grafana API (password from .env):
GRAFANA_PASS=$(grep GRAFANA_PASSWORD ~/docker-compose-services.env | cut -d= -f2)

# Export the Hermes Pi dashboard:
curl -s http://admin:$GRAFANA_PASS@127.0.0.1:3000/api/dashboards/uid/hermes-pi-overview \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['dashboard'], indent=2))" \
  > ~/monitoring/grafana/dashboards/hermes-pi-overview.json

# Export community dashboards that were customised:
# (replace UIDs as needed)
for uid in rYdddlPWk pMEd7m0Mz xtkCtBkiz prometheus-stats; do
  curl -s http://admin:$GRAFANA_PASS@127.0.0.1:3000/api/dashboards/uid/$uid \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['dashboard'], indent=2))" \
    > ~/monitoring/grafana/dashboards/community/${uid}.json
done
```

---

## 5. Alerting — already configured

Alert rules are in `~/monitoring/prometheus/rules/hermes-pi-alerts.yml`.
Referenced by `prometheus.yml` via `rule_files: [/etc/prometheus/rules/*.yml]`.

### Alerts configured:

| Alert | Severity | Condition |
|-------|----------|-----------|
| PiUnreachable | critical | `up{job="node"} == 0` for 2m |
| HighCPU | warning | CPU > 85% for 10m |
| HighMemory | warning | RAM > 90% for 10m |
| DiskFillingUp | warning | Disk > 85% for 10m |
| DiskCritical | critical | Disk > 95% for 5m |
| PiHot | warning | Temp > 75°C for 5m |
| PiThrottle | critical | Temp > 82°C for 1m |
| ContainerDown | critical | Not seen for 2m |
| ContainerRestartLoop | warning | >3 restarts in 15m |
| HermesAPIDown | critical | Probe failing 5m |
| OMLXDown | warning | Mac unreachable 10m |
| GrafanaDown | warning | Health failing 5m |
| PiHoleExporterMissing | warning | Metric absent 5m |
| PiHoleBlockingStopped | warning | 0 blocked while queries active |
| TargetDown | warning | Any target down 5m |

### Prometheus rule files already loaded:
After Prometheus reloads (step 1.4), verify:

```bash
curl -s http://127.0.0.1:9090/api/v1/rules | python3 -c "
import json, sys
d = json.load(sys.stdin)
for g in d['data']['groups']:
    print(f\"Group: {g['name']} ({len(g['rules'])} rules)\")
    for r in g['rules']:
        print(f\"  [{r['state']:8}] {r['name']}\")
"
```

Alerts fire silently to Prometheus logs by default. For notifications:

#### Option A: Grafana Unified Alerting

In Grafana UI → Alerting → Alert rules → Import each rule from "Prometheus" format → Add contact point.

#### Option B: Prometheus Alertmanager

Uncomment the `alerting:` block in `prometheus.yml` and point to Alertmanager on `localhost:9093`.

Contact point initial: Grafana logs. Future: Discord webhook (bot already exists).

---

## 6. Validation

### 6.1 All Prometheus targets UP

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c "
import json, sys
d = json.load(sys.stdin)
targets = d['data']['activeTargets']
down = [t for t in targets if t['health'] != 'up']
if down:
    print(f'DOWN targets: {len(down)}')
    for t in down: print(f'  {t[\"labels\"][\"job\"]}: {t[\"labels\"][\"instance\"]}')
else:
    print(f'All {len(targets)} targets UP ✓')
"
```

### 6.2 cAdvisor metrics

```bash
curl -s http://127.0.0.1:8080/metrics | grep -E 'container_cpu_usage|container_memory_rss' | head -5
```

### 6.3 Blackbox probe metrics

```bash
curl -s http://127.0.0.1:9115/probe?module=http_2xx_or_401&target=http://localhost:8642/v1/models | grep probe_success
```

### 6.4 Grafana provisioning loaded

```bash
curl -s http://admin:$GRAFANA_PASS@127.0.0.1:3000/api/search?folder=Hermes%20Pi | python3 -m json.tool
```

### 6.5 Dashboard accessible

```bash
curl -s -o /dev/null -w "%{http_code}" http://admin:$GRAFANA_PASS@127.0.0.1:3000/d/hermes-pi-overview
# Should return 200
```

---

## 7. Quick setup (one-liner to do everything)

If the monitoring files are already in place, this single command sequence does it all:

```bash
cd ~ && \
docker compose --env-file docker-compose-services.env -f docker-compose-services.yml pull cadvisor blackbox-exporter && \
docker compose --env-file docker-compose-services.env -f docker-compose-services.yml up -d cadvisor blackbox-exporter && \
curl -fsS -X POST http://127.0.0.1:9090/-/reload && \
docker restart grafana && \
echo "Waiting 15s..." && sleep 15 && \
curl -s http://127.0.0.1:9090/api/v1/targets?state=active | python3 -c "
import json, sys
d = json.load(sys.stdin)
down = [t for t in d['data']['activeTargets'] if t['health'] != 'up']
if down:
    print(f'FAIL: {len(down)} targets not UP')
    for t in down: print(f'  {t[\"labels\"][\"job\"]}: {t[\"labels\"][\"instance\"]}')
else:
    print(f'OK — all {len(d[\"data\"][\"activeTargets\"])} targets UP')
" && \
echo "=== Done ===" && \
echo "Access Grafana: ssh -L 3000:127.0.0.1:3000 pi@192.168.31.246 && open http://localhost:3000"
```

---

## 8. Agent instructions summary

1. **Start here**: verify you are on the Pi at `/home/hermes-pi/`
2. **Section 1**: deploy cAdvisor + blackbox-exporter, reload Prometheus, restart Grafana
3. **Section 2**: import community dashboards (1860, 14282, 7587, 2) via Grafana UI
4. **Section 3**: the overview dashboard is already provisioned — verify it appears in "Hermes Pi" folder
5. **Section 4**: export any customised dashboards back to JSON files
6. **Section 5**: alerting is pre-configured in Prometheus rules — verify with the validation query
7. **Section 6**: run all validation checks and report results

If any step fails, report the error and the output of the failing command.
