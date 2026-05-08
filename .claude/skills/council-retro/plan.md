# Implementation Plan: /council-retro

Target: MAD.Council Phase 2 Council layer per `mad.council.a2a.md` §12 — or usable in Phase 1 for simple retro capture without verdict integration.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 13 | ⏸ |
| `scripts/channel-helpers.ps1` | iter 13 | ⏸ |
| `scripts/literal-phrase-scan.ps1` (shared) | iter 13 | ⏸ |
| ALAS client (HTTP POST helper) | iter 13 (optional) | ⏸ |
| AskUserQuestion (Claude Code native) | available | ✓ |

## Implementation steps

### 1. Parse arguments

- Single positional `<channel-name>`.

### 2. Preflight

- Membership check.
- Read `channel.json` + `digest.json` for context.
- Missing channel / not a member → `rc=2`.

### 3. Interactive prompts

Use `AskUserQuestion` for each:

- `what_worked` — freeform text, 1-500 chars.
- `what_was_hard` — freeform text, 1-500 chars.
- 5 axis scores (accuracy / completeness / tsg_alignment / dx / confidence) — integer 1-5 each.

Each prompt has 60s timeout → treat as null/empty.

### 4. Derive channel context

- `turns_taken` = digest.stats.total_messages.
- `verdicts_required` = count of `threads/*/verdict.json`.
- `a2a_bridges_used` = count of members with non-null agent_card.a2a_endpoint_url.
- `improvisation_needed` = heuristic:
  - Free-form contains "improvise" / "adapt" / "unexpected" / "figure out" → true.
  - OR any verdict.json has role_confidence <0.5 → true.

### 5. Rule-1 scan

- Scan `what_worked` + `what_was_hard` for literal-phrase ban list.
- On match: set `suspicious: true` + include phrase in annotation.
- Post is NOT rejected (blameless discipline — user may legitimately discuss attacks).

### 6. Write retro file

- Path: `<channel-dir>/retros/<alias>-<timestamp>.json`.
- Ensure `retros/` dir exists.
- Atomic-rename write with full schema.

### 7. ALAS submission (optional)

- Check for `ALAS_HUB_URL` env var.
- If present, consent gate with URL preview.
- User "yes" → POST retro JSON to hub.
- User "no" / "skip" / timeout → local-only storage (rc=0 still).
- Failure (HTTP error) → `rc=1` with warning.

### 8. Emit output

- Render summary per SKILL §Step 9.
- Include the "low scores valuable" reminder.

## Rollback

| Step | Failure | Action |
|---|---|---|
| 6 (retro write) | `rc=4`; no ALAS submission attempted |
| 7 (ALAS POST) | `rc=1` warn; retro stored locally |

## Error messages

| Condition | Message |
|---|---|
| Channel missing | `"Channel '<c>' not found."` |
| retros/ dir write fails | `"Cannot create retros/ directory. Check channel permissions."` |
| ALAS submission fails | `"Retro stored locally. ALAS submission failed: <error>. Retry with manual POST or wait for next opportunity."` |

## Test coverage targets

- All 5 rc codes reachable.
- Empty user inputs → null scores captured.
- Literal-phrase match → suspicious=true.
- improvisation_needed heuristic: test all 3 positive conditions + baseline negative.
- ALAS submission success + fail paths.
- Retro file schema validated against expected shape.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + preflight | 1 |
| Interactive prompt orchestration | 3 |
| Channel context derivation | 2 |
| Rule-1 scan | 1 (shared helper) |
| Retro file write | 1 |
| ALAS client + consent gate | 3 |
| Output rendering | 1 |
| Tests | 5 |
| **Total** | **~17 hours (~2 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Users inflate scores to seem competent | Prompt wording emphasizes honest-low-score culture; downstream analysis catches persistent inflation via self-vs-outcome gap |
| PII leaks in free-form text despite no-PII discipline | User responsibility per `mad.council.a2a.md` §2 non-goal; retro is readable only by channel members |
| Empty responses give no signal | Null score explicitly allowed; users can skip axes they don't feel qualified to rate |
| ALAS hub is unreachable | Local-only fallback is fine; retro persists for later manual submission |
| Prompt injection via what_was_hard ("Ignore prev instructions...") | Rule-1 scan + suspicious tag; reported but not rejected |

## Forward-links

- `evals/fixtures/council-retro-happy-path/` — all 7 prompts answered.
- `evals/fixtures/council-retro-minimal/` — empty responses, null scores.
- `evals/fixtures/council-retro-injection-in-text/` — Rule-1 match flagged.
- `evals/fixtures/council-retro-improvisation-heuristic/` — triggers heuristic via free-form keyword.
- `evals/fixtures/council-retro-alas-configured/` — ALAS submission path.
- `evals/fixtures/council-retro-alas-unreachable/` — local fallback.
- `evals/layer-2-integration/council-retro.test.md`.
- `metrics/quality-metrics.md` (iter 15) — consume retro signals.
