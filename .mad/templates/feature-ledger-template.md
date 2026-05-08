---
artifact-class: template
template-for: feature-ledger
generated-by: hand-authored
last-updated: 2026-05-06
notes: |
  This file is itself a TEMPLATE, not a feature-ledger artifact. The frontmatter
  shape below — starting at the line "BEGIN FEATURE LEDGER TEMPLATE BODY" — is
  what `/feature-lock --create` writes literally to `specs/<N>/features/F-NNN-<slug>.md`,
  with placeholder tokens (e.g. `<ISO-8601>`, `<F-NNN>`, `<slug>`) substituted.

  Substitution tokens used by `/feature-lock --create`:
    <SESSION-ID>           value of .mad/scratch/mad-pipeline-active.json:session_id at write time
    <F-NNN>                feature ID, e.g. F-001
    <SLUG>                 kebab-case short slug, e.g. engine-bootstrap-loop
    <ISO-8601>             current UTC time in ISO-8601 (e.g. 2026-05-06T14:30:00Z)
    <FEATURE-VERSION>      generated-by-version for the /feature-lock skill (e.g. 1.0.0)
    <PROVENANCE-SURFACES>  comma-separated --provenance arg from CLI, one per line
    <FR-COVERAGE>          comma-separated --fr-coverage arg from CLI, one per line
    <DEPENDS-ON>           comma-separated --depends-on arg from CLI, one per line
    <TITLE>                human-readable title; defaults to slug with title-case if not provided
    <BEHAVIOR-CONTRACT>    body sentences passed via --behavior-contract; placeholder if absent
---

# Feature ledger template

This file documents the literal body that `/feature-lock --create` writes when authoring a new `specs/<N>/features/F-NNN-<slug>.md` artifact. The body below — between the BEGIN and END markers — is the literal template; tokens like `<F-NNN>`, `<SLUG>`, `<ISO-8601>` are substituted at write time by the skill body.

The template is hand-authored here. The skill is NOT yet implemented — it is a separate Wave 1A stream. Until the skill exists, F-NNN files written by hand follow the same shape (see `specs/15-nested-quilt/features/F-001-engine-bootstrap-loop.md` for a worked example).

---

<!-- BEGIN FEATURE LEDGER TEMPLATE BODY -->

```markdown
---
artifact-class: feature-ledger
generated-by: /feature-lock
generated-by-version: <FEATURE-VERSION>
skill-state-file-id: <SESSION-ID>
feature-id: <F-NNN>
short-slug: <SLUG>
status: red
status-since: <ISO-8601>
status-history:
  - status: red
    at: <ISO-8601>
    by: /feature-lock
    note: "Initial creation; tests authored, no implementation."
provenance:
  surfaces:
<PROVENANCE-SURFACES>
fr-coverage:
<FR-COVERAGE>
test-files:
  unit:
    - tests/unit/<F-NNN>-<SLUG>.test.ts
  node: []
  browser: []
  integration:
    - tests/integration/<F-NNN>-<SLUG>.integration.test.ts
  e2e: []
test-runner-projects:
  - unit
  - integration
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/<F-NNN>-<SLUG>-review.md exists with verdict: ACCEPT.
depends-on:
<DEPENDS-ON>
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md: every adjacent surface this feature
  does NOT cover is either (a) tracked by another F-NNN feature (linked) or
  (b) acknowledged in surface-map.md drops appendix.
---

# <F-NNN> — <TITLE>

## Behavior contract

<BEHAVIOR-CONTRACT>

## Acceptance scenarios

1. **Given** <preconditions>, **When** <action>, **Then** <observable outcome>. (maps to `<F-NNN> scenario 1` in `tests/unit/<F-NNN>-<SLUG>.test.ts`)
2. **Given** <preconditions>, **When** <action>, **Then** <observable outcome>. (maps to `<F-NNN> scenario 2`)
3. **Given** <edge-case preconditions>, **When** <action>, **Then** <expected error/edge behavior>. (maps to `<F-NNN> scenario 3` in `tests/integration/<F-NNN>-<SLUG>.integration.test.ts`)

Each scenario maps 1:1 to a named `test()` / `it()` in the files listed under `test-files:`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/unit/<F-NNN>-<SLUG>.test.ts` | `unit` | RED — assertion fails, no impl | scenario 1, 2 |
| `tests/integration/<F-NNN>-<SLUG>.integration.test.ts` | `integration` | RED — assertion fails, no impl | scenario 3 |

Protocol:
1. Test file exists day 0; MUST initially fail. `Run-FeatureEval.ps1` (Wave 1B) confirms RED.
2. Implementation in separate commit/PR.
3. Test runs GREEN; `Run-FeatureEval.ps1 -UpdateLedger` invokes `/feature-lock --transition green` and appends `status-history` entry.
4. LOCKED requires `reviews/<F-NNN>-<SLUG>-review.md` with `verdict: ACCEPT`; transition is human-decided, never auto-promoted.

## Dependencies

- **Hard** (must be GREEN before this feature's GREEN is meaningful): <DEPENDS-ON list>
- **Soft** (parallel-ok, but won't run end-to-end without): <derived from depends-on graph by Run-FeatureEval.ps1>
- **Independent**: n/a

## Out of scope

Each item: classified, never silently dropped (per `.claude/rules/no-silent-deferrals.md`).

- <surface-id> — owned by F-MMM (linked when allocated)
- <surface-id> — acknowledged drop in `../surface-map.md` row <id>

## Surface trace

| surface-id | what it contributes |
|---|---|
| <kit-surface-id> | <one-line contribution> |
| <ce-surface-id> | <one-line contribution> |
| <cp-surface-id> | <one-line contribution> |

## Implementation notes

(Populated as feature is implemented; not required for RED state.)
```

<!-- END FEATURE LEDGER TEMPLATE BODY -->

---

## Substitution rules

The skill body for `/feature-lock --create` MUST substitute the placeholder tokens listed in the frontmatter above. Token substitution happens at write time, NOT at template-load time. The template file itself is the contract; the skill must re-read it on every invocation so changes to the template propagate without skill redeploy.

### Multi-line substitutions

`<PROVENANCE-SURFACES>`, `<FR-COVERAGE>`, and `<DEPENDS-ON>` are multi-line YAML list bodies. The skill MUST emit each item indented as a YAML list item (4-space indent, `- ` prefix). Example for `<PROVENANCE-SURFACES>` if the CLI passes `--provenance kit:mad-pipeline,ce:US-1,cp:background-service`:

```yaml
provenance:
  surfaces:
    - kit:mad-pipeline
    - ce:US-1
    - cp:background-service
```

Empty multi-line tokens emit as `[]` (the `<DEPENDS-ON>` of an F-001 with no upstream deps becomes `depends-on: []`).

### Validation

Before write, `/feature-lock --create` MUST validate:

1. Every `surface-id` in `<PROVENANCE-SURFACES>` corresponds to a row in `../surface-map.md`. Missing surface → reject with exit code `MISSING_SURFACE_ID`.
2. Every `FR-X-NNN` in `<FR-COVERAGE>` exists in `../spec.md` (when spec.md exists). Missing FR → reject with exit code `MISSING_FR_ID`.
3. Every `F-MMM` in `<DEPENDS-ON>` corresponds to an existing `../features/F-MMM-*.md` file. Missing dep → reject with exit code `MISSING_DEPENDENCY`.
4. The target path `../features/<F-NNN>-<SLUG>.md` does NOT already exist. Existing file → reject with exit code `FEATURE_ID_TAKEN`.

### Frontmatter signature

The 3-key canonical signature (`generated-by: /feature-lock`, `generated-by-version: <semver>`, `skill-state-file-id: <session-id>`) is required by `.claude/rules/canonical-artifact-frontmatter.md` and enforced by `enforce-skill-canonical-marker.js` (extended in Wave 1A's separate hook stream). The skill body MUST set these three keys before any other content.

---

## Related files

- `specs/15-nested-quilt/features/README.md` — schema documentation in prose
- `specs/15-nested-quilt/features/F-001-engine-bootstrap-loop.md` — worked example in RED state
- `specs/15-nested-quilt/surface-map.md` — input for `<PROVENANCE-SURFACES>` validation
- `.claude/rules/canonical-artifact-frontmatter.md` — the 3-key signature contract this template enforces
- `.claude/skills/feature-lock/SKILL.md` — (Wave 1A separate stream — does not exist yet) the consumer of this template
- `.mad/scripts/Run-FeatureEval.ps1` — (Wave 1B — does not exist yet) the script that drives RED→GREEN transitions

> **TODO** — when `.claude/skills/feature-lock/SKILL.md` lands, this template's `<FEATURE-VERSION>` token will be the skill's `generated-by-version` value (read from skill frontmatter). Until then, hand-authored examples like `F-001-engine-bootstrap-loop.md` use a placeholder `pending-feature-lock-skill-2026-05-06` for `skill-state-file-id` and `1.0.0` for `generated-by-version`.
