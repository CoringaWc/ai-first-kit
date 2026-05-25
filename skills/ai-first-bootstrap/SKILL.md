---
name: ai-first-bootstrap
description: Prepare the host (Ubuntu/Debian/WSL) for AI-first development by installing required tools and the ai-first-kit globally. Use when the user wants to "set up ai-first", "install the kit", "bootstrap opencode", or runs scripts/bootstrap.sh.
---

# ai-first-bootstrap

> Status: skeleton. Implementation lives in `scripts/bootstrap.sh`; this skill documents the contract and will hold the interactive logic in a later plan.

## Contract

- Idempotent: re-running the bootstrap must not break a healthy install.
- Interactive by default; honors `AFK_NONINTERACTIVE=1` for CI with safe defaults.
- Supported hosts: Ubuntu, Debian, WSL Ubuntu. Other OSes exit with a clear message.

## TODO

- Implement MCP merge logic (separate plan).
- Implement external skill sync via `npx skills add` (separate plan).
