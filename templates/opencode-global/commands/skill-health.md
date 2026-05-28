---
name: skill-health
description: "ECC: Mostra saude do portfolio de skills com graficos e analises."
command: true
---

# Skill Health Dashboard

Shows a comprehensive health dashboard for all skills in the portfolio with success rate sparklines, failure pattern clustering, pending amendments, and version history.

## Implementation

Run the skill health CLI in dashboard mode:

```bash
node /home/coringawc/.config/opencode/scripts/skills-health.js --dashboard --skills-root /home/coringawc/.config/opencode/skills --imported-root /home/coringawc/.agents/skills
```

For a specific panel only:

```bash
node /home/coringawc/.config/opencode/scripts/skills-health.js --dashboard --skills-root /home/coringawc/.config/opencode/skills --imported-root /home/coringawc/.agents/skills --panel failures
```

For machine-readable output:

```bash
node /home/coringawc/.config/opencode/scripts/skills-health.js --dashboard --skills-root /home/coringawc/.config/opencode/skills --imported-root /home/coringawc/.agents/skills --json
```

## Usage

```
/skill-health                    # Full dashboard view
/skill-health --panel failures   # Only failure clustering panel
/skill-health --json             # Machine-readable JSON output
```

## What to Do

1. Run the skills-health.js script with --dashboard flag
2. Display the output to the user
3. If any skills are declining, highlight them and suggest running /evolve
4. If there are pending amendments, suggest reviewing them

## Panels

- **Success Rate (30d)** — Sparkline charts showing daily success rates per skill
- **Failure Patterns** — Clustered failure reasons with horizontal bar chart
- **Pending Amendments** — Amendment proposals awaiting review
- **Version History** — Timeline of version snapshots per skill
