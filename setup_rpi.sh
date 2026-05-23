#!/usr/bin/env bash
set -euo pipefail

MUTED='\033[0;2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${MUTED}━━━ ${NC}$1${MUTED} ━━━${NC}"; }

# ──────────────────────────────────────────────
# Detect root: sudo not needed if already root
# ──────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    SUDO=""
    CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
    if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
        CURRENT_USER=$(who am i | awk '{print $1}' 2>/dev/null || echo "hermes-pi")
    fi
else
    SUDO="sudo"
    CURRENT_USER="$USER"
fi

log_info "Running as: $(whoami), target user: ${CURRENT_USER}"

# ──────────────────────────────────────────────
# Step-by-step plan
# ──────────────────────────────────────────────
print_plan() {
    echo ""
    echo -e "${MUTED}══════════════════════════════════════════════${NC}"
    echo -e "${MUTED}  Raspberry Pi Setup — Step-by-Step Plan${NC}"
    echo -e "${MUTED}══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} System update & install prerequisites"
    echo -e "     ${MUTED}apt update/upgrade, curl, git, ufw, htop${NC}"
    echo ""
    echo -e "  ${GREEN}2.${NC} Docker Engine + Compose plugin"
    echo -e "     ${MUTED}via get.docker.com, add user to docker group${NC}"
    echo ""
    echo -e "  ${GREEN}3.${NC} Node.js (v22) + npm"
    echo -e "     ${MUTED}via NodeSource or binary tarball for ARM${NC}"
    echo ""
    echo -e "  ${GREEN}4.${NC} opencode (AI coding agent)"
    echo -e "     ${MUTED}via opencode.ai/install -> ~/.opencode/bin${NC}"
    echo ""
    echo -e "  ${GREEN}5.${NC} Node Exporter (system metrics)"
    echo -e "     ${MUTED}Docker container, port 9100${NC}"
    echo ""
    echo -e "  ${GREEN}6.${NC} Prometheus (metrics collection)"
    echo -e "     ${MUTED}Docker container, port 9090, persistent storage${NC}"
    echo ""
    echo -e "  ${GREEN}7.${NC} Grafana (visualization dashboards)"
    echo -e "     ${MUTED}Docker container, port 3000, persistent storage${NC}"
    echo ""
    if [ "$INSTALL_PIHOLE" = true ]; then
    echo -e "  ${GREEN}8.${NC} Pi-hole DNS ad-blocker"
    echo -e "     ${MUTED}Docker container, macvlan IP 192.168.31.2, DNS :53, admin :80${NC}"
    echo ""
    echo -e "  ${GREEN}9.${NC} Pi-hole Exporter (DNS metrics)"
    echo -e "     ${MUTED}Docker container, port 9606, scraped by Prometheus${NC}"
    echo ""
    echo -e "  ${GREEN}10.${NC} Firewall rules"
    echo -e "     ${MUTED}UFW: allow SSH + DNS + Pi-hole admin + monitoring ports${NC}"
    echo ""
    echo -e "  ${GREEN}11.${NC} Summary — installed versions & next steps"
    else
    echo -e "  ${GREEN}8.${NC} Firewall rules"
    echo -e "     ${MUTED}UFW: allow SSH + monitoring ports (3000, 9090, 9100)${NC}"
    echo ""
    echo -e "  ${GREEN}9.${NC} Summary — installed versions & next steps"
    fi
    echo ""
    echo -e "${MUTED}══════════════════════════════════════════════${NC}"
    echo ""
}

# ──────────────────────────────────────────────
# Confirm before proceeding
# ──────────────────────────────────────────────
confirm() {
    echo -e "${YELLOW}This script will install/update packages and run Docker containers.${NC}"
    read -rp "$(echo -e "${YELLOW}Proceed? [Y/n] ${NC}")" reply
    case "$reply" in
        [nN]|[nN][oO]) echo "Aborted."; exit 0 ;;
        *) ;;
    esac
}

detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        aarch64) echo "arm64" ;;
        armv7l|armv6l) echo "armhf" ;;
        x86_64) echo "amd64" ;;
        *) echo "$arch" ;;
    esac
}

ARCH=$(detect_arch)
PI_NAME=${PI_NAME:-"hermes-pi"}
MONITOR_DIR="${HOME}/monitoring"
INSTALL_PIHOLE=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pihole) INSTALL_PIHOLE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--pihole]"
            echo "  --pihole    Also deploy Pi-hole DNS ad-blocker (macvlan, IP 192.168.31.2)"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ──────────────────────────────────────────────
# 0. Show plan & confirm
# ──────────────────────────────────────────────
print_plan
confirm

# ──────────────────────────────────────────────
# 1. System updates & prerequisites
# ──────────────────────────────────────────────
log_step "1/11 — Updating system packages"
$SUDO apt-get update -qq
$SUDO apt-get upgrade -y -qq
$SUDO apt-get install -y -qq \
    curl wget git \
    ca-certificates \
    gnupg lsb-release \
    ufw htop

# ──────────────────────────────────────────────
# 2. Docker Engine
# ──────────────────────────────────────────────
log_step "2/11 — Installing Docker"
if command -v docker >/dev/null 2>&1; then
    log_info "Docker already installed: $(docker --version)"
else
    curl -fsSL https://get.docker.com | $SUDO sh
    $SUDO usermod -aG docker "$CURRENT_USER"
    log_info "Docker installed — user '${CURRENT_USER}' added to docker group."
    log_info "Login required for group to take effect: su - ${CURRENT_USER}"
fi

# ──────────────────────────────────────────────
# 3. Node.js
# ──────────────────────────────────────────────
log_step "3/11 — Installing Node.js"
if command -v node >/dev/null 2>&1; then
    log_info "Node already installed: $(node --version)"
else
    NODE_MAJOR=${NODE_MAJOR:-22}
    log_info "Installing Node.js ${NODE_MAJOR}..."
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "amd64" ]; then
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | $SUDO -E bash -
        $SUDO apt-get install -y nodejs
    else
        log_warn "NodeSource may not support ${ARCH}. Using binary tarball."
        NODE_VERSION="22.14.0"
        case "$ARCH" in
            armhf)  NODE_ARCH="armv7l" ;;
            arm64)  NODE_ARCH="arm64" ;;
            amd64)  NODE_ARCH="x64" ;;
        esac
        curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
            | $SUDO tar -xJ -C /usr/local --strip-components=1
    fi
    log_info "Node: $(node --version)  npm: $(npm --version)"
fi

# ──────────────────────────────────────────────
# 4. opencode
# ──────────────────────────────────────────────
log_step "4/11 — Installing opencode"
if command -v opencode >/dev/null 2>&1; then
    log_info "opencode already installed: $(opencode --version)"
else
    curl -fsSL https://opencode.ai/install | bash
    log_info "opencode installed to ~/.opencode/bin"
    log_info "Add to PATH: export PATH=\$HOME/.opencode/bin:\$PATH"
fi

# ──────────────────────────────────────────────
# 5. Node Exporter (system metrics for Prometheus)
# ──────────────────────────────────────────────
STEP=5
log_step "5/11 — Deploying Node Exporter"
if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^node-exporter$'; then
    log_info "Node Exporter already running"
else
    $SUDO docker run -d \
        --name node-exporter \
        --restart unless-stopped \
        --network host \
        --pid host \
        -v /proc:/host/proc:ro \
        -v /sys:/host/sys:ro \
        -v /:/rootfs:ro \
        prom/node-exporter:latest \
        --path.procfs=/host/proc \
        --path.sysfs=/host/sys \
        --path.rootfs=/rootfs
    log_info "Node Exporter started on port 9100"
fi

# ──────────────────────────────────────────────
# 6. Prometheus
# ──────────────────────────────────────────────
log_step "6/11 — Deploying Prometheus"
mkdir -p "${MONITOR_DIR}/prometheus"

cat > "${MONITOR_DIR}/prometheus/prometheus.yml" <<PROMEOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          host: '${PI_NAME}'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
PROMEOF

if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^prometheus$'; then
    log_info "Prometheus already running"
else
    $SUDO docker run -d \
        --name prometheus \
        --restart unless-stopped \
        -p 9090:9090 \
        -v "${MONITOR_DIR}/prometheus:/etc/prometheus" \
        -v prometheus-data:/prometheus \
        prom/prometheus:latest
    log_info "Prometheus started on port 9090"
fi

# ──────────────────────────────────────────────
# 7. Grafana
# ──────────────────────────────────────────────
log_step "7/11 — Deploying Grafana"
if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^grafana$'; then
    log_info "Grafana already running"
else
    $SUDO docker run -d \
        --name grafana \
        --restart unless-stopped \
        -p 3000:3000 \
        -v grafana-data:/var/lib/grafana \
        -e "GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}" \
        -e "GF_INSTALL_PLUGINS=grafana-piechart-panel" \
        grafana/grafana:latest
    log_info "Grafana started on port 3000 (admin / ${GRAFANA_PASSWORD:-admin})"
fi

# ──────────────────────────────────────────────
# 8. Pi-hole + Exporter (optional)
# ──────────────────────────────────────────────
if [ "$INSTALL_PIHOLE" = true ]; then
log_step "8/11 — Deploying Pi-hole DNS ad-blocker"
if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^pihole$'; then
    log_info "Pi-hole already running"
else
    # systemd-resolved conflicts on port 53, disable it
    $SUDO systemctl disable systemd-resolved --now 2>/dev/null || true
    echo "nameserver 1.1.1.1" | $SUDO tee /etc/resolv.conf >/dev/null

    $SUDO docker run -d \
        --name pihole \
        --restart unless-stopped \
        --network host \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        -v etc-pihole:/etc/pihole \
        -v etc-dnsmasq:/etc/dnsmasq.d \
        -e TZ=America/Sao_Paulo \
        -e WEBPASSWORD="${PIHOLE_PASSWORD:-admin}" \
        -e PIHOLE_DNS_="1.1.1.1;8.8.8.8" \
        -e DNSSEC="true" \
        pihole/pihole:latest
    log_info "Pi-hole started — admin: http://$(hostname -I | awk '{print $1}'):80/admin (${PIHOLE_PASSWORD:-admin})"
fi

log_step "9/11 — Deploying Pi-hole Exporter"
if systemctl is-active --quiet pihole-exporter 2>/dev/null; then
    log_info "Pi-hole Exporter already running"
else
    # Scrape Pi-hole v6 API and expose Prometheus metrics on port 9607
    $SUDO tee /etc/systemd/system/pihole-exporter.service > /dev/null << \SERVICEEOF
[Unit]
Description=Pi-hole v6 Prometheus Exporter
After=network.target docker.service
Wants=docker.service

[Service]
ExecStart=/usr/bin/python3 /opt/pihole_exporter.py
WorkingDirectory=/opt
User=nobody
Restart=always
RestartSec=10
Environment=PIHOLE_URL=http://localhost
Environment=PIHOLE_PASSWORD=admin
Environment=PORT=9607

[Install]
WantedBy=multi-user.target
SERVICEEOF

    # Copy exporter script to /opt
    cp "$(dirname "$0")/pihole_exporter.py" /opt/pihole_exporter.py 2>/dev/null || \
        $SUDO tee /opt/pihole_exporter.py > /dev/null < /dev/null

    $SUDO systemctl daemon-reload
    $SUDO systemctl enable --now pihole-exporter
    log_info "Pi-hole Exporter started on port 9607 (systemd service)"
fi
fi

# ──────────────────────────────────────────────
# 10. Firewall
# ──────────────────────────────────────────────
log_step "10/11 — Configuring UFW firewall"
if command -v ufw >/dev/null 2>&1; then
    $SUDO ufw --force reset >/dev/null 2>&1 || true
    $SUDO ufw default deny incoming >/dev/null
    $SUDO ufw default allow outgoing >/dev/null
    $SUDO ufw allow ssh >/dev/null
    $SUDO ufw allow 3000/tcp comment 'Grafana' >/dev/null
    $SUDO ufw allow 9090/tcp comment 'Prometheus' >/dev/null
    $SUDO ufw allow 9100/tcp comment 'Node Exporter' >/dev/null
    if [ "$INSTALL_PIHOLE" = true ]; then
        $SUDO ufw allow from 192.168.31.0/24 to any port 53 proto udp comment 'Pi-hole DNS' >/dev/null
        $SUDO ufw allow from 192.168.31.0/24 to any port 53 proto tcp comment 'Pi-hole DNS TCP' >/dev/null
        $SUDO ufw allow from 192.168.31.0/24 to any port 80 proto tcp comment 'Pi-hole admin' >/dev/null
        $SUDO ufw allow from 192.168.31.0/24 to any port 9607 proto tcp comment 'Pi-hole Exporter' >/dev/null
    fi
    $SUDO ufw --force enable >/dev/null
    PIHOLE_EXTRA=""
    if [ "$INSTALL_PIHOLE" = true ]; then
        PIHOLE_EXTRA=", Pi-hole DNS (53), Pi-hole admin (80), Pi-hole Exporter (9607)"
    fi
    log_info "UFW enabled — allowed: SSH (22), Grafana (3000), Prometheus (9090), Node Exporter (9100)${PIHOLE_EXTRA}"
fi

# ──────────────────────────────────────────────
# 11. Summary
# ──────────────────────────────────────────────
log_step "11/11 — Setup complete!"
echo ""
echo -e "  ${GREEN}✓${NC} Docker        $($SUDO docker --version 2>/dev/null || echo 'failed')"
echo -e "  ${GREEN}✓${NC} Docker Compose $($SUDO docker compose version 2>/dev/null || echo 'failed')"
echo -e "  ${GREEN}✓${NC} Node.js       $(node --version 2>/dev/null || echo 'failed')"
echo -e "  ${GREEN}✓${NC} npm           $(npm --version 2>/dev/null || echo 'failed')"
echo -e "  ${GREEN}✓${NC} opencode      $(opencode --version 2>/dev/null || echo 'add ~/.opencode/bin to PATH')"
echo ""
echo -e "  ${MUTED}Running containers:${NC}"
$SUDO docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "  (docker login required — run: su - ${CURRENT_USER})"
echo ""
echo -e "  ${MUTED}Access points:${NC}"
echo -e "    Grafana:     http://$(hostname -I 2>/dev/null | awk '{print $1}'):3000  (admin / ${GRAFANA_PASSWORD:-admin})"
echo -e "    Prometheus:  http://$(hostname -I 2>/dev/null | awk '{print $1}'):9090"
echo -e "    Node Exp:    http://$(hostname -I 2>/dev/null | awk '{print $1}'):9100/metrics"
if [ "$INSTALL_PIHOLE" = true ]; then
echo -e "    Pi-hole:     http://$(hostname -I 2>/dev/null | awk '{print $1}'):80/admin  (${PIHOLE_PASSWORD:-admin})"
echo -e "    Pi-hole Exp: http://$(hostname -I 2>/dev/null | awk '{print $1}'):9606/metrics"
fi
echo ""
echo -e "  ${MUTED}Next steps:${NC}"
echo -e "    1. Log out/in:  su - ${CURRENT_USER}"
echo -e "    2. Grafana → Data Sources → Add → Prometheus → http://prometheus:9090"
echo -e "    3. Import dashboard ID 1860 (Node Exporter Full)"
if [ "$INSTALL_PIHOLE" = true ]; then
echo -e "    4. Import dashboard ID 11107 (Pi-hole metrics)"
echo -e "    5. Configurar roteador pra DNS 192.168.31.2 via DHCP (opcional)"
fi
echo ""
echo -e "  ${MUTED}Containers auto-restart on boot (unless-stopped).${NC}"
echo ""
