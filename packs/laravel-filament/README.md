# laravel-filament

Laravel 13 + Filament v5 + Pest + Octane/Swoole stack with production-tested skills (TDD, scaffolding, docker, CI).

Battle-tested in the **Processo Migratório TPA Fernando de Noronha** project. Skills cover the full lifecycle: project bootstrap, Filament Resources/Forms/Tables, Pest unit + feature + browser tests, native Laravel policies and Spatie permission policies, Docker FPM and Octane/Swoole stacks, larastan + pint static analysis, and a `verify-before-commit` gate.

## Skills

**Scaffolding & project setup**
- `init-project` — bootstrap a new Laravel + Filament project from this pack.
- `composer-dep-install`, `npm-dep-install` — dependency install patterns.
- `ssl-local-dev` — local HTTPS development certs.
- `docker-stack-fpm`, `docker-stack-octane-swoole` — two production docker layouts (PHP-FPM and Octane on Swoole).
- `enable-octane-swoole` — enable Octane on an existing project.
- `ci-github-actions` — GitHub Actions workflow.

**Filament v5 (Resources / Forms / Tables / Pages)**
- `filament-resource-scaffold` — create a Resource for a Model.
- `filament-schema-class` — extract Form/Table schemas into dedicated classes.
- `filament-form-component-reusable` — build reusable Form components.
- `filament-table-defaults` — table defaults (filters, search, bulk actions).
- `filament-cache-performance` — counts, badges, aggregates, and safe cache for Filament tables/resources.
- `filament-action-with-modal-heading` — action modals with proper headings.
- `filament-relation-page` — Relation pages on Resources.
- `filament-nested-resource` — nested resources pattern.
- `filament-page-with-inline-blade` — Filament Page with inline Blade view.
- `filament-repeater-create-flow` — repeater field with create flow.
- `filament-app-panel-provider-defaults` — AppPanelProvider defaults.

**Models, Migrations, Validation**
- `model-with-factory-and-seeder` — Model + Factory + Seeder in one shot.
- `migration-with-conventions` — migration naming and structure conventions.
- `form-request-validation` — FormRequest classes for validation.
- `enum-with-translations` — PHP 8.1+ Enums with i18n labels.
- `faker-realistic-ptbr` — realistic pt-BR fake data (CPF, CNPJ, addresses).
- `translation` — i18n workflow (lang/pt_BR).

**Actions & Authorization**
- `action-class` — Action class pattern (single-responsibility callable).
- `policy-native-laravel` — native Laravel Policies.
- `policy-with-spatie-permission` — Policies on top of spatie/laravel-permission.

**Testing (Pest)**
- `pest-unit-test-action` — unit tests for Action classes.
- `pest-feature-test-livewire-page` — feature tests for Livewire pages.
- `pest-feature-test-filament-resource` — feature tests for Filament Resources.
- `pest-browser-test-filament-flow` — browser tests (Pest v3 browser plugin).
- `testcase-modular` — modular TestCase organization.

**Quality gates**
- `static-analysis-larastan-pint` — larastan + pint configuration and workflow.
- `verify-before-commit` — verification gate that runs before commits.

## Internal helpers (prefixed `_`)

- `_helpers/` — shared frontmatter template, sections checklist, smoke runner, and `verify-skill.sh`. Used by skill maintenance; not invoked at agent runtime.
- `_shared/docker-base-deps.md` — base apt deps shared between FPM and Octane docker stacks.

## Usage

Selected from `ai-first-init`'s pack list (once `ai-first-init` supports pack picking). Skills under `skills/` are copied into `<project>/.agents/skills/` when a user scaffolds a project with this pack.

Until `ai-first-init` exposes a pack picker, you can adopt the pack manually:

```bash
cp -r ~/ai-first-kit/packs/laravel-filament/skills/. <your-project>/.agents/skills/
```

## Source

Skills were extracted from the `processo-migratorio-tpa-fernando-de-noronha` project where they were authored and validated against real production work.
