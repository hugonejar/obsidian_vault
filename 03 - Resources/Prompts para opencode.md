# Prompts para opencode

> Coleção de prompts prontos pra copiar, colar e rodar no opencode.
> Adapte os nomes, IPs e portas conforme seu setup.

---

## Como usar

```bash
# No Pi, dentro do diretório do projeto
cd ~/docker
opencode
```

Cole o prompt, veja o resultado, revise e aplique.

---

## Infraestrutura

### Docker Compose unificado

> Gera um arquivo `docker-compose.yml` completo para rodar no meu Raspberry Pi (linux/arm64) com os seguintes serviços:
> - **Prometheus** (imagem prom/prometheus, porta 9090, volume prometheus-data)
> - **Grafana** (imagem grafana/grafana, porta 3000, volume grafana-data, senha admin lida de `${GRAFANA_PASSWORD}` no .env)
> - **Node Exporter** (imagem prom/node-exporter, network host, coletando /proc, /sys, /)
> - **Hermes Agent** (imagem nousresearch/hermes-agent:main, porta 8642, volume ./hermes-data)
> Todos na mesma rede `app-network` com restart unless-stopped. Quero variáveis de ambiente num arquivo `.env` separado.

---

### Script de backup dos volumes Docker

> Cria um script bash `backup.sh` que faz backup dos volumes Docker do meu Pi (prometheus-data, grafana-data) para ~/backups. Cada backup deve ter a data no nome do arquivo. Manter apenas os últimos 7 backups (rotacionar). Execução segura com set -euo pipefail. Mostrar progresso e tamanho de cada backup.

---

### Adicionar Alertmanager

> Cria uma configuração completa de Alertmanager + Prometheus no meu docker-compose.yml para o Raspberry Pi. Quero alerts de:
> - CPU > 80% por 5min
> - Disk > 85%
> - Memory > 85%
> - Node exporter down
> Os alerts devem enviar notificação via webhook do Discord. Incluir prometheus.yml com alerting config e alertmanager.yml com roteamento.

---

### Script de health check

> Cria um script `health.sh` que verifica se todos os containers Docker do meu setup (node-exporter, prometheus, grafana) estão rodando. Se algum estiver down, tenta reiniciar e envia uma notificação via Discord webhook. Usar o arquivo .env pra configurar o webhook URL.

---

### Automação GitHub Actions

> Cria um workflow GitHub Actions (.github/workflows/deploy.yml) que:
> 1. Faz SSH no meu Raspberry Pi (192.168.31.246, usuário hermes-pi)
> 2. Faz pull das imagens Docker
> 3. Re-cria os containers com docker compose up -d
> 4. Verifica se tudo subiu corretamente
> Usar secrets do GitHub pra guardar a chave SSH e o host.

---

### Docker stats pra log

> Cria um script `log-stats.sh` que roda a cada 5 minutos via cron, salvando `docker stats --no-stream` num arquivo CSV em ~/monitoring/logs/. Formato: timestamp,cpu%,mem%,mem_usage,net_in,net_out,block_in,block_out. Rotacionar logs com mais de 30 dias.

---

## Segurança

### UFW extra

> Quero adicionar regras no UFW do Pi pra bloquear acesso externo às portas 9090 (Prometheus) e 3000 (Grafana), permitindo apenas da rede local 192.168.0.0/16 e do Tailscale (100.0.0.0/8). Gerar o script bash.

---

### Tailscale setup

> Gera um guia passo a passo pra instalar Tailscale no Raspberry Pi OS (Debian Trixie, arm64), configurar como subnet router e expor os serviços (Grafana :3000, Prometheus :9090) apenas pela rede Tailscale, bloqueando acesso direto pela LAN. Incluir comandos e systemd config se necessário.

---

## opencode

### Automatizar tarefa repetitiva

> **Context:** Act as a Senior Developer and Automation Specialist. I am working on my Raspberry Pi homelab (hermes-pi).
> **Task:** [descreva a tarefa, ex: criar um script que limpa imagens Docker antigas automaticamente]
> **Technical Specifications:**
> * Language/Tools: Bash, Docker CLI
> * Target: Raspberry Pi OS (Debian, arm64)
> **Constraints and Rules:**
> 1. Código com set -euo pipefail
> 2. Logs com timestamp
> 3. Mandar notificação em caso de erro
> **Output Format:**
> * Código funcional dentro de code block
> * Abaixo, bullets breves de como usar

---

### Configurar Hermes Agent

> Preciso configurar o Hermes Agent no meu Raspberry Pi. Me ajuda com:
> 1. docker-compose.yml com hermes-agent:main na porta 8642
> 2. Primeira execução interativa pra setup
> 3. Integrar com opencode: como fazer os dois agentes conversarem
> 4. Expor só via Tailscale (não via IP direto)

---

## Utilitários

### Monitor de temperatura do Pi

> Cria um script `temp.sh` que mostra a temperatura atual da CPU do Raspberry Pi, uso de clock e throttle status. Usar vcgencmd. Formato legível pra humano. Bônus: exportar em JSON pra um endpoint HTTP simples com Python.

---

### Migrar docker run para docker compose

> Tenho containers rodando via `docker run` (node-exporter, prometheus, grafana). Gera o comando `docker compose convert` ou me ajuda a extrair as configs atuais pra um docker-compose.yml sem perder dados. Os volumes são: prometheus-data, grafana-data.

---

> 💡 **Dica:** Quer um prompt diferente? Pega o modelo do `automaton.md`, preenche e joga no opencode.
