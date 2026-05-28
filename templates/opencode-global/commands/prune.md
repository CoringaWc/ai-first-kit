---
name: prune
description: "Continuous Learning: Remove instincts pendentes antigos que nunca foram promovidos."
command: true
---

# Prune Pending Instincts

Remove expired pending instincts that were auto-generated but never reviewed or promoted.

## Implementation

Run the instinct CLI from the OpenCode skill installation:

```bash
python3 /home/coringawc/.config/opencode/ecc/skills/ecc/ecc-continuous-learning-v2/scripts/instinct-cli.py prune $ARGUMENTS
```

## Usage

```
/prune                    # Delete instincts older than 30 days
/prune --max-age 60      # Custom age threshold (days)
/prune --dry-run         # Preview without deleting
```
