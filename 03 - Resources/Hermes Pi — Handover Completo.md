# Hermes Pi — Handover Completo

> **Data:** 2026-05-23
> **Responsável:** Hugo Lopes
> **Cobertura:** Monitoramento (Prometheus/Grafana) + DNS (Pi-hole v6) + AI Gateway (Hermes Agent c/ OMLX)

---

## 1. Visão Geral

Arquitetura completa rodando no Raspberry Pi 5 (`hermes-pi`):

```
Mac (OMLX :8000, Qwen 7B) ← LAN → hermes-pi ─┬─ Pi-hole v6 (DNS :53, admin :80)
                                                ├─ Pi-hole Exporter (systemd :9607)
                                                ├─ Node Exporter (Docker :9100)
                                                ├─ Prometheus (Docker :9090)
                                                ├─ Grafana (Docker :3000)
                                                ├─ Hermes Gateway (Docker :8642)
                                                └─ Hermes Dashboard (Docker :9119)

Acesso externo: ZeroTier (172.24.39.82) ou LAN (192.168.31.246)
```

### 1.1 Endpoints

| Serviço | LAN | ZeroTier | Auth |
|---------|-----|----------|------|
| SSH | `192.168.31.246:22` | `172.24.39.82:22` | Chave SSH |
| Pi-hole admin | `192.168.31.246:80/admin` | `172.24.39.82:80/admin` | `$PIHOLE_PASSWORD` (.env) |
| Grafana | `127.0.0.1:3000` (SSH tunnel) | — | `admin` / `$GRAFANA_PASSWORD` |
| Prometheus | `127.0.0.1:9090` (local) | — | — |
| Hermes API | `127.0.0.1:8642/v1` | via SSH tunnel | Bearer `$HERMES_API_KEY` |
| Hermes Dashboard | `127.0.0.1:9119` | via SSH tunnel | `--insecure` — token na página |
| Node Exporter | `:9100/metrics` | — | — |
| Pi-hole Exporter | `:9607/metrics` | — | — |

---

## 2. Stack de Monitoramento

### 2.1 Prometheus

- **Container:** `prometheus` (Docker, `network_mode: host`)
- **Config:** `/home/hermes-pi/monitoring/prometheus/prometheus.yml`
- **Targets:** `localhost:9100` (node), `localhost:9607` (pihole), `localhost:9090` (self)
- **Comando:** `docker compose -f ~/docker-compose-services.yml up -d prometheus`

### 2.2 Node Exporter

- **Container:** `node-exporter` (Docker, `network_mode: host`, `pid: host`)
- **Porta:** 9100
- **Métricas:** CPU, memória, disco, rede do Pi

### 2.3 Grafana

- **Container:** `grafana` (Docker, bridge, porta publicada :3000)
- **Volume:** `grafana-data`
- **Data Source:** Prometheus em `http://localhost:9090`
- **Dashboards pendentes:** ID 1860 (Node Exporter Full), ID 11107 (Pi-hole)

### 2.4 Pi-hole v6

- **Container:** `pihole` (Docker, `network_mode: host`)
- **Portas:** 53/udp (DNS), 53/tcp (DNS TCP), 80/tcp (admin)
- **API auth:** SID via `POST /api/auth` (v6 não tem senha fixa na URL)
- **Senha admin:** lida de `$PIHOLE_PASSWORD` (`.env`)

### 2.5 Pi-hole Exporter (custom)

- **Tipo:** systemd service (não container)
- **Arquivo:** `/home/hermes-pi/pihole_exporter.py`
- **Porta:** 9607
- **Cache:** 30s
- **Auth:** Faz `POST /api/auth` com senha admin do Pi-hole, mantém SID ativo
- **Comandos:**
  ```bash
  sudo systemctl status pihole-exporter
  sudo journalctl -u pihole-exporter -n 50 --no-pager
  sudo systemctl restart pihole-exporter
  curl localhost:9607/metrics
  ```

---

## 3. AI Gateway (Hermes Agent)

### 3.1 Arquitetura

```
Cliente (opencode, curl, etc.) → Hermes Gateway (:8642) → OMLX (Mac, Qwen 7B)
                                                         → OpenRouter (fallback)
```

### 3.2 Componentes

**Gateway (API):**
- **Container:** `hermes` (Docker, bridge)
- **Porta:** 8642 (bound em `127.0.0.1` — usar SSH tunnel)
- **API Key:** `$HERMES_API_KEY` (em `.env`, nunca em markdown)
- **Provider primário:** OMLX no Mac (`192.168.31.117:8000/v1`)
- **Provider fallback:** OpenRouter (`$OPENROUTER_API_KEY` em `.env`)
- **Modelo:** `Qwen2.5-Coder-7B-Instruct-MLX-4bit`

**Dashboard (Web UI):**
- **Container:** `hermes-dashboard` (Docker, bridge)
- **Porta:** 9119
- **Depende de:** `hermes` (gateway)
- **Flag:** `--insecure` (bind em `0.0.0.0`, necessário para acesso remoto)
- **Funcionalidades:** kanban, histórico de sessões, stats, visualização de configs

### 3.3 Configuração

**`~/.hermes/config.yaml`**
```yaml
model:
  default: "Qwen2.5-Coder-7B-Instruct-MLX-4bit"
  provider: "custom"
  base_url: "http://192.168.31.117:8000/v1"
  api_key: "${OMLX_API_KEY}"   # expandido a partir do .env

fallback_providers:
  - provider: "openrouter"
    model: "qwen/qwen-2.5-coder-7b-instruct"
```

**`~/.hermes/.env`** (chmod 600, nunca commitar)
```
OMLX_API_KEY=<gerar com: openssl rand -hex 32>
OPENROUTER_API_KEY=<chave real do openrouter.ai>
```

### 3.4 Comandos

```bash
# Logs
docker compose -f ~/docker-compose-services.yml logs -f hermes
docker compose -f ~/docker-compose-services.yml logs -f hermes-dashboard

# Reiniciar (puxa novo config.yaml)
docker compose -f ~/docker-compose-services.yml restart hermes

# Testar API (lê a chave do .env, nunca cole no histórico do shell)
source ~/docker-compose-services.env   # contém HERMES_API_KEY=...
curl http://localhost:8642/v1/models -H "Authorization: Bearer $HERMES_API_KEY"
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

---

## 4. OMLX (Mac — Provider Local)

### 4.1 Configuração

- **Servidor:** OMLX rodando no Mac (`192.168.31.117`)
- **Porta:** 8000
- **API Key:** `$OMLX_API_KEY` (em `~/.omlx/settings.json` no Mac; ver `.env.example`)
- **Host:** `192.168.31.117` (apenas LAN do Mac — **não usar 0.0.0.0** em redes não confiáveis)
- **Modelo carregado:** `Qwen2.5-Coder-7B-Instruct-MLX-4bit`
- **Config:** `/Users/hugonlopes/.omlx/settings.json`

### 4.2 Acesso do Mac

```bash
# A chave fica no Keychain do Mac (security add-generic-password -s omlx-key ...)
export OMLX_API_KEY="$(security find-generic-password -a "$USER" -s omlx-key -w)"

# Listar modelos
curl http://localhost:8000/v1/models -H "Authorization: Bearer $OMLX_API_KEY"

# Chat direto (sem Hermes)
curl http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer $OMLX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen2.5-Coder-7B-Instruct-MLX-4bit","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

### 4.3 Notas

- OMLX precisa estar **rodando no Mac** para o Hermes funcionar
- Se OMLX cair, Hermes tenta fallback pro OpenRouter
- A porta 8000 precisa estar acessível de `192.168.31.117` (LAN) — configurado via `host: 0.0.0.0`

---

## 5. Rede e Firewall

### 5.1 Endereços

| Dispositivo | LAN | ZeroTier | Função |
|-------------|-----|----------|--------|
| hermes-pi | `192.168.31.246` | `172.24.39.82` | Servidor |
| MacBook | `192.168.31.117` | — | Provider OMLX |

### 5.2 UFW

```bash
Status: active
Portas liberadas:
  22/tcp    — SSH (qualquer origem)
  53/udp    — Pi-hole DNS (LAN)
  53/tcp    — Pi-hole DNS TCP (LAN)
  80/tcp    — Pi-hole admin (LAN)
  3000/tcp  — Grafana (LAN)
  9090/tcp  — Prometheus (LAN)
  9100/tcp  — Node Exporter (LAN)
  9607/tcp  — Pi-hole Exporter (LAN)
  8642/tcp  — Hermes API (LAN)
  9119/tcp  — Hermes Dashboard (LAN)
```

> **⚠️ Importante:** Containers Docker com portas publicadas (`ports:` no compose) escrevem regras direto no iptables, **ignorando UFW**. Na prática, UFW controla efetivamente: SSH (22), Pi-hole DNS (53) e Pi-hole Exporter (9607). As portas Docker (3000, 9090, 9100, 8642, 9119) estão abertas independente do UFW.

### 5.3 Docker Networking

- **Host network:** Pi-hole, Node Exporter, Prometheus
- **Bridge com portas:** Grafana (:3000), Hermes (:8642), Dashboard (:9119)

---

## 6. Docker Compose

**Arquivo:** `~/docker-compose-services.yml`

```yaml
services:
  pihole:           # host network, :53/:80
  node-exporter:    # host network, :9100
  prometheus:       # host network, :9090
  grafana:          # bridge, :3000
  hermes:           # bridge, 127.0.0.1:8642 (API key: $HERMES_API_KEY)
  hermes-dashboard: # bridge, :9119 (--insecure)

volumes:
  etc-pihole, etc-dnsmasq, prometheus-data, grafana-data
```

**Comandos úteis:**

```bash
# Parar tudo
docker compose -f ~/docker-compose-services.yml down

# Subir tudo
docker compose -f ~/docker-compose-services.yml up -d

# Logs de tudo em tempo real
docker compose -f ~/docker-compose-services.yml logs -f -t

# Atualizar imagens
docker compose -f ~/docker-compose-services.yml pull
docker compose -f ~/docker-compose-services.yml up -d
```

---

## 7. Lições Aprendidas

### 7.1 Prometheus em host network

**Problema:** Containers em bridge não conseguiram acessar `192.168.31.246:9607` (Pi-hole Exporter) — timeout, rota bloqueada pelo Docker iptables.

**Solução:** Mudar Prometheus para `network_mode: host` e usar `localhost:*` nos targets. Perde-se isolamento de rede, mas ganha-se acesso direto a todos os serviços do host. Todos os targets usam `localhost` agora.

### 7.2 Pi-hole Exporter e API v6

**Problema:** `ekofr/pihole-exporter` (imagem Docker) não suporta Pi-hole v6 (API mudou: precisa de SID via `POST /api/auth`).

**Solução:** Exporter customizado em Python (`pihole_exporter.py`), rodando como systemd service. Faz login a cada requisição (cache 30s do SID). `BrokenPipeError` tratado com `try/except` no `do_GET`.

### 7.3 UFW bloqueou SSH

**Problema:** Ao rodar `ufw --force enable` sem antes liberar a porta 22, perdeu-se acesso SSH ao Pi. Foi necessário acesso físico (monitor + teclado).

**Solução:** Sempre rodar `ufw allow ssh` **antes** de `ufw --force enable`.

### 7.4 Hermes chown lento

**Problema:** O entrypoint do Hermes roda `chown -R hermes:hermes /opt/hermes/.venv` a cada inicialização, levando ~30s em cada container.

**Solução:** Nenhuma (comportamento do entrypoint). Apenas aguardar o chown terminar antes de testar conectividade.

### 7.5 OMLX host binding

**Problema:** OMLX inicialmente configurado com `host: 127.0.0.1`, inacessível do Pi.

**Solução:** Mudar para `host: 0.0.0.0` no `settings.json` e reiniciar OMLX.

---

## 8. Segurança

### 8.1 Credenciais

Todas as credenciais ficam em `~/docker-compose-services.env` (chmod 600, gitignored).
Ver `03 - Resources/.env.example` como template. **Nenhuma credencial deve aparecer neste documento.**

Gerar com: `openssl rand -hex 32`

| Serviço | Variável |
|---------|----------|
| Pi-hole admin | `$PIHOLE_PASSWORD` |
| Grafana | `$GRAFANA_PASSWORD` |
| Hermes API | `$HERMES_API_KEY` |
| OMLX | `$OMLX_API_KEY` (Mac Keychain) |
| OpenRouter | `$OPENROUTER_API_KEY` |

### 8.2 Acesso externo

- **ZeroTier:** Único método de acesso externo — seguro, sem portas expostas no roteador
- **LAN:** Acesso local apenas (UFW restringe a `192.168.31.0/24`)
- **NUNCA** fazer port forwarding no roteador

### 8.3 Containers com `--insecure`

O Hermes Dashboard usa `--insecure` porque expõe API keys e configs sem autenticação robusta. Está atrás do ZeroTier (restringido a dispositivos na rede), mas é um risco consciente.

---

## 9. Pendências

- [ ] Colocar chave real do OpenRouter em `~/.hermes/.env`
- [ ] Importar dashboards Grafana: ID 1860 (Node Exporter), ID 11107 (Pi-hole)
- [ ] Trocar senhas default (Pi-hole, Grafana)
- [ ] Backup automático dos volumes Docker via cron

---

## 10. Referências

| Recurso | Caminho no Vault |
|---------|------------------|
| Setup completo | `01 - Projects/Monitoramento Hermes Pi.md` |
| Guia pós-setup | `03 - Resources/Hermes Pi — Pós-Setup e Workflow.md` |
| Handover Pi-hole | `03 - Resources/Monitoring Pi-hole v6 — Handover.md` |
| Docker Compose | `03 - Resources/docker-compose-services.yml` |
| Exporter Python | `pihole_exporter.py` |
| Script de setup | `setup_rpi.sh` |
| Hermes Config | `/home/hermes-pi/.hermes/config.yaml` |
| OMLX Config | `/Users/hugonlopes/.omlx/settings.json` |
