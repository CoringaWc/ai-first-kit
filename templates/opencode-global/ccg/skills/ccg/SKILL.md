---
name: ccg-skills
description: "CCG: Use para o pacote CCG de quality gates, gerador de documentação e orquestração multiagente."
license: MIT
user-invocable: false
disable-model-invocation: false
---

# CCG Skills

## Directory Structure

```
skills/
├── tools/            # Quality gate tools
│   ├── verify-security/   # Security vulnerability scanning
│   ├── verify-quality/    # Code quality checking
│   ├── verify-change/     # Change analysis & doc sync
│   ├── verify-module/     # Module completeness validation
│   ├── gen-docs/          # README.md & DESIGN.md generator
│   └── lib/               # Shared utilities
├── orchestration/    # Multi-agent coordination
│   └── multi-agent/       # Ant colony-inspired coordination
├── run_skill.js      # Unified skill runner
└── SKILL.md          # This file
```

## Quick Navigation

| Category | Description | Entry |
|----------|-------------|-------|
| **Quality Gates** | Module completeness, security, quality, change validation | [Quality Gates](#quality-gates) |
| **Multi-Agent** | Multi-agent coordination and task decomposition | [Multi-Agent](#multi-agent-orchestration) |

---

## Quality Gates

**Mandatory quality checkpoints to ensure deliverable standards.**

| Skill | Trigger | Description |
|-------|---------|-------------|
| `ccg-verify-module` | New module completed | Module structure & documentation completeness |
| `ccg-verify-security` | New module / security changes / refactoring | Security vulnerability scanning |
| `ccg-verify-change` | Design-level changes / refactoring | Document sync & change impact analysis |
| `ccg-verify-quality` | Complex modules / refactoring | Code quality metrics checking |
| `ccg-gen-docs` | New module created | README.md & DESIGN.md skeleton generator |

### Auto-trigger Rules

```
New module:     /gen-docs → develop → /verify-module → /verify-security
Code changes:   develop → /verify-change → /verify-quality
Security tasks: execute → /verify-security
Refactoring:    refactor → /verify-change → /verify-quality → /verify-security
```

### Running Skills

```bash
# Unified runner
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js <skill-name> [args...]

# Examples
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js ccg-verify-security ./src
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js ccg-verify-quality ./src -v
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js ccg-verify-change --mode staged
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js ccg-verify-module ./my-module
node /home/coringawc/.config/opencode/ccg/skills/ccg/run_skill.js ccg-gen-docs ./new-module --force
```

---

## Multi-Agent Orchestration

| Skill | Trigger | Description |
|-------|---------|-------------|
| `multi-agent` | TeamCreate, parallel tasks, multi-agent | Ant colony-inspired multi-agent coordination |

Provides:
- Agent role system (Lead/Scout/Worker/Soldier/Drone)
- Pheromone-based indirect communication
- File ownership locking & conflict avoidance
- Adaptive concurrency control
- TeamCreate vs single-agent decision tree

---

## Installed by CCG

These skills are automatically installed during `npx ccg-workflow` initialization.
To update: run `npx ccg-workflow update` or `npx ccg-workflow` again.
