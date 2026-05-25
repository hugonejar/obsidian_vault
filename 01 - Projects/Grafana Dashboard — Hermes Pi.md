# Grafana Dashboard — Hermes Pi (Plano Completo)

> **Data:** 2026-05-23
> **Objetivo:** Dashboard único em Grafana cobrindo Pi (host), todos containers Docker, Pi-hole DNS, Hermes AI Gateway e provider OMLX no Mac.
> **Refresh:** 30s · **Time range default:** Last 6 hours

---

## 1. Inventário de fontes de métricas

### 1.1 Já existe

| Exporter | Porta | Cobre | Status |
|----------|-------|-------|--------|
| node-exporter | `:9100` | CPU, RAM, disco, rede, load, filesystem do host | ✅ rodando |
| pihole-exporter (custom) | `127.0.0.1:9607` | Queries totais/bloqueadas/cached, clientes ativos, gravity | ✅ rodando |
| prometheus | `127.0.0.1:9090` | Self-monitoring (scrape duration, target up) | ✅ rodando |

### 1.2 Gaps a preencher

Para "monitorar **todos os containers e apps**" faltam três peças. Sem isso o dashboard não consegue mostrar CPU/RAM por container ou subir alertas de container caído.

| Componente | Para que serve | Imagem ARM64 |
|-----------|----------------|--------------|
| **cAdvisor** | Métricas por container: CPU, memória, rede, I/O, restart count | `gcr.io/cadvisor/cadvisor:v0.49.1` |
| **blackbox-exporter** | Health-check HTTP/TCP em endpoints (Hermes API, Grafana, OMLX no Mac) | `prom/blackbox-exporter:v0.25.0` |
| **process-exporter** *(opcional)* | Métricas de processos systemd no host (pihole-exporter.service) | `ncabatoff/process-exporter:0.8.4` |

> O Hermes Agent não expõe `/metrics` nativo. Cobrimos via blackbox-exporter (probe HTTP 200 no `/v1/models`) + cAdvisor (CPU/RAM do container).
> O OMLX no Mac também é coberto via blackbox-exporter probando `http://192.168.31.117:8000/v1/models`.

---

## 2. Estrutura do dashboard

UID sugerido: `hermes-pi-overview` · Folder: `Hermes Pi`

```
┌─────────────────────────────────────────────────────────────────┐
│ Row 0 — STATUS GERAL (stat panels, sempre no topo)              │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐       │
│  │ Pi up    │ Containers│ Pi-hole  │ Hermes   │ OMLX     │       │
│  │ uptime   │ running   │ blocking │ API 200  │ API 200  │       │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘       │
├─────────────────────────────────────────────────────────────────┤
│ Row 1 — HOST (Raspberry Pi 5)                                   │
│  CPU %    │ Load 1/5/15  │ RAM used/free │ Temp CPU             │
│  Disk used per mount │ Network rx/tx eth0/wlan0                 │
│  Disk I/O read/write │ Filesystem inode usage                   │
├─────────────────────────────────────────────────────────────────┤
│ Row 2 — CONTAINERS (cAdvisor, repeat por $container)            │
│  Tabela: nome │ status │ CPU% │ RSS │ rx │ tx │ restart count   │
│  Time series: CPU per container (stacked)                       │
│  Time series: Memory per container (stacked)                    │
│  Time series: Net I/O per container                             │
├─────────────────────────────────────────────────────────────────┤
│ Row 3 — PI-HOLE DNS                                             │
│  Queries/sec │ Blocked/sec │ % blocked │ Clients ativos         │
│  Gravity domains (gauge) │ Cached vs forwarded (stack)          │
│  Top clients (table, opcional via FTL API extension)            │
├─────────────────────────────────────────────────────────────────┤
│ Row 4 — HERMES AI GATEWAY                                       │
│  Probe up (Hermes :8642) │ Probe up (OMLX :8000)                │
│  Probe latency (ms)      │ HTTP status code timeline            │
│  Container CPU/RAM (cAdvisor, hermes + hermes-dashboard)        │
├─────────────────────────────────────────────────────────────────┤
│ Row 5 — PROMETHEUS SELF                                         │
│  Scrape duration p95 │ Target up matrix │ TSDB head series      │
│  Storage size on disk │ Samples ingested/sec                    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Template variables

| Var | Query | Uso |
|-----|-------|-----|
| `$datasource` | Prometheus | Datasource picker |
| `$instance` | `label_values(node_uname_info, instance)` | Host (futuro: multi-Pi) |
| `$container` | `label_values(container_last_seen{name!=""}, name)` | Filtro por container |
| `$fs` | `label_values(node_filesystem_size_bytes{fstype!~"tmpfs\|overlay"}, mountpoint)` | Filtro de mountpoint |
| `$probe` | `label_values(probe_success, instance)` | Endpoint blackbox |

---

## 3. PromQL por painel

### Row 0 — Status geral (todos `stat`)

| Painel | Query | Threshold |
|--------|-------|-----------|
| Pi uptime | `time() - node_boot_time_seconds{instance=~"$instance"}` | green |
| Containers running | `count(container_last_seen{name!=""} > (time() - 60))` | red <5, green ≥5 |
| Pi-hole % blocked | `pihole_queries_percent_blocked` | red <5, yellow 5–10, green >10 |
| Hermes API up | `probe_success{instance="http://hermes:8642/v1/models"}` | red 0, green 1 |
| OMLX API up | `probe_success{instance="http://192.168.31.117:8000/v1/models"}` | red 0, green 1 |

### Row 1 — Host

```promql
# CPU % (todos modos exceto idle)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)

# Load average
node_load1 ; node_load5 ; node_load15

# RAM usada
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes
# RAM %
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Temperatura CPU (Pi 5 expõe via hwmon; node-exporter coleta automático)
node_hwmon_temp_celsius{chip=~".*thermal.*"}

# Disco usado por mountpoint
100 - (node_filesystem_avail_bytes{mountpoint=~"$fs",fstype!~"tmpfs|overlay"}
       / node_filesystem_size_bytes * 100)

# Rede rx/tx por interface
rate(node_network_receive_bytes_total{device!~"lo|docker.*|veth.*"}[2m])
rate(node_network_transmit_bytes_total{device!~"lo|docker.*|veth.*"}[2m])

# Disco I/O
rate(node_disk_read_bytes_total[2m])
rate(node_disk_written_bytes_total[2m])

# Inodes
100 - (node_filesystem_files_free / node_filesystem_files * 100)
```

### Row 2 — Containers (cAdvisor)

```promql
# CPU % por container
sum by (name) (rate(container_cpu_usage_seconds_total{name=~"$container",name!=""}[2m])) * 100

# Memória RSS por container
sum by (name) (container_memory_rss{name=~"$container",name!=""})

# Memória working set (mais próxima do "memory" que o docker stats mostra)
sum by (name) (container_memory_working_set_bytes{name=~"$container",name!=""})

# Network rx/tx por container
sum by (name) (rate(container_network_receive_bytes_total{name=~"$container"}[2m]))
sum by (name) (rate(container_network_transmit_bytes_total{name=~"$container"}[2m]))

# Restart count (último valor; spike = container crashou)
changes(container_start_time_seconds{name!=""}[1h])

# Tabela "container status" — usar transformação em Grafana sobre:
container_last_seen{name!=""}
container_spec_memory_limit_bytes{name!=""}
```

### Row 3 — Pi-hole

```promql
# Queries por segundo (vem do exporter custom como counter)
rate(pihole_queries_total[5m])

# Bloqueadas/sec
rate(pihole_queries_blocked[5m])

# % bloqueado (gauge direto)
pihole_queries_percent_blocked

# Clientes ativos (gauge)
pihole_clients_active

# Domínios na blocklist (gauge)
pihole_gravity_domains

# Cached vs forwarded (stack)
rate(pihole_queries_cached[5m])
rate(pihole_queries_forwarded[5m])

# Unique domains
pihole_queries_unique_domains
```

### Row 4 — Hermes Gateway + OMLX

```promql
# Probes blackbox
probe_success{instance=~"http://hermes.*|http://192.168.31.117.*"}
probe_duration_seconds{instance=~"http://hermes.*|http://192.168.31.117.*"}
probe_http_status_code{instance=~"http://hermes.*"}

# Container CPU/RAM (hermes + dashboard, via cAdvisor)
sum by (name) (rate(container_cpu_usage_seconds_total{name=~"hermes.*"}[2m])) * 100
sum by (name) (container_memory_working_set_bytes{name=~"hermes.*"})

# Tempo desde último 200 OK (alerta-friendly)
time() - probe_success_timestamp{instance="http://hermes:8642/v1/models"}
```

### Row 5 — Prometheus self

```promql
# Scrape duration p95 por job
histogram_quantile(0.95, sum by (job,le) (rate(scrape_duration_seconds_bucket[5m])))

# Targets up/down (matriz)
up

# TSDB head series
prometheus_tsdb_head_series

# Disk used
prometheus_tsdb_storage_blocks_bytes

# Sample ingestion rate
rate(prometheus_tsdb_head_samples_appended_total[5m])
```

---

## 4. Alertas (Grafana unified alerting ou Prometheus rules)

Severities: `critical` (paginar/notificar imediato) · `warning` (revisar em 24h).

| Alerta | Expressão | Para | Severity |
|--------|-----------|------|----------|
| Pi inacessível | `up{job="node"} == 0` | 2m | critical |
| Container caiu | `time() - container_last_seen{name!=""} > 120` | 2m | critical |
| Container reiniciando em loop | `increase(container_start_time_seconds{name!=""}[15m]) > 3` | 5m | warning |
| Disco >85% | `100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100) > 85` | 10m | warning |
| Disco >95% | mesma >95 | 5m | critical |
| RAM >90% | `100 * (1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes) > 90` | 10m | warning |
| Pi temp >75°C | `node_hwmon_temp_celsius > 75` | 5m | warning |
| Pi temp >82°C (throttle) | `node_hwmon_temp_celsius > 82` | 1m | critical |
| Hermes API down | `probe_success{instance="http://hermes:8642/v1/models"} == 0` | 5m | critical |
| OMLX down | `probe_success{instance=~"http://192.168.31.117:8000.*"} == 0` | 10m | warning |
| Pi-hole bloqueio caiu | `rate(pihole_queries_blocked[10m]) == 0 and rate(pihole_queries_total[10m]) > 0` | 15m | warning |
| Pi-hole exporter erro | `absent(pihole_queries_total)` | 5m | warning |
| Prometheus alvo down | `up == 0` | 5m | warning |

Contact point inicial: **logs do Grafana**. Depois plugar webhook → Discord bot (já presente).

---

## 5. Deploy

### 5.1 Adicionar cAdvisor + blackbox ao compose

Em `~/docker-compose-services.yml`, anexar:

```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    command:
      - --housekeeping_interval=10s
      - --docker_only=true
      - --listen_ip=127.0.0.1
      - --port=8080
    network_mode: host

  blackbox-exporter:
    image: prom/blackbox-exporter:v0.25.0
    container_name: blackbox-exporter
    restart: unless-stopped
    volumes:
      - ./blackbox.yml:/etc/blackbox_exporter/config.yml:ro
    ports:
      - "127.0.0.1:9115:9115"
```

`~/monitoring/blackbox.yml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      preferred_ip_protocol: ip4
      valid_status_codes: [200]
  http_2xx_auth:
    prober: http
    timeout: 5s
    http:
      preferred_ip_protocol: ip4
      valid_status_codes: [200]
      bearer_token_file: /etc/blackbox_exporter/hermes-token
  tcp_connect:
    prober: tcp
    timeout: 3s
```

### 5.2 Atualizar `prometheus.yml`

Adicionar jobs:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'pihole'
    static_configs:
      - targets: ['localhost:9607']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://localhost:8642/v1/models       # Hermes (sem auth dá 401, ver nota)
          - http://localhost:3000/api/health      # Grafana
          - http://192.168.31.117:8000/v1/models  # OMLX (Mac)
          - http://localhost/admin/                # Pi-hole admin
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115
```

> **Nota Hermes auth:** `/v1/models` requer Bearer token. Opções:
> 1. Probar `GET /healthz` se existir (sem auth)
> 2. Usar módulo `http_2xx_auth` com `valid_status_codes: [200, 401]` (401 = serviço respondendo, mesmo sem auth)
> 3. Mais limpo: montar `bearer_token_file` no container blackbox apontando para `${HERMES_API_KEY}`

### 5.3 Importar dashboards comunitários como base

Em vez de construir do zero, importar via UI ou provisioning:

| Dashboard | ID | Cobre | Customização |
|-----------|-----|-------|---------------|
| Node Exporter Full | **1860** | Toda Row 1 (host) | Trocar datasource para Prometheus local |
| Docker / cAdvisor | **14282** | Toda Row 2 (containers) | OK out-of-the-box |
| Pi-hole (v6 compatível) | **15826** | Parcial — talvez precisar adaptar para o exporter custom | Reescrever queries para `pihole_*` |
| Blackbox Exporter | **7587** | Toda Row 4 (probes) | OK |
| Prometheus Stats | **2 (oficial)** | Toda Row 5 | OK |

**Recomendação:** importar os 5 acima, criar dashboard "Hermes Pi — Overview" próprio com Row 0 (status), e linkar os outros via "Dashboard links" no menu.

### 5.4 Provisioning (versionar dashboards no git)

Em `~/monitoring/grafana/provisioning/dashboards/`:

```yaml
# default.yaml
apiVersion: 1
providers:
  - name: 'hermes-pi'
    folder: 'Hermes Pi'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards
```

Adicionar volume no Grafana:
```yaml
grafana:
  volumes:
    - grafana-data:/var/lib/grafana
    - ./grafana/provisioning:/etc/grafana/provisioning:ro
```

Assim os JSONs dos dashboards ficam em `~/monitoring/grafana/provisioning/dashboards/*.json` e versionados no git.

---

## 6. Ordem de execução

1. [ ] Criar `~/monitoring/blackbox.yml` no Pi
2. [ ] Atualizar `~/docker-compose-services.yml` com cAdvisor + blackbox
3. [ ] Atualizar `~/monitoring/prometheus/prometheus.yml` com novos jobs
4. [ ] `docker compose up -d cadvisor blackbox-exporter && docker compose restart prometheus`
5. [ ] Verificar targets em `http://localhost:9090/targets` (todos UP)
6. [ ] Importar dashboards 1860, 14282, 7587, 2 via UI Grafana
7. [ ] Criar dashboard "Hermes Pi — Overview" (Row 0 custom) e exportar JSON
8. [ ] Adaptar dashboard 15826 (Pi-hole) para queries do exporter custom — exportar JSON
9. [ ] Mover JSONs para provisioning e committar no git
10. [ ] Configurar alertas (seção 4) via UI ou `alertmanager` (se quiser routing avançado)
11. [ ] Validar: subir um container fake, parar, ver alerta disparar

---

## 7. Custo de recursos no Pi 5

Estimativa após adicionar cAdvisor + blackbox:

| Componente | RAM | CPU idle |
|-----------|-----|----------|
| cAdvisor | ~80 MB | ~2% |
| blackbox-exporter | ~15 MB | <1% |
| Prometheus (com nova carga) | +50 MB | +1% |
| **Total adicional** | **~150 MB** | **~4%** |

Pi 5 8GB aguenta tranquilo. Storage TSDB: ~50 MB/dia com retention default de 15 dias.

---

## 8. Referências cruzadas

- [[Hermes Pi — Handover Completo]] — stack atual
- [[Monitoring Pi-hole v6 — Handover]] — detalhes do exporter custom
- [[Monitoramento Hermes Pi]] — projeto pai
- [[SECURITY-CHECKLIST]] — bloqueio de portas (cAdvisor/blackbox devem ficar em `127.0.0.1`)

---

## 9. Execução

> **Status:** A configuração completa (cAdvisor, blackbox-exporter, prometheus.yml, alert rules, dashboard JSON / provisioning) já está construída no vault em `03 - Resources/monitoring/`.

### O que já está pronto

| Artefacto | Caminho no vault |
|-----------|------------------|
| Docker Compose (cAdvisor + blackbox) | `03 - Resources/docker-compose-services.yml` |
| Blackbox config | `03 - Resources/monitoring/blackbox.yml` |
| Prometheus config + alert rules | `03 - Resources/monitoring/prometheus/` |
| Dashboard Hermes Pi — Overview (JSON + provisioning) | `03 - Resources/monitoring/grafana/` |
| Deploy script | `03 - Resources/monitoring/deploy.sh` |

### O que falta (executar no Pi)

O handover para o agente que vai executar no Raspberry Pi está em:
→ [[03 - Resources/Grafana Dashboard — Hermes Pi — Handover for Pi Agent]]
