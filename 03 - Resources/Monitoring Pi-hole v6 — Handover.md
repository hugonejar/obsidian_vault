# Monitoring Pi-hole v6 — Handover

> Pipeline de métricas do Pi-hole v6 no hermes-pi: arquitetura, decisões, configurações e lições aprendidas.

---

## 1. O Problema

Precisávamos de métricas de DNS (queries totais, bloqueadas, cache, etc.) do Pi-hole no Prometheus + Grafana. Dois obstáculos:

| Obstáculo | Detalhe |
|-----------|---------|
| **Pi-hole v6 API** | Mudou completamente em relação à v5. Não tem mais `/admin/api.php`. A autenticação agora é via `POST /api/auth` que retorna um `sid` (session ID). O exporter pre-built `ekofr/pihole-exporter` não suporta a v6. |
| **Isolamento de rede** | Tentamos macvlan pro Pi-hole ter IP próprio na LAN (`192.168.31.2`) e ficar invisível pros outros containers. Mas containers no host não conseguiam alcançar o IP macvlan. |

---

## 2. Arquitetura Final

```
                    ┌─────────────────────────────────────────────┐
                    │              hermes-pi (RPi 5)               │
                    │           IP: 192.168.31.246                 │
                    │                                              │
                    │  ┌───────────────────┐  ┌─────────────────┐  │
                    │  │  Pi-hole (Docker) │  │  Node Exporter  │  │
                    │  │  host network     │  │  host network   │  │
                    │  │  :53 (DNS)        │  │  :9100/metrics  │  │
                    │  │  :80 (admin)      │  └────────┬────────┘  │
                    │  └────────┬──────────┘           │           │
                    │           │ HTTP API (auth+stats)│           │
                    │           │                      │           │
                    │  ┌────────▼──────────────────────▼────────┐  │
                    │  │     Prometheus (Docker, host network)   │  │
                    │  │     :9090                               │  │
                    │  │     Targets: localhost:9100 (node)      │  │
                    │  │              localhost:9607 (pihole)    │  │
                    │  │              localhost:9090 (self)      │  │
                    │  └───────────────────┬─────────────────────┘  │
                    │                      │                        │
                    │  ┌───────────────────▼─────────────────────┐  │
                    │  │     Grafana (Docker, bridge :3000)       │  │
                    │  │     Data Source: http://localhost:9090    │  │
                    │  └─────────────────────────────────────────┘  │
                    │                                              │
                    │  ┌─────────────────────────────────────────┐  │
                    │  │  Pi-hole Exporter (systemd service)      │  │
                    │  │  /home/hermes-pi/pihole_exporter.py      │  │
                    │  │  :9607/metrics                           │  │
                    │  │  Autentica via POST /api/auth → sid     │  │
                    │  │  Cache métricas por 30s                 │  │
                    │  └─────────────────────────────────────────┘  │
                    └─────────────────────────────────────────────┘
```

### Pipeline de dados

```
Pi-hole API (:80/api)  ──HTTP──>  Python Exporter (:9607)  ──HTTP──>  Prometheus (:9090)  ──SQL──>  Grafana (:3000)
                                        ↑
                                    systemd service
                                  (restart: always)
```

---

## 3. Decisões Arquiteturais

### 3.1 Pi-hole em host network (não macvlan)

| Opção | Resultado |
|-------|-----------|
| **macvlan** (tentativa inicial) | Pi-hole ganhava IP próprio (`192.168.31.2`) mas containers no host (Prometheus) não conseguiam alcançá-lo. O tráfego de containers bridge pra interface macvlan é bloqueado pelo roteamento do kernel. |
| **host network** (solução final) | Pi-hole compartilha o stack de rede do host. Acessível em `localhost:80` de qualquer processo no host. **Tradeoff**: perde o isolamento de rede — Pi-hole enxerga e é enxergado por outros containers. |

**Efeito colateral:** `systemd-resolved` também escuta na porta 53 e conflita com o Pi-hole. Solução: desabilitar `systemd-resolved` e setar `/etc/resolv.conf` manualmente para `1.1.1.1`.

### 3.2 Exporter em Python como systemd (não container Docker)

| Opção | Resultado |
|-------|-----------|
| **ekofr/pihole-exporter** (container) | Funciona apenas com Pi-hole v5. A API v6 mudou o endpoint de auth para `POST /api/auth` com resposta `{session: {sid: ...}}`. O exporter antigo não consegue autenticar. |
| **Python script direto** (systemd) | Script leve de 84 linhas que autentica via `POST /api/auth`, consulta `GET /api/stats/summary`, expõe métricas Prometheus em `:9607`. Vantagem: controle total, sem imagem Docker pra manter. |

**Por que systemd e não Docker?**
- O script precisa alcançar `localhost:80` (Pi-hole em host network). Num container, `localhost` é o próprio container.
- Menos overhead que um container Docker inteiro pra rodar um script Python.
- systemd garante restart em caso de falha (`Restart=always`).

### 3.3 Prometheus em host network (não bridge)

| Opção | Resultado |
|-------|-----------|
| **bridge** com target `192.168.31.246:9607` | O container Prometheus (`172.17.0.x`) envia pacote para o host via docker bridge. O host recebe na `docker0`, mas o UFW bloqueia porque o source IP (`172.17.0.x`) não está na faixa `192.168.31.0/24`. **Timeout.** |
| **bridge** com target `172.17.0.1:9607` | Teoricamente funcionaria, mas o exportador Python não respondia a tempo. |
| **host network** (solução) | Prometheus compartilha o network stack do host. `localhost:9607` funciona direto. **Tradeoff**: perde isolamento de porta (porta 9090 fica exposta direto no host). |

### 3.4 BrokenPipeError no exporter

**Problema:** Prometheus fecha a conexão HTTP antes do exporter terminar de escrever a resposta. O `http.server` do Python lança `BrokenPipeError` e loga traceback feio.

**Solução:** Adicionar `try/except BrokenPipeError` no handler `do_GET`. O erro é inofensivo — Prometheus já recebeu os dados.

---

## 4. Configurações Detalhadas

### 4.1 Docker Compose (`/home/hermes-pi/docker-compose-services.yml`)

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - etc-pihole:/etc/pihole
      - etc-dnsmasq:/etc/dnsmasq.d
    environment:
      TZ: America/Sao_Paulo
      WEBPASSWORD: ${PIHOLE_PASSWORD:?PIHOLE_PASSWORD must be set in .env}
      PIHOLE_DNS_: 1.1.1.1;8.8.8.8
      DNSSEC: "true"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --path.rootfs=/rootfs

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    network_mode: host
    volumes:
      - /home/hermes-pi/monitoring/prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.listen-address=0.0.0.0:9090

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:?GRAFANA_PASSWORD must be set in .env}
      GF_INSTALL_PLUGINS: grafana-piechart-panel

volumes:
  etc-pihole:
  etc-dnsmasq:
  prometheus-data:
  grafana-data:
```

### 4.2 Prometheus Config (`/home/hermes-pi/monitoring/prometheus/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ["localhost:9100"]
        labels:
          host: "hermes-pi"

  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: pihole
    static_configs:
      - targets: ["localhost:9607"]
        labels:
          host: "hermes-pi"
```

### 4.3 Systemd Service (`/etc/systemd/system/pihole-exporter.service`)

```ini
[Unit]
Description=Pi-hole v6 Prometheus Exporter
After=network.target docker.service
Wants=docker.service

[Service]
ExecStart=/usr/bin/python3 /home/hermes-pi/pihole_exporter.py
WorkingDirectory=/home/hermes-pi
User=hermes-pi
Restart=always
RestartSec=10
Environment=PIHOLE_URL=http://localhost
EnvironmentFile=/etc/pihole-exporter.env    # PIHOLE_PASSWORD=... (chmod 600, root:root)
Environment=PORT=9607

[Install]
WantedBy=multi-user.target
```

### 4.4 Exporter Script (`/home/hermes-pi/pihole_exporter.py`)

- **Path no Pi:** `/home/hermes-pi/pihole_exporter.py`
- **Path no vault:** `/Users/hugonlopes/code/obsidian_vault/pihole_exporter.py`
- **Porta:** 9607
- **Cache:** métricas cacheadas por 30s (evita flood na API do Pi-hole)
- **Autenticação v6:** `POST /api/auth` com `{"password": "admin"}` → extrai `session.sid` → usa `sid` no header das requests seguintes
- **Endpoint consultado:** `GET /api/stats/summary`
- **Métricas expostas:** `pihole_queries_total`, `pihole_queries_blocked`, `pihole_queries_percent_blocked`, `pihole_queries_cached`, `pihole_queries_forwarded`, `pihole_queries_unique_domains`, `pihole_clients_active`, `pihole_gravity_domains`

### 4.5 UFW Rules

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
```

> **Nota:** As portas 3000, 9090, 9100 são publicadas por containers Docker e **passam direto no iptables**, ignorando UFW. As regras acima são principalmente para documentação — na prática, só 22, 53, 80 e 9607 são efetivamente controladas pelo UFW (são serviços no host).

---

## 5. Comandos de Manutenção

### Containers

```bash
# Ver status
sudo docker ps

# Logs de cada serviço
sudo docker logs prometheus --tail 50
sudo docker logs pihole --tail 50
sudo docker logs grafana --tail 50
sudo docker logs node-exporter --tail 50

# Parar tudo (exceto pihole-exporter, que é systemd)
sudo docker compose -f ~/docker-compose-services.yml down

# Subir tudo
sudo docker compose -f ~/docker-compose-services.yml up -d

# Atualizar imagens
sudo docker compose -f ~/docker-compose-services.yml pull
sudo docker compose -f ~/docker-compose-services.yml up -d
```

### Exporter (systemd)

```bash
# Ver status
sudo systemctl status pihole-exporter

# Logs
sudo journalctl -u pihole-exporter -n 50 --no-pager

# Reiniciar
sudo systemctl restart pihole-exporter

# Ver métricas ao vivo
curl -s localhost:9607/metrics
```

### Firewall

```bash
# Ver regras
sudo ufw status numbered

# Adicionar regra (exemplo: liberar Tailscale)
sudo ufw allow from 100.64.0.0/10 to any port 3000 proto tcp comment 'Grafana via Tailscale'

# Remover regra (usar o número do `status numbered`)
sudo ufw delete 5

# Desabilitar (emergência)
sudo ufw disable
```

---

## 6. Troubleshooting

| Sintoma | Causa | Solução |
|---------|-------|---------|
| Prometheus mostra `pihole: down` com `context deadline exceeded` | Exporter lento ou inalcançável | `curl localhost:9607/metrics` no Pi. Se falhar, `sudo systemctl restart pihole-exporter` e `sudo journalctl -u pihole-exporter -n 20` |
| `ERROR: pihole_exporter_error` nas métricas | Exporter não consegue autenticar no Pi-hole | Verificar se `PIHOLE_PASSWORD` no systemd service e no Pi-hole estão sincronizados. Testar: `curl -X POST http://localhost/api/auth -H "Content-Type: application/json" -d '{"password":"admin"}'` |
| Porta 53 já em uso | `systemd-resolved` rodando | `sudo systemctl disable systemd-resolved --now && echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf` |
| SSH trava depois de ativar UFW | UFW ativado sem regra SSH | Conectar físico (monitor+teclado) e rodar `sudo ufw disable`. Depois reaplicar com `sudo ufw allow ssh` ANTES de ativar |
| BrokenPipeError no log do exporter | Prometheus fecha conexão antes do fim da resposta | Inofensivo. O `try/except` no script já trata. Se encher o log, reduzir `scrape_interval` no Prometheus |
| Grafana não conecta no Prometheus | Data source URL errada | Configurar como `http://localhost:9090` (não `http://prometheus:9090` — sem Docker DNS em host network) |

---

## 7. Lições Aprendidas

1. **Pi-hole v6 mudou a API.** Não assuma compatibilidade com ferramentas da v5. Sempre verificar a documentação da API antes de escolher um exporter.
2. **macvlan isola demais.** Containers no host não conseguem alcançar IPs macvlan sem roteamento extra. Prefira host network quando a comunicação com outros processos no host for necessária.
3. **Docker publicado ≠ UFW.** Containers com `ports:` publicadas escrevem regras direto no iptables, pulando o UFW. UFW só controla serviços rodando direto no host (ou containers com `network_mode: host`).
4. **Prometheus em host network simplifica.** Targets viram `localhost` em vez de IPs mágicos. Desvantagem: perde isolamento de rede.
5. **BrokenPipeError no http.server é normal.** Prometheus fecha conexões agressivamente. O handler precisa tratar isso.
6. **Sempre validar SSH antes de ativar UFW.** Adicionar `sudo ufw allow ssh` ANTES de `sudo ufw --force enable`. Se der merda, Precisa de acesso físico.

---

## 8. Próximos Passos

- [ ] **Trocar senhas** (Pi-hole, Grafana) de `admin` para algo seguro
- [ ] **Instalar Tailscale** no Pi e restringir UFW apenas à rede Tailscale
- [ ] **Dashboard Grafana 11107** — importar e verificar métricas de DNS
- [ ] **Alertas** no Prometheus para CPU > 80%, disco > 85%, serviço down
- [ ] **Backup automático** dos volumes Docker via cron

---

## 9. Referências

| Recurso | Localização |
|---------|-------------|
| Script de setup | `/Users/hugonlopes/code/obsidian_vault/setup_rpi.sh` |
| Docker Compose | `/Users/hugonlopes/code/obsidian_vault/03 - Resources/docker-compose-services.yml` |
| Exporter Python | `/Users/hugonlopes/code/obsidian_vault/pihole_exporter.py` |
| Guia pós-setup | `/Users/hugonlopes/code/obsidian_vault/03 - Resources/Hermes Pi — Pós-Setup e Workflow.md` |
| Prompts opencode | `/Users/hugonlopes/code/obsidian_vault/03 - Resources/Prompts para opencode.md` |
| Guia Docker Compose | `/Users/hugonlopes/code/obsidian_vault/03 - Resources/Guia Docker Compose Hermes.md` |
| Template de prompts | `/Users/hugonlopes/code/obsidian_vault/automaton.md` |
