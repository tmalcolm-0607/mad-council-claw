# MAD.Council Scripts

Shared plugin-level PowerShell scripts reused across the 10 `/council-*` skills. Lives at `MAD/scripts/` per the "shared plugin-level scripts" pattern from `plugins/zen-agents/scripts/` (marketplace CHECKLIST pattern #102).

**Why plugin-level shared scripts** (not per-skill):

- **DRY at plugin scope.** Five skills need atomic JSON write; one helper covers all.
- **Consistency.** Every skill uses the same seq-increment retry logic, preventing subtle bugs from divergent implementations.
- **Testability.** Helpers are independently unit-testable; skills focus on orchestration.
- **Single source of truth for invariants.** Concurrency rules, literal-phrase ban list, etc. live in one file — edits propagate to all callers.

## Inventory

### Core helpers (cited by most skills)

| Script | Purpose | Cited by |
|---|---|---|
| `atomic-write.ps1` | Atomic JSON write: `.tmp` + rename. Used for every mutable state file. | every skill |
| `channel-helpers.ps1` | Read channel.json, find member by session_id, verify membership, member-update helpers. | every skill |
| `seq-increment.ps1` | Read-inc-write with retry-on-collision for seq.json. | /council-post, /council-resolve |
| `digest-rebuild.ps1` | Recompute digest.json from thread directory scan. | /council-post, /council-leave |
| `preflight.ps1` | Run preflight dependency probes (fs writable, CronCreate, clock, A2A, MAD). | /council-open, /council-join |
| `completion-report.ps1` | Scan channel threads + messages + verdicts; build structured Completion Report. | /council-leave |

### Supporting helpers

| Script | Purpose | Cited by |
|---|---|---|
| `check-mad-links.ps1` | Walks `MAD/**/*.md`; verifies internal cross-refs (`rules/`, `wiki/`, `skills/`, `scripts/`, `evals/`, `metrics/`, `agents/`, `plans/`, `schemas/`, `operations/`) resolve. **Additionally enforces (ADOPT-025)** the `rules/_status-convention.md` frontmatter on `rules/*.md`, `wiki/patterns/*.md`, `wiki/implementations/*.md` — missing `status:` or invalid enum value → non-zero exit. | Layer-0 CI gate |
| `literal-phrase-scan.ps1` | Scan text against Rule-1 ban list (prompt-injection-policy). | /council-post, /council-check, /council-retro, /council-review |
| `context-gaps-reporter.ps1` | Format Context Gaps as a markdown table. | /council-check, /council-list |
| `slugify.ps1` | Convert thread title → thread-id (lowercase, hyphens, collision-suffix). | /council-post |
| `validate-agent-card.ps1` | Validate A2A Agent Card JSON schema. | /council-open, /council-join |
| `archive-channel.ps1` | Atomic directory rename (channel → archive). | /council-leave |
| `mad-tasks-checkoff.ps1` | Parse `[T###]` patterns + update tasks.md checkboxes. | /council-resolve |
| `yagni-filter.ps1` | Grep for callers of proposed symbol; demote finding severity if none. | /council-review |
| `pattern-verify.ps1` | Detect if a "deviation from pattern" is actually an improvement. | /council-review |
| `verdict-compute.ps1` | Severity-threshold + mechanical-ESCALATE verdict computation. | /council-review |

### Templates

`MAD/scripts/mad-templates/` contains starter stubs for MAD artifacts initialized by `/council-open --mad`:

- `spec.md` — spec artifact template (FR-IDs, NEEDS_CLARIFICATION markers, success criteria).
- `plan.md` — plan artifact template (Phase 0 research, Phase 1 contracts, Phase 2 impl, Phase 3 verify).
- `tasks.md` — tasks artifact template (empty; tier auto-detected on first task post).

## Conventions

1. **Atomic writes everywhere.** All mutable state writes go through `atomic-write.ps1`. No direct `Set-Content` in skill code.
2. **PowerShell 7+.** All scripts target pwsh 7+ (not Windows PowerShell 5.1). Cross-platform.
3. **Error surface.** Scripts throw on unrecoverable errors. Skills wrap in try/catch and translate to skill-level rc codes.
4. **No side effects in validation-only scripts.** `validate-agent-card.ps1`, `yagni-filter.ps1` etc. are pure — they READ and RETURN, never write.
5. **Output format.** Scripts that produce structured data return PSCustomObject or JSON strings. Avoid PowerShell object-pipeline surprises.
6. **Logging.** Verbose logging via `Write-Verbose`. Errors via `Write-Error`. Skills decide what to surface to user.

## Testing conventions

Each script has a sibling `*.Tests.ps1` in `MAD/evals/fixtures/scripts/` (future iter). Pester-based. Covers:

- Happy path.
- Error paths (file not found, parse error, permission denied).
- Edge cases specific to the script's invariants (e.g., seq-increment collision retry; atomic-write interrupted mid-rename).
- Concurrency where applicable (e.g., two seq-increment callers racing).

## Migration from placeholder to real implementation

Every script ships as a **stub** with:
- Full contract header (SYNOPSIS / DESCRIPTION / PARAMETER / OUTPUTS / NOTES).
- A `throw "NOT YET IMPLEMENTED"` as the body.

This lets:
- Skill SKILL.md files reference real file paths today.
- Test fixtures stub the helper with known-good responses.
- Implementation proceed incrementally without breaking links.

As each helper is implemented:
1. Replace stub body with real code.
2. Ensure contract match (parameter names, return types).
3. Add Pester tests.
4. Update this README to mark as `✅ IMPLEMENTED`.

Current status (2026-04-17):

| Script | Status |
|---|---|
| All scripts | 📝 SPEC ONLY (stubs) — implementation tracked per-file |

## Coding conventions

- Functions over scripts-as-entry-points: each `.ps1` defines 1-3 functions, exported via `Export-ModuleMember` when converted to a module.
- Named parameters always; no positional.
- `[CmdletBinding()]` on every function for `-Verbose` / `-Debug` standard flags.
- `-Confirm` / `-WhatIf` for destructive operations (via `SupportsShouldProcess`).
- `Set-StrictMode -Version Latest` at the top of every script.

## Related

- `rules/concurrency-safety.md` — the atomic-write / read-inc-write invariants these scripts enforce.
- `rules/prompt-injection-policy.md` — literal-phrase-scan.ps1 enforces Rule 1.
- `wiki/patterns/state-file-coordination.md` — underlying pattern.
- Every skill's `plan.md` — cites these scripts by name.
