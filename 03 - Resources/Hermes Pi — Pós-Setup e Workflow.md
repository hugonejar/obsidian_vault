# Hermes Pi — Pós-Setup e Workflow

> Guia do que fazer depois de rodar o `setup_rpi.sh` no Raspberry Pi.
>
> **Atualizado:** 2026-05-23 — Hermes Agent com OMLX (Mac) + Dashboard incluídos.

---

## 1. Status atual (pós-setup com `--pihole`)

O script instalou e configurou:

| Serviço | Porta | Acesso | Como roda |
|---------|-------|--------|-----------|
| Docker Engine | — | `sudo docker ps` | nativo |
| Node.js 22 | — | `node --version` | nativo |
| opencode | — | `opencode` | nativo |
| Node Exporter | 9100 | `/metrics` | Docker, host network |
| Prometheus | 9090 | Web UI | Docker, host network |
| Grafana | 3000 | Web UI | Docker, bridge |
| Pi-hole | 53 / 80 | admin | Docker, host network |
| Pi-hole Exporter | 9607 | `/metrics` | systemd (Python) |
| Hermes Gateway | 8642 | API OpenAI-compatível | Docker, bridge |
| Hermes Dashboard | 9119 | Web UI | Docker, bridge |

---

## 2. Pós-setup imediato (5 min)

### 2.1 Recarregar grupo Docker

```bash
# Opção A: sair e entrar de novo
exit
ssh hermes-pi@192.168.31.246

# Opção B: recarregar grupo sem logout
newgrp docker
```

### 2.2 Verificar containers

```bash
sudo docker ps
# Deve mostrar: node-exporter, prometheus, grafana, pihole
```

### 2.3 Verificar exporter do Pi-hole

```bash
curl -s localhost:9607/metrics | head -5
# Deve mostrar pihole_queries_total, pihole_queries_blocked etc.
sudo systemctl status pihole-exporter --no-pager -l
```

### 2.4 Adicionar Prometheus como data source no Grafana

1. Browser → http://192.168.31.246:3000
2. Login: **admin** / **admin**
3. ⚙️ Settings → **Data Sources** → **Add data source** → **Prometheus**
4. URL: `http://localhost:9090` (importante: `localhost`, não `prometheus`)
5. **Save & Test** (deve mostrar verde)

### 2.5 Importar dashboards

**Node Exporter (sistema):**
1. No Grafana: **+** → **Import**
2. Dashboard ID: **1860** (Node Exporter Full)
3. Select **Prometheus** → **Import**

**Pi-hole (DNS):**
1. No Grafana: **+** → **Import**
2. Dashboard ID: **11107** (Pi-hole metrics)
3. Select **Prometheus** → **Import**

---

## 3. Arquitetura

```
                     ┌──────────────────────────────────────────────────┐
                     │               hermes-pi (RPi 5)                  │
                     │      LAN: 192.168.31.246  ZT: 172.24.39.82      │
                     │                                                  │
                     │  ┌────────────────────┐  ┌──────────────────┐   │
                     │  │  Pi-hole (Docker)  │  │  Node Exporter   │   │
                     │  │  host network      │  │  Docker          │   │
                     │  │  :53 (DNS)         │  │  host network    │   │
                     │  │  :80 (admin)       │  │  :9100/metrics   │   │
                     │  └────────┬───────────┘  └────────┬─────────┘   │
                     │           │ HTTP API               │             │
                     │           │ (auth + stats)         │             │
                     │           │                        │             │
                     │  ┌────────▼────────────────────────▼─────────┐  │
                     │  │     Prometheus (Docker, host network)      │  │
                     │  │     :9090                                 │  │
                     │  └───────────────────┬────────────────────────┘  │
                     │                      │                          │
                     │  ┌───────────────────▼────────────────────────┐  │
                     │  │  Grafana (Docker, bridge :3000)             │  │
                     │  │  Data Source: http://localhost:9090         │  │
                     │  └────────────────────────────────────────────┘  │
                     │                                                  │
                     │  ┌────────────────────────────────────────────┐  │
                     │  │  Pi-hole Exporter (systemd)                 │  │
                     │  │  pihole_exporter.py em Python               │  │
                     │  │  :9607/metrics, cache 30s                  │  │
                     │  └────────────────────────────────────────────┘  │
                     │                                                  │
                     │  ┌────────────────────────────────────────────┐  │
                     │  │  Hermes Agent (Docker, bridge)              │  │
                     │  │  Gateway API :8642   Dashboard :9119        │  │
                     │  │  Provider: OMLX (Mac 192.168.31.117:8000)  │  │
                     │  └────────────────────────────────────────────┘  │
                     └──────────────────────────────────────────────────┘
```

**Rede:** Todos os serviços críticos (Pi-hole, Prometheus, Node Exporter) usam `network_mode: host`. Grafana usa bridge com porta publicada (`:3000`). O exporter do Pi-hole é um systemd service (não container) porque precisa de acesso direto a `localhost:80`. Hermes Agent usa bridge com portas publicadas (`:8642` API, `:9119` dashboard).

**ZeroTier:** Já configurado no Pi. IP: `172.24.39.82`.

---

## 4. Docker Compose

O arquivo único está em `/home/hermes-pi/docker-compose-services.yml`.

### Deploy inicial (já rodou no setup)

```bash
sudo docker compose -f ~/docker-compose-services.yml up -d
```

### Comandos do dia a dia

```bash
# Ver status
sudo docker ps

# Logs em tempo real
sudo docker compose -f ~/docker-compose-services.yml logs -f -t

# Logs de um serviço específico
sudo docker compose -f ~/docker-compose-services.yml logs -f pihole

# Parar tudo
sudo docker compose -f ~/docker-compose-services.yml down

# Atualizar imagens
sudo docker compose -f ~/docker-compose-services.yml pull
sudo docker compose -f ~/docker-compose-services.yml up -d

# Quanto de recurso os containers estão usando
sudo docker stats
```

### Comandos específicos do Pi-hole

```bash
# Ver senha admin (se perdeu)
sudo docker exec pihole pihole -a -p

# Estatísticas rápidas
sudo docker exec pihole pihole -c -j | jq

# Logs do DNS
sudo docker logs -f pihole

# Atualizar Gravity (lists de bloqueio)
sudo docker exec pihole pihole updateGravity

# Ver queries em tempo real
sudo docker exec pihole pihole -t
```

### Comandos do Hermes Agent

```bash
# Logs do gateway
docker compose -f ~/docker-compose-services.yml logs -f hermes

# Logs do dashboard
docker compose -f ~/docker-compose-services.yml logs -f hermes-dashboard

# Reiniciar gateway (ex: depois de alterar config.yaml)
docker compose -f ~/docker-compose-services.yml restart hermes

# Testar API
source ~/docker-compose-services.env   # carrega HERMES_API_KEY
curl http://localhost:8642/v1/models \
  -H "Authorization: Bearer $HERMES_API_KEY"

# Chat via Hermes (roteia pro OMLX no Mac)
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

### Comandos do Exporter (systemd)

```bash
# Status
sudo systemctl status pihole-exporter

# Logs
sudo journalctl -u pihole-exporter -n 50 --no-pager

# Reiniciar
sudo systemctl restart pihole-exporter

# Ver métricas
curl -s localhost:9607/metrics
```

---

## 5. Firewall (UFW)

### Regras atualmente aplicadas

```
Porta      Protocolo   Serviço           Origem
──────     ────────   ────────────────   ─────────────────────
22/tcp     TCP        SSH               0.0.0.0/0 (qualquer)
53/udp     UDP        Pi-hole DNS       192.168.31.0/24 (LAN)
53/tcp     TCP        Pi-hole DNS TCP   192.168.31.0/24 (LAN)
80/tcp     TCP        Pi-hole admin     192.168.31.0/24 (LAN)
3000/tcp   TCP        Grafana           192.168.31.0/24 (LAN)
9090/tcp   TCP        Prometheus        192.168.31.0/24 (LAN)
9100/tcp   TCP        Node Exporter     192.168.31.0/24 (LAN)
9607/tcp   TCP        Pi-hole Exporter  192.168.31.0/24 (LAN)
8642/tcp   TCP        Hermes API        192.168.31.0/24 (LAN)
9119/tcp   TCP        Hermes Dashboard  192.168.31.0/24 (LAN)
```

> **Nota importante:** Containers Docker com `ports:` publicadas (Grafana :3000, e também Prometheus/Node Exporter via host network) escrevem regras direto no iptables, **ignorando UFW**. As regras UFW para essas portas são principalmente documentais. Na prática, UFW controla efetivamente: SSH (22), Pi-hole DNS (53/udp, 53/tcp), Pi-hole admin (80) e Pi-hole Exporter (9607).

### ⚠️ Exposição externa — regra de segurança

| Método | Segurança | Recomendação |
|--------|-----------|-------------|
| **Tailscale** | Alta | ✅ **Recomendado.** Nenhuma porta exposta, acesso via rede privada mesh |
| **Cloudflare Tunnel** | Alta | ✅ Alternativa. Túnel sem abrir portas |
| **SSH tunnel** | Média | ⚠️ Pra acesso temporário: `ssh -L 3000:localhost:3000 hermes-pi@192.168.31.246` |
| **Port forwarding no roteador** | **Baixa** | ❌ **NUNCA.** Expõe os serviços pro mundo inteiro |

**Ações recomendadas:**

- [ ] Instalar Tailscale no Pi: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`
- [ ] Depois de configurar Tailscale, remover regras UFW de portas não essenciais (manter só SSH + DNS)
- [ ] Trocar senha do Grafana e Pi-hole de `admin` pra algo seguro

---

## 6. Workflow diário

### Rotina de manutenção

**Semanal:**
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Atualizar containers
sudo docker compose -f ~/docker-compose-services.yml pull
sudo docker compose -f ~/docker-compose-services.yml up -d

# Limpar imagens antigas
sudo docker image prune -f

# Atualizar listas de bloqueio do Pi-hole
sudo docker exec pihole pihole updateGravity
```

**Mensal:**
```bash
# Backup dos volumes Docker
BACKUP_DIR=~/backups/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

sudo docker run --rm -v prometheus-data:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/prometheus.tar.gz -C /data .

sudo docker run --rm -v grafana-data:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/grafana.tar.gz -C /data .

sudo docker run --rm -v etc-pihole:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/pihole.tar.gz -C /data .

cd ~/backups
ls -t | tail -n +8 | xargs rm -rf   # keep last 7 backups
```

---

## 7. Credenciais

| Serviço | URL | Usuário | Senha |
|---------|-----|---------|-------|
| Pi-hole admin | `http://192.168.31.246:80/admin` | — | `$PIHOLE_PASSWORD` |
| Pi-hole Exporter | `127.0.0.1:9607/metrics` (localhost only) | — | — |
| Grafana | `http://127.0.0.1:3000` (SSH tunnel) | `admin` | `$GRAFANA_PASSWORD` |
| Prometheus | `http://127.0.0.1:9090` (local) | — | — |
| Pi SSH | `ssh hermes-pi@192.168.31.246` | `hermes-pi` | chave SSH (sem senha) |
| Hermes API | `127.0.0.1:8642/v1` (SSH tunnel) | API Key | `$HERMES_API_KEY` |
| Hermes Dashboard | `:9119` | — | Web UI (token incluso na página) |

> Mude as senhas depois do primeiro acesso. Veja seção 5 sobre exposição externa.

---

## 8. Próximos passos (sugestões)

- [ ] **Trocar senhas** (Pi-hole, Grafana) de `admin` para algo seguro
- [ ] **Importar dashboard Grafana 11107** (Pi-hole metrics) e verificar
- [ ] **Colocar chave real do OpenRouter** no `~/.hermes/.env` (fallback)
- [ ] **Adicionar Alertmanager** pro Prometheus mandar alerts (Discord)
- [ ] **Automação GitHub Actions** — deploy no Pi via SSH
- [ ] **Backup automatizado** via cron (script já tem)
- [ ] **Configurar roteador** pra distribuir o Pi como DNS via DHCP
- [ ] **Usar opencode** pra gerar scripts — veja `03 - Resources/Prompts para opencode.md`

---

## 9. Handover detalhado

Para detalhes técnicos completos sobre o pipeline do Pi-hole v6 (problemas enfrentados, decisões arquiteturais, troubleshooting), veja:

➡️ [[03 - Resources/Monitoring Pi-hole v6 — Handover]]
