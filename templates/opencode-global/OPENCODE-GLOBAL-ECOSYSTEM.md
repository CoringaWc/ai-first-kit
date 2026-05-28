# Ecossistema Global do OpenCode

Documento de referência do setup global em `/home/coringawc/.config/opencode`.

Atualizado em: `2026-05-27`.

## Resumo Para Leigos

Este OpenCode tem várias camadas. Pense nelas assim:

| Camada | O que é | Use quando |
| --- | --- | --- |
| OpenCode | O aplicativo principal que conversa com o modelo, carrega plugins, comandos, agents e skills. | Sempre. Ele é o host de tudo. |
| Superpowers | Regras de disciplina do agente: pensar antes, planejar, depurar direito, testar e revisar. | Quando a tarefa muda código, comportamento, design ou exige cuidado. |
| ECC | Biblioteca de engenharia: segurança, testes, bancos, Laravel, Django, Prisma, revisões, migrações e padrões. | Quando a tarefa é técnica e precisa de conhecimento específico. |
| CCG | Skills e comandos de qualidade, UI, documentação, arquitetura e multi-agent. | Quando você quer gates de qualidade, UI polish, domínio técnico ou automação CCG. |
| GSD | Workflow de projeto/fases com roadmap, SPEC, PLAN, execução e verificação. | Quando o trabalho é grande, com fases e checkpoints. |
| OpenSpec | CLI local para spec-driven development. | Quando você precisa transformar requisitos em spec/design/tasks antes de codar. |
| Graphify | Grafo de conhecimento do projeto. | Quando existe `graphify-out/graph.json` e você quer entender arquitetura/relações. |
| claude-mem | Memória persistente entre sessões. | Quando decisões e aprendizados precisam sobreviver a reinícios. |

## Mapa Visual De Uso Diario

Use este desenho quando estiver perdido:

```text
Pedido do usuario
       |
       v
E pergunta simples? -------------------------- sim ---> Responder direto
       |
      nao
       |
       v
Vai mudar codigo, UI, comportamento ou docs? -- sim ---> Superpowers escolhe skill
       |                                                |
      nao                                               v
       |                                      Bug? -> systematic-debugging
       v                                      Feature? -> brainstorming + TDD
Precisa entender projeto?                     UI? -> impeccable / ccg-frontend-design
       |                                      Seguranca? -> ecc-security-review
       v                                      Grande? -> /plan, GSD ou /spec-*
Graphify existe? -- sim ---> usar graphify query
       |
      nao
       |
       v
Usar explore, grep/glob, docs-lookup ou Context7
```

Regra simples: se voce nao sabe por onde comecar, escreva para o agente: `me ajude a escolher o workflow certo para esta tarefa: <descreva a tarefa>`. O plugin Superpowers deve forcar o agente a carregar skills relevantes antes de agir.

## Comece Por Aqui

Para uma tarefa pequena, faca assim:

1. Descreva o objetivo em uma frase.
2. Diga se pode editar arquivos ou se voce quer apenas explicacao.
3. Se for bug, cole o erro completo e diga como reproduzir.
4. Se for feature, diga o comportamento esperado e onde deve aparecer.
5. Deixe o agente escolher as skills e comandos, mas peca para explicar o caminho se voce quiser aprender.

Para uma tarefa media, use este roteiro:

1. Peca `/plan <objetivo>` se voce quer plano antes de mexer.
2. Aprove ou ajuste o plano.
3. Peca para executar o plano.
4. No final, peca `rode verificacoes e me diga evidencias`.

Para uma tarefa grande, use este roteiro:

1. Se ainda nao existe projeto/fase organizada, use GSD com `/gsd-new-project` ou `/gsd-plan-phase`.
2. Se o trabalho precisa de especificacao formal, use OpenSpec com `/spec-init` e depois `/spec-plan`.
3. Se existem partes independentes, use multi-agentes com `/orchestrate`, `/multi-plan` ou peça explicitamente `use subagents para pesquisar em paralelo`.
4. Antes de terminar, use `/code-review`, `/security` se houver risco, e `/verify` ou `verification-before-completion`.

## Tipos De Ferramenta Sem Confusao

| Tipo | Como voce chama | O que acontece | Exemplo |
| --- | --- | --- | --- |
| Skill | O agente carrega com o tool `skill` quando precisa. | Muda o metodo de trabalho do agente. | `brainstorming`, `systematic-debugging`, `ecc-security-review`. |
| Command | Voce digita `/nome-do-comando`. | Executa um prompt pronto, geralmente com agent/subagent. | `/plan`, `/code-review`, `/spec-plan`. |
| Agent | O agente principal chama como subagent. | Um especialista pesquisa, revisa ou executa parte isolada. | `planner`, `code-reviewer`, `security-reviewer`. |
| Plugin | Carrega sozinho quando OpenCode inicia. | Automatiza hooks, contexto, memoria ou tool extra. | `superpowers`, `ecc-hooks`, `graphify`. |
| CLI | Programa de terminal chamado por comando ou manualmente. | Faz trabalho fora do chat. | `openspec`, `graphify`, `opencode`. |

Em geral: voce usa comandos e conversa normal; plugins ficam ligados nos bastidores; skills sao escolhidas pelo agente; agents entram quando a tarefa precisa de especialista; CLIs diretos sao para diagnostico ou uso avancado.

## Estado Atual

| Item | Valor atual |
| --- | --- |
| Config principal | `/home/coringawc/.config/opencode/opencode.jsonc` |
| Serviço web | `opencode-web.service` |
| URL local | `http://localhost:4096` |
| Porta | `4096` |
| Modelo padrão | `llama.cpp/qwen36-claude-opus-mtp-compact` |
| Skills configuradas por arquivo | `117` nomes únicos nos roots configurados |
| Skills vistas pelo `opencode debug skill` | `118`, incluindo skill embutida `customize-opencode` |
| Duplicatas ativas | `0` avisos de duplicata no debug |
| Comandos globais em `commands/` | `134` arquivos `.md` |
| Comandos CCG fonte em `ccg/commands/ccg/` | `40` arquivos `.md` |
| MCP ativo | `context7` remoto |
| OpenSpec local | `/home/coringawc/.config/opencode/openspec/bin/openspec` |

## Descrições Das Skills Em Português

Pergunta: é possível deixar a descrição de todas as skills em português sem alterar as skills diretamente?

Resposta curta: não de forma oficial só com `opencode.jsonc`.

O OpenCode monta a lista de skills a partir do frontmatter de cada `SKILL.md`, principalmente os campos `name` e `description`. A documentação oficial do OpenCode e a especificação Agent Skills dizem que a descrição exibida vem desse frontmatter. O `opencode.jsonc` não tem campo para traduzir, sobrescrever ou criar aliases de descrições.

O que dá para fazer sem editar os `SKILL.md`:

1. Manter este documento como catálogo em pt_BR. É o caminho mais seguro.
2. Criar um plugin customizado que intercepte a definição do tool `skill` e reescreva a descrição apresentada ao modelo. Isso é possível tecnicamente usando hooks de plugin, mas é uma camada customizada e pode quebrar se o formato interno do tool mudar.
3. Gerar um catálogo separado em pt_BR, como JSON/Markdown, e instruir o agente a consultar esse catálogo. Isso não muda a lista nativa do tool `skill`.

O que exige alterar skills diretamente:

1. Traduzir o campo `description` em cada `SKILL.md`.
2. Criar cópias/overlays de skills com frontmatter traduzido.

Recomendação atual: deixar os arquivos de skill intactos e usar este documento como camada humana em português. Se a meta for que o próprio seletor nativo de skills apareça em português, aí precisa de plugin customizado ou alteração dos frontmatters.

## Como Decidir O Que Usar

Siga este roteiro simples:

1. A tarefa é só uma pergunta rápida? Responda direto, usando docs se precisar.
2. A tarefa cria comportamento novo, muda UI, adiciona feature ou altera fluxo? Use `brainstorming` primeiro.
3. A tarefa é bug, erro, build quebrado ou comportamento inesperado? Use `systematic-debugging` primeiro.
4. A tarefa envolve código novo ou bugfix? Use `test-driven-development` antes de implementar.
5. A tarefa está grande demais para uma conversa simples? Use GSD ou `writing-plans`.
6. A tarefa é visual/frontend? Use `impeccable` ou as skills CCG `ccg-frontend-design` e relacionadas.
7. A tarefa é segurança, banco, framework específico, migração, Laravel, Django, Prisma ou E2E? Use as skills ECC correspondentes.
8. A tarefa precisa gerar README/DESIGN ou verificar qualidade? Use CCG: `ccg-gen-docs`, `ccg-verify-*`.
9. Existe `graphify-out/graph.json` no projeto? Use Graphify para entender relações antes de vasculhar arquivos manualmente.
10. Terminou algo e quer dizer que está pronto? Use `verification-before-completion` antes.

## Plugins

Plugins sao automacoes carregadas quando o OpenCode inicia. Voce normalmente nao digita o nome do plugin no chat. Voce usa o OpenCode normalmente e o plugin age nos bastidores.

Fluxo mental correto:

```text
OpenCode inicia
       |
       v
Le opencode.jsonc + plugins auto-descobertos
       |
       v
Plugins registram hooks, contexto, tools e alteracoes de config
       |
       v
Voce conversa ou roda comandos
       |
       v
Plugins interceptam eventos quando necessario
```

| Plugin | Arquivo | O que faz | Quando você deve pensar nele |
| --- | --- | --- | --- |
| claude-mem | `plugins/claude-mem.js` | Integra memória persistente ao OpenCode. | Quando quiser lembrar decisões, padrões, caminhos e próximos passos entre sessões. |
| claude-mem-manual-summary | `plugins/claude-mem-manual-summary.js` | Em `session.idle` e `session.deleted`, roda scanner de blocos `CLAUDE_MEM_MANUAL_SUMMARY`. | Quando a resposta final contém um resumo durável que deve ir para memória. |
| graphify | `plugins/graphify.js` | Se existir `graphify-out/graph.json`, injeta lembrete antes de comandos shell para usar o grafo. | Quando você está em projeto com grafo gerado e quer consultas mais inteligentes que grep bruto. |
| plugin-display-names | `plugins/plugin-display-names.js` | Encurta a lista `config.plugin` em runtime para o popup do OpenCode web mostrar nomes como `ecc-hooks` em vez de URLs `file:///home/...`. | Quando o popup superior de MCPs/plugins fica ilegível por causa de paths longos. |
| superpowers | `plugins/superpowers.js` | Injeta o bootstrap `using-superpowers` no começo da conversa e garante descoberta das skills Superpowers quando necessário. | Sempre. Ele é a camada que força o agente a usar skills antes de agir. |
| ecc-hooks | `plugins/ecc-hooks.ts` | Hooks ECC para rastrear arquivos alterados, alertar `console.log`, formatar em modo strict, registrar mudanças e expor tool de changed files. | Quando você quer automação de qualidade durante edição. Normalmente fica ligado. |
| index | `plugins/index.ts` | Reexporta o plugin ECC. | Arquivo de compatibilidade/entrada para carregar ECC. Você raramente mexe nele. |

### Workflow Do Plugin `superpowers`

Use mentalmente assim:

```text
Nova conversa
       |
       v
superpowers injeta using-superpowers no primeiro pedido
       |
       v
Agente e obrigado a checar skills antes de responder
       |
       v
Se alguma skill combina, agente carrega a skill
       |
       v
Agente segue o workflow da skill
```

O que voce faz:

1. Nao precisa chamar `superpowers` manualmente.
2. Escreva a tarefa normalmente.
3. Se quiser garantir disciplina, diga: `use o workflow correto de skills antes de agir`.
4. Para feature nova, espere o agente usar `brainstorming`.
5. Para bug, espere o agente usar `systematic-debugging`.
6. Para implementacao, espere o agente usar `test-driven-development` quando aplicavel.

Quando desconfiar que nao funcionou:

1. Se o agente sair codando sem skill em tarefa complexa, interrompa e diga: `pare e use a skill apropriada primeiro`.
2. Se a conversa iniciou antes de alteracoes em plugin/skills, reinicie o OpenCode.

### Workflow Do Plugin `claude-mem`

Use mentalmente assim:

```text
Durante a sessao
       |
       v
Decisoes e aprendizados importantes aparecem
       |
       v
Resposta final pode conter CLAUDE_MEM_MANUAL_SUMMARY
       |
       v
claude-mem guarda memoria para sessoes futuras
```

O que voce faz:

1. Para lembrar algo duravel, diga: `registre isto na memoria manual no final`.
2. Use memoria para decisoes, caminhos importantes, comandos uteis e proximos passos.
3. Nao coloque tokens, senhas, chaves, dados pessoais ou outputs grandes.
4. Em outra sessao, diga: `procure na memoria o contexto de <assunto>`.

Quando usar:

1. Depois de configurar ambiente.
2. Depois de decidir padrao de arquitetura.
3. Depois de corrigir um erro dificil.
4. Antes de encerrar uma sessao longa.

### Workflow Do Plugin `claude-mem-manual-summary`

Use mentalmente assim:

```text
Resposta final contem CLAUDE_MEM_MANUAL_SUMMARY
       |
       v
Sessao fica idle ou e encerrada
       |
       v
Plugin roda scanner automatico
       |
       v
Resumo vai para claude-mem
```

O que voce faz:

1. Quando quiser memoria duravel, peca para o agente incluir o bloco `CLAUDE_MEM_MANUAL_SUMMARY` no final.
2. Nao precisa rodar scanner manualmente na maioria dos casos.
3. Se quiser confirmar depois, peca `busque na memoria por <titulo ou tema>`.

Quando usar:

1. Use no encerramento de tarefas de configuracao.
2. Use no encerramento de migracoes.
3. Use quando o proximo agente precisara continuar de onde parou.

### Workflow Do Plugin `graphify`

Use mentalmente assim:

```text
Projeto tem graphify-out/graph.json?
       |
       v
Sim: plugin lembra antes de bash
       |
       v
Use graphify query para perguntas focadas
       |
       v
Use GRAPH_REPORT.md para visao ampla
```

O que voce faz:

1. Se o projeto ja tem `graphify-out/graph.json`, pergunte: `use Graphify para entender esta parte: <pergunta>`.
2. Para pergunta focada, use `graphify query "<pergunta>"`.
3. Para arquitetura geral, leia `GRAPH_REPORT.md`.
4. Se nao existe grafo, peca `gere um grafo Graphify deste projeto`.

Quando usar:

1. Antes de refatoracao grande.
2. Para entender dependencias entre arquivos.
3. Para descobrir onde implementar uma feature.
4. Para onboarding em projeto desconhecido.

### Workflow Do Plugin `ecc-hooks`

Use mentalmente assim:

```text
Agente edita arquivo ou roda comando
       |
       v
ecc-hooks registra arquivo alterado
       |
       v
Pode avisar sobre console.log, typecheck, docs desnecessarias ou push
       |
       v
No idle, roda auditoria leve e limpa estado
```

O que voce faz:

1. Nao precisa chamar `ecc-hooks` manualmente.
2. Se aparecer aviso `[ECC]`, leia como alerta de qualidade, nao como erro fatal automatico.
3. Use `changed-files` ou o tool `changed-files` para ver arquivos alterados rastreados.
4. Para rigor maior, configure `ECC_HOOK_PROFILE=strict` antes de iniciar o OpenCode.
5. Para menos ruido, use `ECC_HOOK_PROFILE=minimal` antes de iniciar o OpenCode.

Quando usar:

1. Sempre que estiver editando codigo.
2. Antes de commit, para saber o que mudou.
3. Quando quiser rastreamento de arquivos modificados por agents.

### Workflow Do Plugin `plugin-display-names`

Use mentalmente assim:

```text
OpenCode monta lista de plugins
       |
       v
Paths longos sao encurtados para nomes legiveis
       |
       v
Interface web fica mais facil de entender
```

O que voce faz:

1. Nada no uso diario.
2. Se o popup de plugins estiver ilegivel, este plugin ja deve ajudar.
3. Se mexer nele, reinicie o OpenCode.

### Workflow Do Plugin `index`

Use mentalmente assim:

```text
OpenCode encontra index.ts
       |
       v
index reexporta ECC
       |
       v
ECC hooks ficam disponiveis
```

O que voce faz:

1. Nada no uso diario.
2. Trate como arquivo tecnico de compatibilidade.
3. Nao edite a menos que esteja consertando carregamento do ECC.

## Configuração Ativa

| Área | Estado |
| --- | --- |
| Instructions | `/home/coringawc/.config/opencode/AGENTS.md` |
| Plugins explícitos | `claude-mem.js`, `graphify.js`, `claude-mem-manual-summary.js` |
| Plugins auto-descobertos relevantes | `superpowers.js`, `ecc-hooks.ts`, `index.ts`, `plugin-display-names.js` |
| Skill roots | `skills`, `ecc/skills`, `ccg/skills` |
| MCP | `context7` remoto com `CONTEXT7_API_KEY` |
| Provider local | `llama.cpp` em `http://dias-desktop.tailf0492f.ts.net:3500/v1` |
| Agents globais inline | planner, architect, code-reviewer, security-reviewer, tdd-guide, build-error-resolver, e2e-runner, doc-updater, refactor-cleaner, docs-lookup, harness-optimizer, loop-operator |

## Skills Superpowers E Globais

Estas skills ficam em `/home/coringawc/.config/opencode/skills`. Misturam Superpowers e skills globais utilitárias.

| Skill | Quando usar, em português simples |
| --- | --- |
| `using-superpowers` | No início de qualquer conversa. Garante que skills sejam verificadas antes de agir. |
| `brainstorming` | Antes de criar feature, componente, fluxo ou comportamento novo. Ajuda a entender intenção antes de codar. |
| `systematic-debugging` | Quando há bug, erro, teste falhando, build quebrado ou comportamento estranho. Obriga achar causa raiz. |
| `test-driven-development` | Antes de implementar feature ou bugfix. Ajuda a escrever teste falhando primeiro. |
| `writing-plans` | Quando já existe uma especificação e você precisa de plano detalhado de implementação. |
| `executing-plans` | Quando há um plano escrito e você quer executar passo a passo na sessão atual. |
| `subagent-driven-development` | Quando um plano tem tarefas independentes e pode ser executado por subagents com revisão entre tarefas. |
| `dispatching-parallel-agents` | Quando há duas ou mais tarefas independentes que podem rodar em paralelo. |
| `using-git-worktrees` | Antes de trabalho que precisa ficar isolado do branch atual. |
| `requesting-code-review` | Depois de implementar algo importante ou antes de merge/PR. |
| `receiving-code-review` | Quando alguém ou um agent deu feedback de review e você precisa avaliar antes de aplicar. |
| `verification-before-completion` | Antes de dizer “pronto”, “corrigido” ou “passou”. Exige evidência. |
| `finishing-a-development-branch` | Quando terminou uma branch e precisa decidir merge, PR, manter ou descartar. |
| `writing-skills` | Quando for criar ou editar skills. Trata skills como documentação testável. |
| `agent-browser` | Para navegar sites, preencher formulários, testar apps web, screenshots e automação de browser. |
| `caveman` | Quando o usuário pede resposta ultra curta, estilo “caveman”, ou economia forte de tokens. |
| `design-md-library` | Quando o usuário quer UI no estilo de marca/produto conhecido, como Apple, Stripe, Linear, Vercel. |
| `find-skills` | Quando o usuário pergunta se existe skill para alguma tarefa ou quer descobrir skills novas. |
| `graphify` | Quando quer gerar/consultar grafo de conhecimento de código, docs ou arquitetura. |
| `grill-me` | Quando o usuário quer ser questionado rigorosamente sobre um plano/design. |
| `grill-with-docs` | Como `grill-me`, mas confrontando o plano com docs do projeto e atualizando contexto/ADRs. |
| `healthcare-phi-compliance` | Para PHI/PII em aplicações de saúde, privacidade, trilhas de auditoria e vazamentos. |
| `hookify-rules` | Para criar ou configurar regras Hookify. |
| `impeccable` | Para design/revisão/polimento de UI frontend com qualidade visual alta. |
| `plankton-code-quality` | Para qualidade em tempo de escrita com Plankton, formatação/lint/fixes via hooks. |
| `production-audit` | Para auditoria local de prontidão de produção. |
| `skill-creator` | Para criar, modificar, testar e otimizar skills. |
| `skill-scout` | Para procurar skills locais, marketplace, GitHub ou web antes de criar nova. |
| `ui-ux-pro-max` | Para inteligência UI/UX com base de dados pesquisável. |
| `web-design-guidelines` | Para revisar UI contra boas práticas web, acessibilidade e UX. |

## Skills ECC

ECC é a biblioteca técnica. Use quando a tarefa pede um domínio específico ou uma prática de engenharia. Todas já usam prefixo `ecc-`.

| Skill | Quando usar, em português simples |
| --- | --- |
| `ecc-agent-introspection-debugging` | Para depurar falhas de agents e entender por que um agent se comportou mal. |
| `ecc-agent-sort` | Para decidir quais partes do ECC instalar em um repositório específico. |
| `ecc-ai-regression-testing` | Para testes de regressão em desenvolvimento assistido por IA. |
| `ecc-clickhouse-io` | Para ClickHouse, analytics e consultas OLAP de alta performance. |
| `ecc-code-tour` | Para criar tours guiados de código em arquivos `.tour`. |
| `ecc-configure-ecc` | Para instalar/configurar ECC de forma guiada. |
| `ecc-continuous-learning` | Skill antiga de aprendizado contínuo. Prefira `ecc-continuous-learning-v2`. |
| `ecc-continuous-learning-v2` | Para capturar aprendizados persistentes como instincts por projeto. |
| `ecc-council` | Para decisões ambíguas com múltiplas opções válidas. |
| `ecc-database-migrations` | Para migrations, rollback, zero downtime e mudanças de schema. |
| `ecc-defi-amm-security` | Para segurança de contratos AMM/DeFi em Solidity. |
| `ecc-django-security` | Para segurança em Django: auth, CSRF, SQLi, XSS e deploy. |
| `ecc-dmux-workflows` | Para orquestração multi-agent usando dmux/tmux. |
| `ecc-e2e-testing` | Para testes E2E com Playwright, Page Objects, CI e flakes. |
| `ecc-error-handling` | Para padrões robustos de erro em TypeScript, Python e Go. |
| `ecc-eval-harness` | Para avaliação formal de sessões e workflows de agents. |
| `ecc-evm-token-decimals` | Para evitar bugs de casas decimais em tokens EVM. |
| `ecc-healthcare-phi-compliance` | Para PHI/PII em saúde com foco ECC. |
| `ecc-hipaa-compliance` | Para HIPAA, PHI, BAA e compliance de saúde nos EUA. |
| `ecc-hookify-rules` | Para regras Hookify no pacote ECC. |
| `ecc-iterative-retrieval` | Para recuperar contexto em rodadas e resolver problema de contexto de subagent. |
| `ecc-laravel-patterns` | Para arquitetura Laravel, controllers, Eloquent, services, queues e cache. |
| `ecc-laravel-plugin-discovery` | Para descobrir e avaliar pacotes Laravel. |
| `ecc-laravel-security` | Para segurança Laravel: validação, CSRF, mass assignment, uploads e rate limit. |
| `ecc-laravel-tdd` | Para TDD em Laravel com PHPUnit/Pest, factories e fakes. |
| `ecc-laravel-verification` | Para loop de verificação Laravel: env, lint, static analysis, testes e segurança. |
| `ecc-llm-trading-agent-security` | Para segurança de agentes LLM que podem operar carteiras/transações. |
| `ecc-mysql-patterns` | Para MySQL/MariaDB: schema, índices, transações e replicação. |
| `ecc-nodejs-keccak256` | Para evitar confusão entre SHA3 e Keccak em Ethereum com Node.js. |
| `ecc-perl-security` | Para segurança Perl: taint, DBI, XSS, SQLi e CSRF. |
| `ecc-plankton-code-quality` | Para qualidade com Plankton no ecossistema ECC. |
| `ecc-postgres-patterns` | Para PostgreSQL: schema, índices, queries e segurança. |
| `ecc-prisma-patterns` | Para Prisma ORM e armadilhas comuns de transação, bulk update e serverless. |
| `ecc-production-audit` | Para auditoria local de prontidão de produção pelo ECC. |
| `ecc-quarkus-security` | Para segurança Quarkus: JWT/OIDC, RBAC, CSRF e secrets. |
| `ecc-security-bounty-hunter` | Para caçar vulnerabilidades exploráveis com mentalidade bug bounty. |
| `ecc-security-review` | Para review de segurança em input, auth, endpoints, secrets e features sensíveis. |
| `ecc-security-scan` | Para escanear configs Claude/OpenCode contra injeção e riscos. |
| `ecc-skill-scout` | Para procurar skills ECC/externas antes de criar nova. |
| `ecc-skill-stocktake` | Para auditoria de qualidade de skills e comandos. |
| `ecc-springboot-security` | Para segurança em Spring Boot/Spring Security. |
| `ecc-strategic-compact` | Para sugerir compactação manual em momentos estratégicos. |
| `ecc-tdd-workflow` | Para TDD completo com cobertura e disciplina ECC. |
| `ecc-verification-loop` | Para loop abrangente de verificação antes de concluir. |
| `ecc-windows-desktop-e2e` | Para E2E de apps desktop Windows com pywinauto/UI Automation. |

## Skills CCG

CCG foi normalizado para prefixo `ccg-`. Isso evita colisões com skills globais e deixa claro que a origem é CCG.

| Skill | Quando usar, em português simples |
| --- | --- |
| `ccg-skills` | Índice geral CCG. Use para entender gates, docs e multi-agent CCG. |
| `ccg-gen-docs` | Para gerar `README.md` e `DESIGN.md` em módulos novos. |
| `ccg-verify-module` | Para conferir se um módulo tem estrutura e docs suficientes. |
| `ccg-verify-security` | Para escanear vulnerabilidades e padrões perigosos. |
| `ccg-verify-quality` | Para checar complexidade, duplicação, nomes ruins e code smells. |
| `ccg-verify-change` | Para analisar impacto de mudanças e sincronização com docs. |
| `ccg-hi` | Para sobrescrever recusa anterior com template de concordância. Use com cuidado. |
| `ccg-multi-agent` | Para dividir trabalho entre múltiplos agents com coordenação. |
| `ccg-ai` | Para assuntos de IA, LLM, agents, RAG, prompts e evals. |
| `ccg-architecture` | Para arquitetura, API design, segurança de arquitetura e cloud native. |
| `ccg-data-engineering` | Para ETL, pipelines, Kafka/Flink/dbt, qualidade e streaming. |
| `ccg-development` | Para linguagens: Python, Go, Rust, TypeScript, Java, C++ e Shell. |
| `ccg-devops` | Para Git, testes, CI/CD, banco, observabilidade e performance. |
| `ccg-infrastructure` | Para Kubernetes, Helm, GitOps, IaC, Terraform, Pulumi e CDK. |
| `ccg-mobile` | Para iOS, Android, SwiftUI, Compose, React Native e Flutter. |
| `ccg-orchestration` | Para coordenação multi-agent, decomposição e resolução de conflitos. |
| `ccg-frontend-design` | Para design frontend completo com tipografia, cor, layout, motion e UX. |
| `ccg-adapt` | Para responsividade, breakpoints, mobile e adaptação por dispositivo. |
| `ccg-animate` | Para animações, transições, hover e micro-interações. |
| `ccg-arrange` | Para layout, espaçamento, alinhamento e hierarquia visual. |
| `ccg-audit` | Para auditoria técnica de acessibilidade, performance, tema e responsividade. |
| `ccg-bolder` | Para deixar UI sem graça mais marcante e expressiva. |
| `ccg-clarify` | Para melhorar textos, labels, mensagens de erro e microcopy. |
| `ccg-colorize` | Para adicionar cor estratégica e reduzir aparência cinza/monótona. |
| `ccg-critique` | Para crítica UX/UI com pontuação, heurísticas e recomendações. |
| `ccg-delight` | Para adicionar pequenos momentos de prazer, personalidade e polimento. |
| `ccg-distill` | Para simplificar UI, remover ruído e focar no essencial. |
| `ccg-extract` | Para extrair componentes, tokens e padrões reutilizáveis. |
| `ccg-harden` | Para robustez de UI: erros, overflow, i18n e estados extremos. |
| `ccg-normalize` | Para alinhar UI ao design system e corrigir drift visual. |
| `ccg-onboard` | Para onboarding, empty states, first-run e ativação de usuário. |
| `ccg-optimize` | Para performance frontend, jank, bundle, imagens e loading. |
| `ccg-overdrive` | Para efeitos ambiciosos: shaders, spring physics, scroll reveals e wow factor. |
| `ccg-polish` | Para acabamento final antes de entregar: alinhamento, spacing e consistência. |
| `ccg-quieter` | Para reduzir UI agressiva, barulhenta ou visualmente cansativa. |
| `ccg-teach-impeccable` | Para criar contexto de design persistente do projeto. |
| `ccg-typeset` | Para tipografia, legibilidade, escala, pesos e hierarquia textual. |
| `ccg-claymorphism` | Para UI soft/puffy estilo claymorphism. |
| `ccg-glassmorphism` | Para UI com vidro fosco, blur, transparência e profundidade. |
| `ccg-liquid-glass` | Para visual Apple Liquid Glass com translucidez e profundidade. |
| `ccg-neubrutalism` | Para UI neobrutalista com bordas grossas, sombras offset e cores fortes. |
| `ccg-scrapling` | Para scraping/coleta de dados com Scrapling, Cloudflare/WAF e parsing HTML. |

## Agents Globais Inline

Agents são especialistas que podem ser chamados como subagents. Use quando a tarefa tem escopo claro e precisa de uma perspectiva específica.

| Agent | Quando usar |
| --- | --- |
| `planner` | Planejar feature complexa, refatoração ou sequência de tarefas. |
| `architect` | Decisões de arquitetura, escalabilidade e desenho de sistema. |
| `code-reviewer` | Revisar código recém-alterado, riscos, bugs e manutenibilidade. |
| `security-reviewer` | Revisar auth, input, endpoints, secrets, pagamentos e dados sensíveis. |
| `tdd-guide` | Guiar TDD e cobertura. |
| `build-error-resolver` | Resolver build quebrado e erros TypeScript/compilação. |
| `e2e-runner` | Criar/rodar testes E2E com Playwright. |
| `doc-updater` | Atualizar docs e codemaps. |
| `refactor-cleaner` | Remover dead code, duplicação e simplificar código. |
| `docs-lookup` | Buscar documentação atual via Context7. |
| `harness-optimizer` | Melhorar confiabilidade/custo/config do harness local. |
| `loop-operator` | Operar loops autônomos e intervir se travarem. |

## Multi-Agentes Para Leigos

Multi-agentes significa dividir uma tarefa em partes menores e mandar especialistas trabalharem em paralelo ou em sequencia. Nao e obrigatorio para tarefas simples.

Use este mapa:

```text
Tarefa pequena
       |
       v
1 agente principal resolve

Tarefa media com plano
       |
       v
/plan -> voce aprova -> agente implementa -> code-reviewer revisa

Tarefa grande com partes independentes
       |
       v
/orchestrate ou /multi-plan
       |
       v
subagents pesquisam/revisam em paralelo
       |
       v
agente principal sintetiza e aplica mudancas
```

Quando usar multi-agentes:

1. Feature fullstack com frontend, backend, banco e testes.
2. Refatoracao grande em varios modulos.
3. Auditoria onde voce quer perspectivas diferentes, como seguranca, arquitetura e testes.
4. Investigacao de bug que pode estar em camadas diferentes.
5. Projeto desconhecido em que varias areas precisam ser exploradas ao mesmo tempo.

Quando nao usar multi-agentes:

1. Alteracao pequena em um arquivo.
2. Pergunta conceitual simples.
3. Bug com erro obvio e reproduzivel em uma funcao.
4. Quando voce quer controle manual total e passo a passo.

### Formas De Usar Multi-Agentes

| Caminho | Como chamar | Melhor para | O que esperar |
| --- | --- | --- | --- |
| Subagent automatico | Pedir no chat: `use subagents para pesquisar X e Y em paralelo`. | Pesquisa e revisao pontual. | O agente principal dispara especialistas e resume. |
| `/orchestrate` | `/orchestrate <tarefa complexa>` | Quebrar trabalho em especialistas OpenCode. | Plano de execucao com agents como planner, architect e reviewer. |
| `/multi-plan` | `/multi-plan <feature ou problema>` | Planejamento multi-modelo sem editar codigo. | Plano salvo em `.opencode/plan/*.md`. |
| `/multi-execute` | `/multi-execute .opencode/plan/<arquivo>.md` | Executar plano aprovado. | Codex sugere prototipos, agente principal aplica codigo com soberania. |
| `/multi-workflow` | `/multi-workflow <tarefa grande>` | Fluxo completo com pesquisa, ideacao, plano, execucao, otimizacao e review. | Mais pesado, com gates e confirmacoes. |
| OpenSpec `/spec-*` | `/spec-research`, `/spec-plan`, `/spec-impl`, `/spec-review` | Mudancas formais guiadas por spec. | Cria artefatos `openspec/changes/*` e implementa por fases. |

### Workflow Seguro De Multi-Agentes

1. Comece com `/plan <objetivo>` ou `/multi-plan <objetivo>`.
2. Leia o plano e aprove explicitamente.
3. Se o plano foi salvo, execute com `/multi-execute .opencode/plan/<arquivo>.md`.
4. Durante execucao, mantenha um unico agente com permissao real de escrita: o agente principal.
5. Trate saidas de Codex/outros modelos como prototipo ou review, nunca como patch para aplicar cegamente.
6. Depois de implementar, use `/code-review` e `/security` quando fizer sentido.
7. Finalize com verificacoes reais: testes, build, lint ou comando especifico do projeto.

### Exemplos Prontos

Para feature fullstack:

```text
/multi-plan adicionar cadastro de usuarios com email e senha, validacao, API, UI e testes
```

Depois de aprovar:

```text
/multi-execute .opencode/plan/cadastro-usuarios.md
```

Para revisao paralela:

```text
/orchestrate revisar esta mudanca com foco em arquitetura, seguranca e testes
```

Para pesquisa sem mexer em codigo:

```text
use subagents para explorar a camada de autenticacao e a camada de frontend em paralelo; nao edite arquivos
```

## Comandos Globais Mais Importantes

Existem muitos comandos em `/home/coringawc/.config/opencode/commands`. Comando e algo que voce digita com `/`. Ele geralmente carrega um prompt pronto e pode chamar um agent especifico.

Fluxo mental:

```text
Voce digita /comando argumentos
       |
       v
OpenCode carrega commands/<comando>.md
       |
       v
O comando pode chamar agent/subagent
       |
       v
O agente executa o workflow descrito no comando
```

Para uso diario, pense assim:

| Grupo | Exemplos | Quando usar |
| --- | --- | --- |
| ECC core | `/plan`, `/tdd`, `/code-review`, `/security`, `/build-fix`, `/e2e`, `/refactor-clean`, `/orchestrate`, `/quality-gate` | Para tarefas de engenharia, revisão, testes e correções. |
| GSD | `/gsd-*` | Para projetos com roadmap, fases, execução, verificação, review, UI/security/eval audits. |
| OpenSpec | `/spec-init`, `/spec-research`, `/spec-plan`, `/spec-impl`, `/spec-review` | Para transformar requisitos em specs e planos antes de implementar. |
| Continuous learning | `/instinct-status`, `/evolve`, `/promote`, `/learn` | Para gerenciar aprendizados/instincts. |
| Multi-workflow | `/multi-plan`, `/multi-execute`, `/multi-workflow` | Para workflows maiores que dependem do runtime CCG/ECC. |

### Quando Usar Cada Comando Principal

| Comando | Use quando | Resultado esperado |
| --- | --- | --- |
| `/plan <objetivo>` | Voce quer plano antes de editar. | Plano de implementacao, normalmente sem mexer em codigo. |
| `/tdd <objetivo>` | Voce quer implementar com testes primeiro. | Teste falhando, implementacao, teste passando. |
| `/code-review <escopo>` | Voce quer review de codigo. | Findings por severidade e sugestoes. |
| `/security <escopo>` | Auth, input, endpoint, secrets, pagamento ou dados sensiveis. | Review de seguranca. |
| `/build-fix <erro>` | Build, TypeScript ou compilacao falhando. | Correcao minima do erro. |
| `/e2e <fluxo>` | Precisa testar fluxo de usuario no browser. | Teste Playwright ou execucao E2E. |
| `/refactor-clean <escopo>` | Remover duplicacao, dead code ou simplificar. | Refatoracao controlada. |
| `/update-docs <escopo>` | Docs ficaram desatualizadas apos mudanca. | README, codemap ou docs atualizadas. |
| `/test-coverage <escopo>` | Quer entender cobertura e lacunas de teste. | Relatorio de cobertura e arquivos fracos. |
| `/orchestrate <tarefa>` | A tarefa precisa de varios especialistas. | Plano multi-agent e coordenacao. |
| `/multi-plan <tarefa>` | Quer planejamento multi-modelo, sem codigo ainda. | Plano salvo em `.opencode/plan`. |
| `/multi-execute <plano>` | Quer executar plano multi-modelo aprovado. | Implementacao com Codex como consultor e agente principal como escritor. |
| `/multi-workflow <tarefa>` | Quer fluxo longo ponta a ponta. | Research, ideation, plan, execute, optimize, review. |
| `/gsd-help` | Esta perdido no GSD. | Ajuda dos comandos GSD. |
| `/gsd-new-project` | Projeto grande do zero. | Estrutura de roadmap/fases. |
| `/gsd-plan-phase` | Planejar uma fase especifica. | Plano de fase. |
| `/gsd-execute-phase` | Executar fase planejada. | Implementacao com checkpoints. |
| `/gsd-verify-work` | Verificar se trabalho cumpriu objetivo. | Relatorio de verificacao. |

### Ordem Recomendada Por Cenario

Feature pequena:

```text
/plan <feature>
aprovar plano
implementar
/code-review
verificacoes finais
```

Bug:

```text
descrever erro e como reproduzir
agente usa systematic-debugging
teste que reproduz
correcao
/code-review se a correcao for relevante
```

Feature grande com spec:

```text
/spec-init
/spec-research "<mudanca desejada>"
/spec-plan
/spec-impl
/spec-review
```

Projeto grande com fases:

```text
/gsd-new-project
/gsd-plan-phase
/gsd-execute-phase
/gsd-verify-work
```

Multi-agente sem OpenSpec:

```text
/multi-plan <tarefa>
aprovar plano
/multi-execute .opencode/plan/<arquivo>.md
/code-review
```

## OpenSpec Local

| Item | Valor |
| --- | --- |
| Root local | `/home/coringawc/.config/opencode/openspec` |
| Binário/wrapper | `/home/coringawc/.config/opencode/openspec/bin/openspec` |
| Papel | Criar e validar specs, designs e tasks em projetos. |
| Observação | Não é skill. É CLI local chamado por comandos `/spec-*`. |

### OpenSpec: Comandos Ou CLI Direto?

Resposta curta: no uso normal, use os comandos `/spec-*`. Use o binario `openspec` direto apenas para diagnostico, verificacao manual ou operacao avancada.

Neste setup nao ha um plugin OpenSpec ativo separado no `opencode.jsonc`. O que existe e:

1. Um CLI local OpenSpec em `/home/coringawc/.config/opencode/openspec/bin/openspec`.
2. Comandos OpenCode `/spec-*` em `/home/coringawc/.config/opencode/commands`.
3. Workflows CCG em `/home/coringawc/.config/opencode/ccg/commands/ccg/spec-*.md`.
4. Os comandos `/spec-*` chamam os workflows CCG, e os workflows CCG chamam o CLI OpenSpec.

Fluxo visual:

```text
Voce digita /spec-research "minha mudanca"
       |
       v
OpenCode carrega commands/spec-research.md
       |
       v
Esse comando chama o workflow CCG spec-research
       |
       v
O workflow usa openspec CLI local
       |
       v
Arquivos aparecem em openspec/changes/<change-id>/
```

Use `/spec-*` para trabalho normal:

| Comando | Quando usar | O que ele faz |
| --- | --- | --- |
| `/spec-init` | Primeira vez em um projeto ou quando quer validar setup. | Verifica OpenSpec, inicializa `openspec/`, testa `codeagent-wrapper`. |
| `/spec-research "descricao"` | Antes de planejar, quando voce ainda tem so a ideia. | Pesquisa contexto, cria change, escreve `proposal.md`, valida. |
| `/spec-plan` | Depois do research. | Escolhe change, resolve ambiguidades, cria `specs`, `design.md` e `tasks.md`. |
| `/spec-impl` | Depois do plano aprovado. | Implementa tarefas por fases, revisa com Codex, marca tasks e arquiva ao final. |
| `/spec-review` | A qualquer momento depois de ter implementacao/diff. | Revisa implementacao contra spec, seguranca, regressao e padroes. |

Use o CLI direto so nestes casos:

| Comando CLI | Quando usar |
| --- | --- |
| `/home/coringawc/.config/opencode/openspec/bin/openspec --version` | Confirmar versao instalada. |
| `/home/coringawc/.config/opencode/openspec/bin/openspec status --json` | Diagnosticar estado do projeto. |
| `/home/coringawc/.config/opencode/openspec/bin/openspec list --json` | Ver active changes sem iniciar workflow completo. |
| `/home/coringawc/.config/opencode/openspec/bin/openspec validate "<change>" --type change --strict --no-interactive` | Validar manualmente um change. |
| `/home/coringawc/.config/opencode/openspec/bin/openspec archive "<change>" --yes` | Arquivar manualmente quando voce sabe exatamente o que esta fazendo. |

Regra pratica: se voce esta construindo algo, use `/spec-*`; se voce esta checando ou consertando o setup, use `openspec` direto.

### Workflow OpenSpec Recomendado

```text
Ideia da mudanca
       |
       v
/spec-init
       |
       v
/spec-research "descricao clara da mudanca"
       |
       v
Ler proposal.md e responder perguntas
       |
       v
/spec-plan
       |
       v
Aprovar specs/design/tasks
       |
       v
/spec-impl
       |
       v
/spec-review
       |
       v
Arquivar quando tudo passar
```

O que cada fase pode ou nao pode fazer:

| Fase | Pode editar codigo? | Deve parar quando? |
| --- | --- | --- |
| `/spec-init` | Nao deveria mexer em codigo do app. | Setup validado. |
| `/spec-research` | Nao. | `proposal.md` criado e validado. |
| `/spec-plan` | Nao. | `specs`, `design.md`, `tasks.md` criados e validados. |
| `/spec-impl` | Sim. | Tarefas implementadas e revisadas. |
| `/spec-review` | Normalmente nao, a menos que voce peca fix. | Findings apresentados e decisao tomada. |

## Passo A Passo Por Tipo De Tarefa

### Quero só entender um projeto

1. Se existir `graphify-out/graph.json`, use `graphify` primeiro.
2. Se não existir, use `explore`/busca normal.
3. Para documentação de biblioteca, use `docs-lookup` ou Context7.

### Quero criar uma feature

1. Use `brainstorming` para entender objetivo e restrições.
2. Use `writing-plans` para plano executável.
3. Use `test-driven-development` na implementação.
4. Use `requesting-code-review` e `verification-before-completion` antes de dizer pronto.

### Quero corrigir bug

1. Use `systematic-debugging`.
2. Reproduza o erro.
3. Ache causa raiz antes de corrigir.
4. Crie teste falhando se possível.
5. Corrija e verifique.

### Quero mexer em UI

1. Use `impeccable` para direção geral de frontend.
2. Use `ccg-frontend-design` se quiser a stack CCG de design.
3. Escolha skills específicas: `ccg-typeset` para tipografia, `ccg-arrange` para layout, `ccg-colorize` para cor, `ccg-polish` para acabamento.
4. Use `ccg-adapt` para mobile/responsivo.
5. Use `ccg-audit` antes de entregar.

### Quero revisar segurança

1. Para código geral sensível, use `ecc-security-review` ou `security-reviewer`.
2. Para scan CCG rápido, use `ccg-verify-security`.
3. Para frameworks específicos, use `ecc-laravel-security`, `ecc-django-security`, `ecc-springboot-security` ou `ecc-quarkus-security`.
4. Para bug bounty, use `ecc-security-bounty-hunter`.

### Quero trabalhar com banco de dados

1. Use `ecc-database-migrations` para migrations.
2. Use `ecc-postgres-patterns`, `ecc-mysql-patterns`, `ecc-prisma-patterns` ou `ecc-clickhouse-io` conforme stack.
3. Valide rollback e impacto em produção.

### Quero preparar entrega

1. Rode testes ou verificação apropriada.
2. Use `verification-before-completion`.
3. Use `requesting-code-review` se houve mudança relevante.
4. Use `finishing-a-development-branch` se for fechar branch/PR.

## Manutenção E Cuidados

- Reinicie `opencode-web.service` depois de mudar config, plugins, agents, commands ou skills.
- Não reintroduza roots duplicados como `superpowers/skills` em `skills.paths`; as cópias top-level já estão em `skills/`.
- Não use `~/.agents/skills` nem `~/.claude/skills` como fonte principal do OpenCode global desta máquina.
- CCG usa prefixo `ccg-*`; não use `ccg:` como nome de skill.
- ECC usa prefixo `ecc-*`.
- OpenCode exige que `name` da skill bata com o diretório pai do `SKILL.md`.
- Se `opencode debug skill --print-logs` mostrar `duplicate skill name`, corrija antes de considerar o setup limpo.

## Verificações Úteis

```bash
opencode debug skill --print-logs
systemctl --user status opencode-web.service --no-pager
systemctl --user restart opencode-web.service
/home/coringawc/.config/opencode/openspec/bin/openspec --version
```

Resultado esperado atual:

- `opencode debug skill --print-logs` sem avisos de duplicata.
- `service=skill count=118` no log.
- `opencode-web.service` ativo em `0.0.0.0:4096`.
