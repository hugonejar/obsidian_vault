# Hermes Pi — Security Remediation Checklist

> Generated 2026-05-23 during security review. Tracks the **manual actions**
> the user must take on remote systems. Local file fixes are already applied
> (see git diff). Cross off each item as you complete it.

---

## 🔴 Critical — do today

### 1. Reset the Discord bot token
- [ ] Open https://discord.com/developers/applications/1500545671508398080/bot
- [ ] Click **Reset Token** (invalidates the old one — the leaked token is now dead)
- [ ] Save the new token to **macOS Keychain**, not a file:
      ```bash
      security add-generic-password -a "$USER" -s discord-hermes-bot -w
      # paste the token when prompted
      ```
- [ ] Verify the old token is dead:
      ```bash
      curl -s -H "Authorization: Bot OLD_TOKEN_HERE" https://discord.com/api/v10/users/@me
      # should return 401 Unauthorized
      ```

### 2. Rotate all service passwords on hermes-pi
SSH in, then:

- [ ] Generate strong secrets:
      ```bash
      openssl rand -hex 32  # one each for PIHOLE_PASSWORD, GRAFANA_PASSWORD, HERMES_API_KEY, OMLX_API_KEY
      ```
- [ ] Create `~/docker-compose-services.env` (chmod 600):
      ```
      PIHOLE_PASSWORD=<generated>
      GRAFANA_PASSWORD=<generated>
      HERMES_API_KEY=<generated>
      OPENROUTER_API_KEY=<real key from openrouter.ai/keys>
      ```
- [ ] `chmod 600 ~/docker-compose-services.env`
- [ ] Update Pi-hole's stored password to match:
      ```bash
      docker exec -it pihole pihole -a -p '<PIHOLE_PASSWORD>'
      ```
- [ ] Update Grafana admin password (or wipe `grafana-data` volume and let it re-init from env).
- [ ] Restart the stack:
      ```bash
      docker compose -f ~/docker-compose-services.yml --env-file ~/docker-compose-services.env up -d
      ```
- [ ] Recreate `/etc/pihole-exporter.env` (chmod 600, root:root) with the new
      `PIHOLE_PASSWORD=...`, then `sudo systemctl restart pihole-exporter`.

### 3. Move OMLX API key out of plaintext (on the Mac)
- [ ] Generate: `OMLX_KEY=$(openssl rand -hex 32)`
- [ ] Store: `security add-generic-password -a "$USER" -s omlx-key -w "$OMLX_KEY"`
- [ ] Update `~/.omlx/settings.json` to use the new key, and **change `host` from
      `0.0.0.0` to `192.168.31.117`** (LAN-bound, not all interfaces).
- [ ] Restart OMLX.

---

## 🟠 High — this week

### 4. Stop exposing services to the LAN
After the new compose file rolls out (already updated locally), services bind
to `127.0.0.1`. Reach them via SSH tunnel:

```bash
# Grafana
ssh -L 3000:127.0.0.1:3000 hermes-pi@192.168.31.246
# then browse http://localhost:3000 on your Mac

# Hermes API
ssh -L 8642:127.0.0.1:8642 hermes-pi@192.168.31.246
```

- [ ] Apply the updated `docker-compose-services.yml` to the Pi:
      ```bash
      scp "03 - Resources/docker-compose-services.yml" hermes-pi:~/
      ssh hermes-pi 'docker compose -f ~/docker-compose-services.yml up -d'
      ```

### 5. Apply hardened pihole_exporter.py
- [ ] `scp pihole_exporter.py hermes-pi:~/`
- [ ] `ssh hermes-pi 'sudo systemctl restart pihole-exporter'`
- [ ] Verify it now binds to `127.0.0.1:9607` only:
      `ssh hermes-pi 'sudo ss -tlnp | grep 9607'`

### 6. Install fail2ban + harden SSH
```bash
ssh hermes-pi
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
# /etc/ssh/sshd_config:
#   PasswordAuthentication no
#   PermitRootLogin no
sudo systemctl restart ssh
```
- [ ] Done

### 7. Pin Docker images (already done in compose; verify on Pi)
- [ ] `docker compose -f ~/docker-compose-services.yml pull` after each git pull
- [ ] No `:latest` anywhere — already replaced with versions.

---

## 🟡 Medium — soon

- [ ] Set up automated backups of Docker volumes (mentioned as pendency in
      handover §9): `restic` to a USB or S3-compatible bucket.
- [ ] Add `DOCKER-USER` iptables rules so UFW actually controls Docker traffic.
- [ ] Front Grafana/Prometheus with a reverse proxy (Caddy) + basic auth, if
      LAN access is needed without SSH tunnels.
- [ ] Run `grep -rE "(token|api[_-]?key|password|secret|sk-or)" --include='*.md'`
      monthly against the vault.

---

## What was already fixed in the repo (no action needed)

- `03 - Resources/env for discord.md` — token redacted, replaced with rotation
  instructions.
- `03 - Resources/docker-compose-services.yml` — `:-admin` fallbacks replaced
  with `:?error`, images pinned, ports bound to 127.0.0.1, dashboard host
  flipped to 127.0.0.1.
- `03 - Resources/.env.example` — template for the new `.env` file.
- `pihole_exporter.py` — no default password, binds to 127.0.0.1.
- `03 - Resources/Hermes Pi — Handover Completo.md` — credentials replaced with
  variable references.
- `03 - Resources/Hermes Pi — Pós-Setup e Workflow.md` — same.
- `03 - Resources/Monitoring Pi-hole v6 — Handover.md` — defaults removed,
  `EnvironmentFile=` directive recommended for systemd.
