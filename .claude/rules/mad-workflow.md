# MAD Workflow

```
/mad-spec (→ /mad-testplan --source spec auto)
  → /mad-plan → /mad-tasks → /mad-analyze → /mad-implement → /mad-validate → /apply-learnings
```

For full automation: `/mad-full`
For parallel: `/mad-decompose` → `/mad-parallel`

## Review Gates

Automatic domain reviews run after `spec`, `plan`, `tasks`, `implement`, and `decompose` phases.
See `rules/review-gate-protocol.md`.

- Disable globally: `AUTO_REVIEW_ENABLED=false`
- Disable per-phase via env vars
- Skip once: pass `--skip-review` to any skill

## Planning-document Convention

Always use MAD format (`idea.md`) for planning documents unless explicitly told otherwise.

## Work-item Layout

Two canonical locations:

- `specs/<N>-<feature>/` — authoritative feature artifacts: `spec.md`, `plan.md`, `tasks.md`, `research.md`, `analysis-report.md`, `test-plan.md`, `data-model.md`, `checklists/`, `contracts/`
- `work-items/<WI-ID>/` — agent artifacts (implementation reports, scratch, intermediate state)

See `rules/artifact-placement.md` for the full placement policy.

## Work-item ID Format

`WI-YYYYMMDD-HHMM-<kebab-slug>` — regex `^WI-[0-9]{8}-[0-9]{4}-[a-z0-9-]+$`.

Example: `WI-20260418-0830-port-production-patterns`.

See `schemas/hash-manifest.md` for the canonical format.
