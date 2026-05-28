---
description: "Continuous Learning: Analisa instincts e sugere ou gera estruturas evoluidas."
agent: build
---

# Evolve Command

Analyze and evolve instincts in continuous-learning-v2: $ARGUMENTS

## Your Task

Run the instinct CLI from the OpenCode ECC skill installation:

```bash
python3 /home/coringawc/.config/opencode/ecc/skills/ecc/ecc-continuous-learning-v2/scripts/instinct-cli.py evolve $ARGUMENTS
```

## Supported Args (v2.1)

- no args: analysis only
- `--generate`: also generate files under `evolved/{skills,commands,agents}`

## Behavior Notes

- Uses project + global instincts for analysis.
- Shows skill/command/agent candidates from trigger and domain clustering.
- Shows project -> global promotion candidates.
- With `--generate`, output path is:
  - project context: `~/.config/opencode/homunculus/projects/<project-id>/evolved/`
  - global fallback: `~/.config/opencode/homunculus/evolved/`
