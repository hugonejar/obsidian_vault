# Hermes Pi — Pós-Setup e Workflow

> Guia do que fazer depois de rodar o `setup_rpi.sh` no Raspberry Pi.

---

## 1. Status atual (pós-setup)

O script instalou e configurou:

| Serviço | Porta | Acesso | Status |
|---------|-------|--------|--------|
| Docker Engine | — | `docker ps` | ✅ |
| Node.js 22 | — | `node --version` | ✅ |
| opencode | — | `opencode` | ✅ |
| Node Exporter | 9100 | `/metrics` | ✅ |
| Prometheus | 9090 | Web UI | ✅ |
| Grafana | 3000 | Web UI | ✅ |
| Pi-hole | 53/80 | `http://192.168.31.2/admin` | ✅ |
| Pi-hole Exporter | 9606 | métricas pro Prometheus | ✅ |

---

## 2. Pós-setup imediato (5 min)

### 2.1 Recarregar grupo Docker

O Docker funciona com `sudo` agora. Pra usar sem `sudo`, faça logout e login:

```bash
# Opção A: sair e entrar de novo
exit
ssh hermes-pi@192.168.31.246

# Opção B: recarregar grupo sem logout (substituto)
newgrp docker
```

### 2.2 Verificar containers

```bash
docker ps
# Deve mostrar: node-exporter, prometheus, grafana, pihole, pihole-exporter
```

### 2.3 Adicionar Prometheus como data source no Grafana

1. Browser → http://192.168.31.246:3000
2. Login: **admin** / **admin**
3. ⚙️ Settings → **Data Sources** → **Add data source** → **Prometheus**
4. URL: `http://prometheus:9090`
5. **Save & Test** (deve mostrar verde)

### 2.4 Importar dashboards

**Node Exporter (sistema):**
1. No Grafana: **+** → **Import**
2. Dashboard ID: **1860** (Node Exporter Full)
3. Select **Prometheus** → **Import**

**Pi-hole (DNS):**
1. No Grafana: **+** → **Import**
2. Dashboard ID: **11107** (Pi-hole metrics)
3. Select **Prometheus** → **Import**

Agora você vê CPU, RAM, disco, temperatura **e** queries de DNS bloqueadas em tempo real.

---

## 3. Arquitetura

```
                    ┌───────────────────────────────────────────┐
                    │           192.168.31.0/24 (LAN)           │
                    │                                            │
                    │   ┌──────────────────────────────────┐     │
                    │   │      hermes-pi (RPi 5)            │     │
                    │   │   IP: 192.168.31.246              │     │
                    │   │                                  │     │
                    │   │  ┌──────────────────────────┐   │     │
                    │   │  │  [macvlan: eth0]         │   │     │
                    │   │  │  IP: 192.168.31.2        │   │     │
                    │   │  │                          │   │     │
                    │   │  │  ┌────────────┐          │   │     │
            DNS ────┼───┼──┼──┤   Pi-hole   │          │   │     │
           HTTP ────┼───┼──┼──┤  :53 / :80  │          │   │     │
                    │   │  │  └──────┬─────┘          │   │     │
                    │   │  └─────────┼────────────────┘   │     │
                    │   │            │ HTTP API           │     │
                    │   │  ┌─────────▼────────────────┐   │     │
                    │   │  │  [bridge: app-network]    │   │     │
                    │   │  │                           │   │     │
                    │   │  │  ┌────────────┐   ┌──────┴───┐ │     │
                    │   │  │  │ Pi-hole    │   │ Prometh. │ │     │
                    │   │  │  │ Exporter ──┼──>│ :9090    │ │     │
                    │   │  │  │ :9606      │   │           │ │     │
                    │   │  │  └────────────┘   └───┬───────┘ │     │
                    │   │  │                       │         │     │
                    │   │  │  ┌────────────────┐   │         │     │
                    │   │  │  │ Node Exporter  ─┼───┘         │     │
                    │   │  │  │ :9100           │             │     │
                    │   │  │  └────────────────┘             │     │
                    │   │  │                       ┌─────────▼──┐  │
                    │   │  │                       │  Grafana   │  │
                    │   │  │                       │  :3000     │  │
                    │   │  │                       └────────────┘  │
                    │   │  │                                       │
                    │   │  │  ┌─────────────────────────────┐      │
                    │   │  │  │  opencode  ~/.opencode/bin  │      │
                    │   │  │  └─────────────────────────────┘      │
                    │   │  └───────────────────────────────────────┘
                    └───────────────────────────────────────────┘
```

**Isolamento de rede:** Pi-hole usa macvlan — IP próprio na LAN, não enxerga os outros containers e vice-versa. Pi-hole Exporter consulta a API do Pi-hole via HTTP pelo IP macvlan (`192.168.31.2`).

---

## 4. Docker Compose

### Serviços de infraestrutura (Pi-hole + monitoramento)

```bash
# Transferir compose pro Pi
scp -i ~/.ssh/id_ed25519 \
  ~/code/obsidian_vault/03\ -\ Resources/docker-compose-services.yml \
  hermes-pi@192.168.31.246:~/docker/

# Deploy
ssh hermes-pi@192.168.31.246
cd ~/docker
docker compose -f docker-compose-services.yml up -d
```

### Comandos específicos do Pi-hole

```bash
# Ver senha admin (se perdeu)
docker exec pihole pihole -a -p

# Estatísticas rápidas
docker exec pihole pihole -c -j | jq

# Logs do DNS
docker logs -f pihole

# Atualizar Gravity (lists de bloqueio)
docker exec pihole pihole updateGravity

# Ver queries em tempo real
docker exec pihole pihole -t
```

---

## 5. Firewall (UFW)

### Regras atualmente aplicadas

```
Porta    Protocolo   Serviço        Origem
──────   ────────   ────────────   ─────────────────────
22/tcp   TCP        SSH            0.0.0.0/0
53/udp   UDP        Pi-hole DNS    192.168.31.0/24 (LAN)
53/tcp   TCP        Pi-hole DNS    192.168.31.0/24 (LAN)
80/tcp   TCP        Pi-hole admin  192.168.31.0/24 (LAN)
3000/tcp TCP        Grafana        192.168.31.0/24 (LAN)
9090/tcp TCP        Prometheus     192.168.31.0/24 (LAN)
9100/tcp TCP        Node Exporter  192.168.31.0/24 (LAN)
9606/tcp TCP        Pi-hole Exp.   192.168.31.0/24 (LAN)
```

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

### Comandos essenciais

```bash
# Ver status de tudo
docker ps

# Ver logs em tempo real (todos containers)
docker compose -f ~/docker/docker-compose-services.yml logs -f -t

# Ver logs de um serviço específico
docker compose -f ~/docker/docker-compose-services.yml logs -f pihole

# Parar tudo
docker compose -f ~/docker/docker-compose-services.yml down

# Atualizar todas as imagens
docker compose -f ~/docker/docker-compose-services.yml pull
docker compose -f ~/docker/docker-compose-services.yml up -d

# Quanto de recurso os containers estão usando
docker stats
```

### Rotina de manutenção

**Semanal:**
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Atualizar containers
docker compose -f ~/docker/docker-compose-services.yml pull
docker compose -f ~/docker/docker-compose-services.yml up -d

# Limpar imagens antigas
docker image prune -f

# Atualizar listas de bloqueio do Pi-hole
docker exec pihole pihole updateGravity
```

**Mensal:**
```bash
# Backup dos volumes Docker
BACKUP_DIR=~/backups/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

docker run --rm -v prometheus-data:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/prometheus.tar.gz -C /data .

docker run --rm -v grafana-data:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/grafana.tar.gz -C /data .

docker run --rm -v etc-pihole:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/pihole.tar.gz -C /data .

cd ~/backups
ls -t | tail -n +8 | xargs rm -rf   # keep last 7 backups
```

---

## 7. Credenciais

| Serviço | URL | Usuário | Senha |
|---------|-----|---------|-------|
| Pi-hole admin | `http://192.168.31.2/admin` | — | `admin` |
| Pi-hole Exporter | `:9606/metrics` | — | `admin` |
| Grafana | `http://192.168.31.246:3000` | `admin` | `admin` |
| Prometheus | `http://192.168.31.246:9090` | — | — |
| Pi SSH | `ssh hermes-pi@192.168.31.246` | `hermes-pi` | (definida no boot) |

> Mude as senhas depois do primeiro acesso. Veja seção 5 sobre exposição externa.

---

## 8. Próximos passos (sugestões)

- [ ] **Instalar Tailscale** no Pi pra acesso externo seguro
- [ ] **Adicionar Alertmanager** pro Prometheus mandar alerts (Discord)
- [ ] **Automação GitHub Actions** — deploy no Pi via SSH
- [ ] **Backup automatizado** via cron (script já tem)
- [ ] **Configurar roteador** pra distribuir `192.168.31.2` como DNS via DHCP
- [ ] **Usar opencode** pra gerar scripts — veja `03 - Resources/Prompts para opencode.md`
