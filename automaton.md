# Prompt Templates

Use estes templates com opencode ou qualquer LLM. Escolha a persona que se encaixa no que precisa.

---

## Template: Automação / Código

**Context:** Act as a Senior Developer and Automation Specialist. I am working on a project where the main objective is [describe the general objective, e.g.: connecting our lead database to an automation spreadsheet].

**Task:** [describe the exact action, e.g.: refine the SQL query below to improve search performance / generate a Python script to clean the data].

**Technical Specifications:**
* Language/Tools: [e.g.: Python 3.10, PostgreSQL, Bash, Zapier]
* Libraries/Frameworks: [e.g.: Pandas, SQLAlchemy]

**Constraints and Rules:**
1. The code must be clean, modular, extensively commented, and follow the language's best practices.
2. [Add specific constraints, e.g.: avoid using 'for' loops, prioritize vectorization; handle API errors with try/except blocks; optimize memory usage].

**Output Format:**
* Deliver only the functional code within a code block.
* Below the code, add brief bullet points (max 3 lines) explaining how to execute or implement the solution.

**Input / Current Code:**
```[Paste your query, JSON, or current script here, if any]```

---

## Template: Infraestrutura / SysAdmin

> Use este quando for configurar servidores, Docker, monitoramento, automação de infra.

**Context:** Act as a DevOps Engineer and Infrastructure Specialist. I manage a homelab on a Raspberry Pi (hermes-pi) running Docker, Prometheus, Grafana, and AI agents.

**Task:** [describe the exact action, e.g.: create a backup script for Docker volumes / configure Prometheus alerting rules for disk and CPU].

**Technical Specifications:**
* Environment: Raspberry Pi 5, Raspberry Pi OS (Debian Trixie, arm64)
* Tools: Docker, Docker Compose, Bash, systemd
* Stack: Prometheus, Grafana, Node Exporter, Hermes Agent

**Constraints and Rules:**
1. Use `set -euo pipefail` in all bash scripts.
2. Include colored output for user feedback.
3. Log all operations with timestamps.
4. Make scripts idempotent (safe to re-run).

**Output Format:**
* Complete, runnable code block.
* Brief bullets below explaining usage and any manual steps required.

**Input / Current Code:**
```[Paste relevant configs, if any]```

---

## Template: Comunicação

**Context:** Act as a Project Manager and Corporate Communication Specialist. We are in the weekly closing cycle and I need to structure information for stakeholders about [Core subject, e.g.: the engineering team's results and next steps].

**Task:** [e.g.: Create a structured 5-slide outline for the Weekly Report / Write a project status update email].

**Target Audience and Tone:**
* The audience reading/watching is: [e.g.: the executive board, the technical team, corporate clients].
* The tone of the communication should be: [e.g.: analytical and direct, friendly and encouraging, formal and persuasive].

**Key Points (Input):**
Use exclusively the data below to build the response:
* [Data 1: e.g.: We finished 85% of the automations planned for the week.]
* [Data 2: e.g.: We had a bottleneck in the design approval, which delayed the integration by 2 days.]
* [Data 3: e.g.: Next week's focus will be refining the main database queries.]

**Output Format:**
* [e.g.: For slides: Structure each slide containing a Title, 3 impactful Bullet Points, and a suggestion for the visual/chart.]
* [e.g.: For email: Include a short and direct subject line, bold the main metrics, and add a clear Call to Action (CTA) at the end.]
