# OpenCode Global Snapshot

This directory is a curated mirror of the global OpenCode workflow from the
maintainer machine. It is installed by `scripts/sync-global-opencode.sh install`.

Included: `opencode.jsonc`, `AGENTS.md`, skills, commands, agents, prompts,
plugins, hooks, scripts, manifests, bundled references, CCG/ECC/GSD/OpenSpec
runtime files, and local documentation.

Excluded intentionally: `node_modules`, `node_modules-ecc`, Python bytecode,
and caches. Reinstall dependencies after copying with `npm ci` where lockfiles
exist.
