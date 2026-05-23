# Hermes Agent + Docker Compose

## Estrutura de arquivos
```
~/docker/
├── docker-compose.yml
├── .env
└── hermes-data/          # Dados persistentes do Hermes
```

## Passo 1: Crie os diretórios no Raspberry Pi
```bash
mkdir -p ~/docker/hermes-data
cd ~/docker
```

## Passo 2: Transfira os arquivos (do Mac para Pi)

No seu Mac, execute:

```bash
# Transfere docker-compose.yml
scp /Users/hugonlopes/code/obsidian_vault/03\ -\ Resources/docker-compose-hermes.yml usuario@IP_DO_RASPBERRY:~/docker/docker-compose.yml

# Transfere .env.example (renomeie depois)
scp /Users/hugonlopes/code/obsidian_vault/03\ -\ Resources/.env.example usuario@IP_DO_RASPBERRY:~/docker/.env
```

**Ou copie e cole o conteúdo diretamente:**

---

## docker-compose.yml
```yaml
services:
  hermes:
    image: nousresearch/hermes-agent:main
    container_name: hermes
    restart: unless-stopped
    volumes:
      - ./hermes-data:/opt/data
    ports:
      - "8642:8642"
    environment:
      - TZ=America/Sao_Paulo
    command: gateway run
    networks:
      - app-network

  # ==============================
  # EXEMPLOS DE OUTROS SERVIÇOS
  # Descomente o que precisar
  # ==============================

  # postgres:
  #   image: postgres:16-alpine
  #   container_name: postgres
  #   restart: unless-stopped
  #   environment:
  #     POSTGRES_USER: admin
  #     POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-sua_senha_segura}
  #     POSTGRES_DB: appdb
  #   volumes:
  #     - postgres-data:/var/lib/postgresql/data
  #   ports:
  #     - "5432:5432"
  #   networks:
  #     - app-network

  # redis:
  #   image: redis:7-alpine
  #   container_name: redis
  #   restart: unless-stopped
  #   command: redis-server --appendonly yes
  #   volumes:
  #     - redis-data:/data
  #   ports:
  #     - "6379:6379"
  #   networks:
  #     - app-network

  # nginx:
  #   image: nginx:alpine
  #   container_name: nginx
  #   restart: unless-stopped
  #   ports:
  #     - "80:80"
  #     - "443:443"
  #   volumes:
  #     - ./nginx/conf.d:/etc/nginx/conf.d
  #     - ./nginx/ssl:/etc/nginx/ssl
  #   networks:
  #     - app-network
  #   depends_on:
  #     - hermes

networks:
  app-network:
    driver: bridge

volumes:
  hermes-data:
  # postgres-data:
  # redis-data:
```

---

## .env.example
```env
# ====================
# HERMES AGENT
# ====================
# Adicione suas API keys aqui ou configure via `hermes setup`
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
# OPENROUTER_API_KEY=sk-or-...

# ====================
# POSTGRES (se usar)
# ====================
# POSTGRES_PASSWORD=sua_senha_segura

# ====================
# OUTRAS VARS
# ====================
TZ=America/Sao_Paulo
```

---

## Primeira execução

**1. Configure o Hermes (modo interativo para criar .env):**
```bash
cd ~/docker
docker run -it --rm \
  -v ./hermes-data:/opt/data \
  nousresearch/hermes-agent:main setup
```

**2. Depois inicie tudo em background:**
```bash
docker compose up -d
```

---

## Comandos úteis

| Ação | Comando |
|------|---------|
| Iniciar tudo | `docker compose up -d` |
| Parar tudo | `docker compose down` |
| Ver logs | `docker compose logs -f` |
| Ver logs só do Hermes | `docker compose logs -f hermes` |
| Reiniciar | `docker compose restart` |
| Atualizar imagens | `docker compose pull && docker compose up -d` |
| Acessar CLI do Hermes | `docker exec -it hermes hermes chat` |
| Status containers | `docker compose ps` |

---

## Acesso ao Hermes dentro de containers

O Hermes consegue controlar o Docker host se você montar o socket:

**⚠️ Apenas se precisar que o Hermes gerencie outros containers:**
```yaml
hermes:
  # ... outras configs ...
  volumes:
    - ./hermes-data:/opt/data
    - /var/run/docker.sock:/var/run/docker.sock  # ADICIONE ESTA LINHA
```

---

## Dicas importantes

1. **Rede compartilhada**: Todos os containers na mesma rede (`app-network`) conseguem se comunicar usando os nomes dos containers como hostname.
   - Do hermes: `ping postgres` (se o postgres estiver rodando)
   - Do postgres: `ping hermes`

2. **Volumes**: Os dados são salvos em volumes Docker ou pastas locais. Faça backup de `./hermes-data/` regularmente.

3. **Segurança**: A porta 8642 não tem autenticação. Não exponha diretamente à internet. Use VPN (Tailscale) ou Nginx com auth básico.

4. **Primeiro uso**: Sempre execute o `hermes setup` primeiro para configurar os provedores de LLM.

---

## Troubleshooting

**Container não sobe?**
```bash
docker compose logs hermes
```

**Imagem não baixa?** Verifique se o Pi é 64-bit:
```bash
uname -m
# Deve ser: aarch64 ou arm64
```

**Permissão Docker?**
```bash
sudo usermod -aG docker $USER
# Faça logout/login depois
```
