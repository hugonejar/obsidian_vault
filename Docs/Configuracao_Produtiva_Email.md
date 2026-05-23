# Guia de Configuração Produtiva de Email
## Outlook + Thunderbird — Inbox Zero e Máxima Organização

---

## 1. Filosofia: A Estrutura Antes da Configuração

Antes de qualquer configuração técnica, defina sua **estrutura mental** de organização:

### O Sistema "4 Pastas" (Inbox Zero)

```
INBOX                       ← tudo chega aqui (caixa única de processamento)
├── @Action Required        ← emails que exigem SUA ação
├── @Waiting On             ← emails que aguardam resposta de outros
├── @Someday / Maybe        ← emails para ler/avaliar depois
└── @Archive                ← TUDO que já foi processado (sem subpastas)
```

**Regra de Ouro**: A Inbox só tem emails NÃO processados. Uma vez processado, vai para @Archive ou outra pasta.

> Nota: O prefixo `@` faz as pastas aparecerem no topo da lista (ordem alfabética).

### Alternativa: Sistema por Projetos (se você gerencia múltiplos projetos)

```
INBOX
├── Projeto-Alpha
├── Projeto-Beta
├── @Action Required
├── @Waiting On
├── @Reference (documentação, relatórios)
└── @Archive
```

**Escolha UM sistema e seja consistente.** Recomendo o sistema de 4 pastas por ser mais simples.

---

## 2. Outlook — Passo a Passo Completo

### 2.1. Configuração Visual da Interface

1. **Painel de Leitura à Direita**
   - `Ver > Painel de Leitura > Direita`
   - `Ver > Painel de Leitura > Opções`: marque "Marcar item como lido após 5 segundos" (ou 3)

2. **Ocultar o Preview de 1 linha**
   - `Ver > Pré-visualização de Mensagem > Desligado`

3. **Barra de Pastas compacta? NÃO**
   - `Ver > Painel de Pastas > Normal` (Não use "Compacto" — a barra completa mostra mais informação)

4. **Colunas da Lista de Emails**
   - Clique com direito na barra de colunas > `Adicionar Colunas`
   - Adicione na ordem:
     1. **Importância** (prioridade)
     2. **Sinalizador** (flag de acompanhamento)
     3. **Categorias** (cor)
     4. **Anexos** (clip)
     5. **De** (remetente)
     6. **Assunto**
     7. **Recebido** (data)

5. **Agrupar por Conversa**
   - `Ver > Mostrar como Conversas` → ativado
   - Isso agrupa emails do mesmo assunto — essencial para não poluir a caixa

6. **Condicionamento de Formatação**
   - `Ver > Configurações da Exibição > Formatação Condicional`
   - Adicione estas regras (adicione uma de cada vez):

   **Regra 1: Chefia / Diretoria**
   - Nome: `Chefia`
   - Fonte: Vermelho escuro, **Negrito**
   - Condição: `De` contém `@diretoria` OU `De` contém `NomeDoChefe`

   **Regra 2: Clientes VIP**
   - Nome: `Clientes VIP`
   - Fonte: Laranja, **Negrito**
   - Condição: `De` contém `@cliente-x` OU `Categoria` = `Cliente VIP`

   **Regra 3: Vencimento Hoje**
   - Nome: `Prazo Hoje`
   - Fonte: Vermelho, Itálico, Tachado (NÃO — use fundo amarelo)
   - Fundo: Amarelo claro
   - Condição: `Data de término` = `Hoje`

   **Regra 4: Eu em Cc**
   - Nome: `Cópia (Cc)`
   - Fonte: Cinza claro
   - Condição: `Meu nome` está em `Cc`

### 2.2. Categorias (Use CORES, não pastas)

Categorias são superiores a pastas porque um email pode ter MÚLTIPLAS categorias.

1. `Página Inicial > Categorizar > Todas as Categorias`
2. Renomeie e atribua atalhos de teclado:

| Cor | Nome | Atalho | Uso |
|-----|------|--------|-----|
| 🔴 Vermelho | Urgente | Ctrl+F2 | Emails que exigem ação IMEDIATA (prazo < 4h) |
| 🟠 Laranja | Cliente | Ctrl+F3 | Emails de clientes externos |
| 🟡 Amarelo | Acompanhar | Ctrl+F4 | Emails que você precisa monitorar |
| 🟢 Verde | Financeiro | Ctrl+F5 | Notas fiscais, orçamentos, cobranças |
| 🔵 Azul | Projeto X | Ctrl+F6 | Emails do projeto específico |
| 🟣 Roxo | Pessoal | Ctrl+F7 | Emails pessoais no meio do trabalho |
| ⚪ Cinza | Leitura | Ctrl+F8 | Newsletters, artigos para ler depois |

3. **Atalho para aplicar categoria**: Selecione o email e pressione `Ctrl+F{2-8}`

### 2.3. Regras Automáticas (Correção de Fluxo)

`Arquivo > Gerenciar Regras e Alertas > Nova Regra`

**Regra 1: Newsletters e Marketing → Categoria "Leitura"**
- Condição: `De` contém `newsletter@` OU `unsubscribe` está no corpo
- Ação: Mover para pasta `@Someday / Maybe`, Categorizar como `Cinza - Leitura`, Marcar como lido
- Exceção: Se `Importância` = `Alta`

**Regra 2: Faturas → Categoria "Financeiro"**
- Condição: Assunto contém `fatura` OU `nota fiscal` OU `boleto` OU `NFS-e`
- Ação: Categorizar como `Verde - Financeiro`, Sinalizar para acompanhamento

**Regra 3: Emails com Anexo**
- Condição: `Tem anexos`
- Ação: Sinalizar para acompanhamento, Categorizar como `Amarelo - Acompanhar`

**Regra 4: Cc Inteligente**
- Condição: `Meu nome` está em `Cc` (não em Para)
- Ação: Categorizar como `Cinza - Leitura`, parar processamento de mais regras

**Regra 5: Chefia/Diretoria**
- Condição: `De` contém `@diretoria` ou lista de nomes
- Ação: Sinalizar como importância Alta, Categorizar como `Vermelho - Urgente`

### 2.4. Respostas Rápidas (Textos Prontos)

`Página Inicial > Respostas Rápidas > Novo`

Crie modelos para situações recorrentes:

1. **"Recebi, vou avaliar"**
```
Recebi, [Nome].
Vou avaliar e te retorno até [DATA/HORA].
Abs,
```

2. **"Aguardando terceiros"**
```
Oi [Nome],
Estou aguardando o feedback de [Pessoa/Área] para dar sequência.
Assim que tiver novidades, aviso.
Abs,
```

3. **"Já encaminhei"**
```
Oi [Nome],
Já encaminhei para [Pessoa] cuidar disso.
Se não tiver retorno em [PRAZO], me avise que dou um follow-up.
Abs,
```

### 2.5. Caixa de Entrada Focada (Focused Inbox)

`Ver > Mostrar Caixa de Entrada Focada` (ativar)

O Outlook aprende com o tempo. Para acelerar:
- Clique com direito em emails → `Mover para Caixa de Entrada Focada` ou `Outros`
- Treine por 1-2 semanas e ela ficará precisa

### 2.6. Arquivamento (Ação Mais Importante)

- **Atalho**: `Backspace` (arquiva e vai para o próximo email)
- No Outlook, "Arquivar" move para a pasta `Arquivo Morto` (criada automaticamente a primeira vez)
- Se não aparecer: `Arquivo > Opções > Personalizar Faixa de Opções` e adicione o botão "Arquivar"

### 2.7. Regras de Produtividade Diária

1. **Processamento em Lotes (Batching)**
   - Verifique email 3x ao dia: 9h, 13h, 17h (NÃO em tempo real)
   - Desative notificações: `Arquivo > Opções > Email > "Exibir Alertas da Área de Notificação"` → desmarcar

2. **Regra dos 2 Minutos**
   - Se responder leva ≤2 min: faça AGORA
   - Se >2 min: mova para `@Action Required` e agende no calendário

3. **Toque uma vez (Touch It Once)**
   - Cada email é processado UMA vez:
     - Responder (se ≤2 min)
     - Delegar (encaminhar + mover para `@Waiting On`)
     - Arquivar (se só informação)
     - Agendar ação (mover para `@Action Required` + tarefa no calendário)

### 2.8. Limpeza Inicial da Caixa

Se sua caixa está cheia:

1. **Pesquisa Inteligente**: `recebido:<mês passado> AND lido:sim AND (não categorizado)` → arquive tudo
2. **Emails Grandes**: `tamanho:>1MB` → avalie e arquive
3. **Newsletters**: `assunto:newsletter OR anúncio OR oferta` → cancele inscrição Massa

---

## 3. Thunderbird — Configuração Equivalente

### 3.1. Estrutura de Pastas (mesma do Outlook)

Crie manualmente:
```
Inbox
├── @Action Required
├── @Waiting On
├── @Someday Maybe
└── @Archive
```

### 3.2. Layout Visual

1. **Painel à Direita**
   - `Ver > Layout > Painel da Mensagem > Direita`

2. **Colunas**
   - Clique direito na lista de mensagens > `Escolher Colunas`
   - Adicione: Status, Anexos, Sinalizador, Tags, Importância, De, Assunto, Data

3. **Agrupar por Conversa**
   - `Ver > Ordenar por > Agrupado por Conversa`

### 3.3. Tags (equivalente às Categorias do Outlook)

`Mensagem > Tag > Personalizar...`

Configure:

| Cor | Nome | Atalho | Uso |
|-----|------|--------|-----|
| 🔴 Vermelho | Urgente | 1 | Ação imediata |
| 🟠 Laranja | Cliente | 2 | Clientes externos |
| 🟡 Amarelo | Acompanhar | 3 | Monitoramento |
| 🟢 Verde | Financeiro | 4 | NF, boletos |
| 🔵 Azul | Projeto X | 5 | Projeto específico |
| 🟣 Roxo | Pessoal | 6 | Pessoal |
| ⚪ Cinza | Leitura | 7 | Newsletters |

**Atalho**: Selecione o email e pressione `1` a `7` (não precisa de Ctrl).

### 3.4. Filtros de Mensagem (equivalente a Regras do Outlook)

`Ferramentas > Filtros de Mensagem`

**Filtro 1: Newsletters → Tag "Leitura" + Mover**
- Condição: `De` contém `newsletter` OU Corpo contém `unsubscribe`
- Ação: Mover para `@Someday Maybe`, Marcar Tag `Leitura`, Marcar como lido

**Filtro 2: Faturas → Tag "Financeiro"**
- Condição: Assunto contém `fatura` OU `boleto` OU `NFS-e`
- Ação: Marcar Tag `Financeiro`, Sinalizar

**Filtro 3: Chefia → Tag "Urgente"**
- Condição: De contém `@empresa.com` (filtro específico por nome)
- Ação: Marcar Tag `Urgente`, Definir prioridade `Alta`

### 3.5. Extensões Essenciais

Instale (`Ferramentas > Complementos`):

1. **QuickFolders** — Navegação rápida de pastas com atalhos (`Ctrl+Shift+1` etc.)
   - Configure atalhos numéricos para: `Inbox=1`, `@Action Required=2`, `@Waiting On=3`, etc.

2. **Color+Tags** — Aplica cores de fundo nas mensagens conforme a tag
   - Equivalente à formatação condicional do Outlook

3. **SmartTemplate** — Respostas rápidas (modelos) com atalhos
   - Crie os mesmos templates do Outlook (seção 2.4)

4. **Send Later** — Agendar envio de email (igual ao agendamento do Outlook)

5. **ImportExportTools NG** — Backup e arquivamento

### 3.6. Atalhos de Teclado Thunderbird

| Ação | Atalho |
|------|--------|
| Novo email | `Ctrl+N` |
| Responder | `Ctrl+R` |
| Responder Todos | `Ctrl+Shift+R` |
| Encaminhar | `Ctrl+L` |
| Arquivar | `A` (tecla A) |
| Excluir | `Del` |
| Sinalizar | `S` ou `.` |
| Tag 1-7 | `1` a `7` |
| Ir para pasta | `Ctrl+Shift+F` |
| Buscar | `Ctrl+K` |
| Avançar para próximo não lido | `N` |
| Ir para próximo email | `F8` |

> **Nota**: Para o arquivamento no Thunderbird funcionar como no Outlook (`A` tecla), você precisa primeiro configurar em `Ferramentas > Configurações > Geral > Tecla "A" para arquivar` e definir a pasta `@Archive`.

### 3.7. Pastas Inteligentes (Saved Search)

Equivalente às Pastas de Pesquisa do Outlook:

1. Clique direito na lista de pastas > `Nova Pesquisa Salva`
2. Crie uma chamada **"Não Respondidos"**:
   - Condição: `Eu` `não está em` `De` → isso mostra emails que você não respondeu
3. Crie **"Anexos Grandes"**:
   - Condição: `Tamanho` `maior que` `1MB` e `Tem anexos` `é verdade`

### 3.8. Desativar Notificações

`Ferramentas > Configurações > Geral > Exibir Alertas` → Desmarcar TODAS

---

## 4. Rotina Diária (Checklist)

| Horário | Ação | Duração |
|---------|------|---------|
| 9:00 | **Processar Inbox** — Aplicar regra dos 2 minutos, categorizar, arquivar | 15 min |
| 9:15 | **Revisar @Action Required** — O que precisa ser feito HOJE | 5 min |
| 12:00 | **Segunda leva** — Processar novos emails, atualizar @Waiting On | 10 min |
| 17:00 | **Fechamento** — Processar tudo, deixar Inbox vazia, revisar calendário do dia seguinte | 15 min |

### Checklist de Fechamento (Final do Dia)

- [ ] Inbox está vazia (ou com no máximo 3 itens)
- [ ] @Action Required revisado e priorizado para amanhã
- [ ] @Waiting On atualizado (cobrar se necessário)
- [ ] Emails importantes foram sinalizados no calendário como tarefas
- [ ] Nenhum email sem categoria/flag

---

## 5. Comparativo Rápido Outlook vs Thunderbird

| Funcionalidade | Outlook | Thunderbird |
|----------------|---------|-------------|
| Categorias coloridas | Categorias (Ctrl+F2..8) | Tags (teclas 1..7) |
| Regras automáticas | Regras (Arquivo > Gerenciar) | Filtros (Ferramentas) |
| Formatação condicional | Formatação Condicional (Ver) | Color+Tags (extensão) |
| Pastas de pesquisa | Pastas de Pesquisa | Pesquisa Salva (clique direito) |
| Caixa focada | Caixa de Entrada Focada | QuickFolders + filtro manual |
| Respostas rápidas | Respostas Rápidas | SmartTemplate (extensão) |
| Arquivo rápido | Backspace | Tecla A (configurar) |
| Agendar envio | Enviar depois | Send Later (extensão) |
| Notificações | Opções > Email > Alertas | Config > Geral > Alertas |

---

## 6. Configurações Ninja (Avançado)

### Outlook — One-Click Archive
Adicione o botão "Arquivar" na Barra de Acesso Rápido:
1. Setinha para baixo na barra superior > `Mais Comandos`
2. Escolher comandos em: `Todos os Comandos`
3. Role até `Arquivar` > Adicionar >> 
4. Agora pode arquivar com 1 clique (além do Backspace)

### Outlook — Swipe no Celular
No app Outlook mobile:
- Deslize para direita: Arquivar
- Deslize para esquerda: Excluir ou Agendar
- Configuração: Config > Swipe

### Thunderbird — Compactar Pastas
Para não acumular espaço:
`Ferramentas > Compactar Pastas` (faça semanalmente)

### Thunderbird — Coluna de Tags Visível
Se as tags não aparecem na lista:
Clique direito na barra de colunas > coluna `Status` mostra o ícone de tag.
Ou adicione coluna `Tags` para ver todas as cores.

---

## 7. Dicas de Manutenção

### Semanal (sexta, 5 min)
- [ ] Revisar regras/filtros — precisa de ajustes?
- [ ] Limpar @Someday Maybe (arquivar ou excluir)
- [ ] Ver se alguma tag/categoria não está sendo usada

### Mensal (30 min)
- [ ] Cancelar inscrição de newsletters não lidas (pesquise: `Não categorizadas + Lidas + Mais de 30 dias`)
- [ ] Revisar pastas grandes (>100MB) e fazer limpeza
- [ ] Verificar se há emails não respondidos há >7 dias

### Trimestral
- [ ] Exportar/backup do arquivo PST (Outlook) ou perfil (Thunderbird)
- [ ] Reavaliar sistema de organização — está funcionando?

---

> **Regra Final**: O sistema perfeito é aquele que você usa consistentemente. Comece simples (4 pastas + categorias) e refine com o tempo. Não crie 30 regras no primeiro dia — adicione conforme sentir dor.
