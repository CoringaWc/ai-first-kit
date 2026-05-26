# Smoke Runner — Containerized E2E harness for the skill kit

## What this is

A reproducible smoke-test harness that exercises the `_shared/` skill kit end-to-end
(skills A1→A8 of Group A), validates idempotency, and boots the resulting Laravel
+ Filament stack with a real `vendor/bin/sail up --build`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  HOST                                                           │
│                                                                 │
│  ./run.sh ──┬─ docker build smoke-runner:latest                 │
│             │                                                   │
│             └─ docker run smoke-runner ──┐                      │
│                                          │                      │
│  /tmp/smoke-runner  ◄──── same path ─────┤  (bind, rw)          │
│  /tmp/smoke-runner  ◄──── /work alias ───┤  (bind, rw)          │
│  /tmp/smoke-out     ◄──── /out  ─────────┤  (bind, rw)          │
│  $REPO/.agents/skills/_shared ─► /kit:ro ┤  (bind, ro)          │
│  /var/run/docker.sock     ◄─────── same ─┘  (talk to host dckr) │
│                                                                 │
│  ┌── HARNESS container (smoke-runner) ──────────────────────┐   │
│  │  scenario script:                                         │  │
│  │   • cp /kit  →  /work/<project>/.agents/skills/_shared    │  │
│  │   • composer create-project laravel/laravel               │  │
│  │   • extract bash from each SKILL.md Workflow, run it      │  │
│  │   • vendor/bin/sail up -d --build   (host docker daemon!) │  │
│  │   • docker exec <app> curl -k https://nginx/up            │  │
│  │   • sail down -v                                           │  │
│  │   • idempotency check (run skills again, diff tree)       │  │
│  │   • write /out/<scenario>-report.md                       │  │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Sail containers (app, pgsql, redis, nginx, ...) run on the HOST │
│  daemon, NOT inside the harness. They mount /tmp/smoke-runner/   │
│  <project>/ because the harness also creates projects at that    │
│  exact absolute path. `/work` is only an alias for compatibility. │
└──────────────────────────────────────────────────────────────────┘
```

### Why the workdir is mounted twice

When the harness runs `vendor/bin/sail up`, Compose reads `docker-compose.yml`
volumes (`.:/var/www/html`) and resolves `.` against the **host** Docker daemon's
filesystem. The path must therefore be identical inside the harness and on the
host. The harness writes to `/tmp/smoke-runner/<project>` by default, and that
same absolute path is bind-mounted inside the harness. `/work` is mounted to the
same host directory as a short alias for artifacts and shell debugging.

## Prerequisites

- Docker Engine 24+ on the host
- Current user must be in the `docker` group (or run `./run.sh` as root)
- Free disk: ~5 GB for a full scenario (Laravel skeleton + node_modules + images)

## Quick start

```bash
cd .agents/skills/_shared/_helpers/smoke-runner
./run.sh --list-scenarios
./run.sh --scenario=group-a-fpm-ptbr
cat /tmp/smoke-out/group-a-fpm-ptbr-report.md
```

## Scenarios

| Name                  | Profile    | Locale | A6                  |
| --------------------- | ---------- | ------ | ------------------- |
| `group-a-fpm-ptbr`    | fpm        | pt_BR  | skipped (opt-in)    |
| `group-a-octane-en`   | octane     | en     | n/a (octane base)   |
| `group-a-fpm-then-a6` | fpm→octane | pt_BR  | invoked (migration) |

## CLI

```
./run.sh [OPTIONS]
  --scenario=<name>      pick scenario (default: group-a-fpm-ptbr)
  --keep-artifacts       tar the project dir to /tmp/smoke-out/<scenario>-artifacts.tar.gz
  --no-cache             docker build --no-cache
  --shell                drop into bash inside the harness (debugging)
  --list-scenarios       list and exit
  --clean                wipe scoped smoke-group-a-* Docker resources plus work/out dirs, then exit
  --help

Exit codes:
  0   all stages passed
  1   a scenario stage failed (see report)
  2   harness setup error (build, mount, missing scenario, docker unreachable)
```

## Environment knobs (host side, exported to harness)

| Var                 | Default               | Effect                                          |
| ------------------- | --------------------- | ----------------------------------------------- |
| `SMOKE_WORK_DIR`    | `/tmp/smoke-runner`   | Host path bind-mounted to `/work` (must match!) |
| `SMOKE_OUT_DIR`     | `/tmp/smoke-out`      | Reports + artifacts land here                   |
| `SMOKE_IMAGE_TAG`   | `smoke-runner:latest` | Image tag for harness                           |
| `SMOKE_SKIP_BOOT=1` | unset                 | Skip Stage 9 (sail up); fast harness debug      |
| `SMOKE_SKIP_IDEM=1` | unset                 | Skip Stage 10 (idempotency re-run)              |

## Debugging a failure

1. Reproduce with artifacts kept:
   ```bash
   ./run.sh --scenario=group-a-fpm-ptbr --keep-artifacts
   ```
2. Open the report: `/tmp/smoke-out/<scenario>-report.md`
3. Inspect the project tree the scenario produced:
   ```bash
   tar tzf /tmp/smoke-out/<scenario>-artifacts.tar.gz | head -50
   ```
4. Drop into a harness shell at the same project state:
   ```bash
   ./run.sh --shell
   cd /work/<scenario>-<timestamp>
   ```
5. Re-run a single SKILL.md workflow block from inside the harness:
   ```bash
   source /harness/lib/extract.sh
   extract_workflow_bash .agents/skills/_shared/docker-stack-fpm/SKILL.md | less
   ```

## What the harness does NOT do

- Does not validate skill SKILL.md *structure* — that's `_helpers/verify-skill.sh`.
- Does not simulate the OpenCode `Skill` tool dispatch chain. It mechanically
  extracts bash blocks from each skill's Workflow section and runs them in order,
  with the same env vars (`LOCALE_SHORT`, `PROFILE`, …) a real run would have.
- Does not assert UI behavior — only that the stack boots and `/up` returns 200/302.

## Cleanup

Scenarios drop their own compose stack on exit. Prefer the scoped cleaner:

```bash
.agents/skills/_shared/_helpers/smoke-runner/run.sh --clean
```

It only targets this harness' `smoke-group-a-*` resources and keeps the Composer cache.

## Files

```
.
├── Dockerfile             # PHP 8.4 + composer + node 22 + docker-cli + python3-yaml
├── run.sh                 # host CLI
├── runner-entrypoint.sh   # container entrypoint, dispatches scenarios
├── README.md              # this file
├── lib/
│   ├── assert.sh          # assert_file, assert_grep, snapshot_tree, assert_idempotent
│   ├── extract.sh         # extract_workflow_bash (python3-backed)
│   └── report.sh          # markdown report builder
└── scenarios/
    ├── group-a-fpm-ptbr.sh
    ├── group-a-octane-en.sh
    └── group-a-fpm-then-a6.sh
```
