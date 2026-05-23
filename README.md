# Second Brain

Meu vault pessoal do Obsidian — sistema de gestão de conhecimento organizado pelo método **PARA** (Projects, Areas, Resources, Archive) de Tiago Forte.

## Estrutura

```
.
├── 01 - Projects/    # Esforços ativos com objetivo e prazo definidos
├── 02 - Areas/       # Responsabilidades contínuas (sem data de fim)
│   ├── Career and Development
│   ├── Data Science
│   ├── Engineering
│   ├── Personal Finance
│   └── Software Development
├── 03 - Resources/   # Tópicos de interesse e material de referência
├── 04 - Archive/     # Itens inativos dos três anteriores
├── Docs/             # Documentação operacional
└── templates/        # Templates do Obsidian
```

### PARA em uma linha
- **Projects** — algo que termina (ex.: "Lançar exporter do Pi-hole")
- **Areas** — algo que mantenho (ex.: "Saúde", "Finanças", "Carreira")
- **Resources** — algo que pode ser útil um dia
- **Archive** — qualquer um dos anteriores quando deixa de estar ativo

## Uso

Abrir a pasta raiz no [Obsidian](https://obsidian.md) como vault. Configurações da app vivem em `.obsidian/` (versionadas, exceto o `workspace.json` local).

## Convenções

- Notas em Markdown, links internos `[[wiki-style]]`.
- Nomes de arquivos em português ou inglês conforme o domínio (ex.: notas técnicas em inglês, finanças em português).
- MOCs (Maps of Content) agregam notas relacionadas dentro de cada Area.

## Segurança

Este repositório é **privado**. Mesmo assim, segredos e dados sensíveis ficam fora do git via `.gitignore`:

- Chaves SSH/PEM
- Arquivos `.env`
- Planilhas financeiras (`*.xlsx`)
- Credenciais de aplicações (ex.: tokens de bots)

Antes de commitar conteúdo novo com configs/scripts, verificar se não há tokens, senhas ou dados pessoais em claro.
