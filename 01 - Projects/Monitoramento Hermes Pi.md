# Monitoramento Hermes Pi

> **Status:** ✅ Concluído
> **Início:** 2026-05-23
> **Término:** 2026-05-23
> **Hermes Agent:** ✅ Rodando

---

## Objetivo

Configurar pipeline completo de monitoramento no Raspberry Pi (hermes-pi): Prometheus + Grafana + Node Exporter + Pi-hole v6 com exporter customizado.

---

## Checklist

### Feito

- [x] Setup inicial do Pi (Docker, Node.js, opencode)
- [x] Node Exporter rodando em host network (porta 9100)
- [x] Prometheus rodando em host network (porta 9090)
- [x] Grafana rodando com volume persistente (porta 3000)
- [x] Pi-hole v6 em host network (portas 53/80)
- [x] Exporter Python para Pi-hole v6 como systemd service (porta 9607)
- [x] UFW configurado com SSH, DNS, admin, exporter liberados na LAN
- [x] Docker Compose file versionado no vault
- [x] Script `setup_rpi.sh` versionado no vault
- [x] Handover documentado em `03 - Resources/Monitoring Pi-hole v6 — Handover`
- [x] Guia pós-setup atualizado
- [x] Hermes Agent configurado (gateway + dashboard)
- [x] Provider: OMLX no Mac (`192.168.31.117:8000`, Qwen2.5-Coder-7B)
- [x] Fallback: OpenRouter configurado (placeholder)
- [x] Dashboard web UI rodando (porta 9119)
- [x] API key: `$HERMES_API_KEY` (em `.env`, ver SECURITY-CHECKLIST.md)
- [x] ZeroTier IP do Pi: `172.24.39.82`

### Pendente

- [ ] Importar dashboard Grafana 1860 (Node Exporter)
- [ ] Importar dashboard Grafana 11107 (Pi-hole)
- [ ] Trocar senhas padrão (`admin`)
- [ ] Colocar chave real do OpenRouter no `.env`
- [ ] Backup automático via cron

---

## Arquivos do Projeto

| Arquivo | Descrição |
|---------|-----------|
| `setup_rpi.sh` | Script de setup completo do Pi |
| `pihole_exporter.py` | Exporter Python para Pi-hole v6 |
| `03 - Resources/docker-compose-services.yml` | Docker Compose da infra |
| `03 - Resources/Hermes Pi — Pós-Setup e Workflow.md` | Guia pós-setup |
| `03 - Resources/Monitoring Pi-hole v6 — Handover.md` | Handover técnico detalhado |

---

## Referências

- [[03 - Resources/Hermes Pi — Pós-Setup e Workflow]]
- [[03 - Resources/Monitoring Pi-hole v6 — Handover]]
- [[03 - Resources/Prompts para opencode]]
