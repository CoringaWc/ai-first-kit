---
description: "Continuous Learning: Mostra instincts aprendidos do projeto e globais com confianca."
agent: build
---

# Instinct Status Command

Show instinct status from continuous-learning-v2: $ARGUMENTS

## Your Task

Run the instinct CLI from the OpenCode ECC skill installation:

```bash
python3 /home/coringawc/.config/opencode/ecc/skills/ecc/ecc-continuous-learning-v2/scripts/instinct-cli.py status
```

## Behavior Notes

- Output includes both project-scoped and global instincts.
- Project instincts override global instincts when IDs conflict.
- Output is grouped by domain with confidence bars.
- This command does not support extra filters in v2.1.
