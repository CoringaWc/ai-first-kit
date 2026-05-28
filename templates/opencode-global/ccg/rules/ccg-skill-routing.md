# CCG Domain Knowledge — Auto-routing Rules

When the user's request matches trigger keywords below, automatically READ the corresponding skill file to gain domain expertise before responding. These knowledge files are installed at `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/`.

**IMPORTANT**: Read the skill file FIRST, then respond. Do NOT fabricate domain knowledge from training data when a skill file exists.

## Security Domain (`domains/security/`) — NOT installed by default

> Security domain files contain red team/pentest reference content that may trigger antivirus false positives.
> They are NOT installed by default. To enable, manually copy from the npm package:
> `cp -r $(npm root -g)/ccg-workflow/templates/skills/domains/security/ /home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/`

| Trigger Keywords | Skill File | Description |
|------------------|-----------|-------------|
| pentest, red team, exploit, C2, lateral movement, privilege escalation, evasion, persistence | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/red-team.md` | Red team attack techniques |
| blue team, alert, IOC, incident response, forensics, SIEM, EDR, containment | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/blue-team.md` | Blue team defense & incident response |
| web pentest, API security, OWASP, SQLi, XSS, SSRF, RCE, injection | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/pentest.md` | Web & API penetration testing |
| code audit, dangerous function, taint analysis, sink, source | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/code-audit.md` | Source code security audit |
| binary, reversing, PWN, fuzzing, stack overflow, heap overflow, ROP | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/vuln-research.md` | Vulnerability research & exploitation |
| OSINT, threat intelligence, threat modeling, ATT&CK, threat hunting | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/security/threat-intel.md` | Threat intelligence & OSINT |

## Architecture Domain (`domains/architecture/`)

| Trigger Keywords | Skill File |
|------------------|-----------|
| API design, REST, GraphQL, gRPC, endpoint, versioning | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-architecture/api-design.md` |
| caching, Redis, Memcached, cache invalidation, CDN | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-architecture/caching.md` |
| cloud native, Kubernetes, Docker, microservice, service mesh | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-architecture/cloud-native.md` |
| message queue, Kafka, RabbitMQ, event driven, pub/sub | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-architecture/message-queue.md` |
| security architecture, zero trust, defense in depth, IAM | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-architecture/security-arch.md` |

## AI / MLOps Domain (`domains/ai/`)

| Trigger Keywords | Skill File |
|------------------|-----------|
| RAG, retrieval augmented, vector database, embedding, chunking | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-ai/rag-system.md` |
| AI agent, tool use, function calling, agent framework, orchestration | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-ai/agent-dev.md` |
| LLM security, prompt injection, jailbreak, guardrail | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-ai/llm-security.md` |
| prompt engineering, model evaluation, benchmark, fine-tuning | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-ai/prompt-and-eval.md` |

## DevOps Domain (`domains/devops/`)

| Trigger Keywords | Skill File |
|------------------|-----------|
| Git workflow, branching strategy, trunk-based, GitFlow | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/git-workflow.md` |
| testing strategy, unit test, integration test, e2e, test pyramid | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/testing.md` |
| database, migration, schema design, indexing, query optimization | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/database.md` |
| performance, profiling, load test, latency, throughput | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/performance.md` |
| observability, logging, tracing, metrics, Prometheus, Grafana | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/observability.md` |
| DevSecOps, CI security, SAST, DAST, supply chain | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/devsecops.md` |
| cost optimization, cloud cost, FinOps, resource right-sizing | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-devops/cost-optimization.md` |

## Development Domain (`domains/development/`)

When the user is working with a specific programming language, read the corresponding skill file for language-specific best practices:

| Language | Skill File |
|----------|-----------|
| Python | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/python.md` |
| Go | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/go.md` |
| Rust | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/rust.md` |
| TypeScript / JavaScript | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/typescript.md` |
| Java / Kotlin | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/java.md` |
| C / C++ | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/cpp.md` |
| Shell / Bash | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-development/shell.md` |

## Frontend Design Domain (`domains/frontend-design/`)

| Trigger Keywords | Skill File |
|------------------|-----------|
| UI aesthetics, visual design, color theory, layout | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ui-aesthetics.md` |
| UX principles, usability, user flow, information architecture | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ux-principles.md` |
| component patterns, design system, atomic design | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/component-patterns.md` |
| state management, Redux, Zustand, Pinia, context | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/state-management.md` |
| frontend engineering, build tool, bundler, SSR, SSG | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/engineering.md` |
| ccg-claymorphism | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ccg-claymorphism/SKILL.md` |
| ccg-glassmorphism | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ccg-glassmorphism/SKILL.md` |
| liquid glass | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ccg-liquid-glass/SKILL.md` |
| ccg-neubrutalism | `/home/coringawc/.config/opencode/ccg/skills/ccg/domains/ccg-frontend-design/ccg-neubrutalism/SKILL.md` |

## Routing Rules

1. **Keyword match is fuzzy** — match on intent, not exact string. "How to do SQL injection testing" triggers `pentest.md`.
2. **Multiple matches** — if a request spans two domains, read both skill files.
3. **Language detection** — automatically detect the programming language from file extensions or context, then read the corresponding development skill.
4. **Read once per conversation** — no need to re-read the same skill file within the same conversation.
5. **Skill files are authoritative** — when a skill file contradicts training data, the skill file wins.
