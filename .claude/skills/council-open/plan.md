# Implementation Plan: /council-open

Target implementation path (MAD.Council Phase 1 — MVP, per `mad.council.a2a.md` §12).

## Dependencies (must exist before this skill can ship)

| Dependency | Where it lives | Status |
|---|---|---|
| `scripts/atomic-write.ps1` (shared helper) | `MAD/scripts/atomic-write.ps1` | ⏸ iter 10 |
| `scripts/preflight.ps1` (probe orchestrator) | `MAD/scripts/preflight.ps1` | ⏸ iter 10 |
| `scripts/channel-helpers.ps1` (channel.json/seq.json/digest.json init) | `MAD/scripts/channel-helpers.ps1` | ⏸ iter 10 |
| A2A Agent Card schema validator | new `scripts/validate-agent-card.ps1` | ⏸ iter 10 |
| MAD template stubs | `MAD/scripts/mad-templates/` (spec.md, plan.md, tasks.md) | ⏸ iter 10 |
| CHN-019 (atomic-write helper) in review checklist | closed when iter 10 ships | open |

## Implementation steps (in order)

### 1. Parse arguments

- Accept `$ARGUMENTS` string.
- Regex-match `<channel-name>` + required `"<purpose>"` + optional `--owner`, `--tier`, `--triage`, `--acceptance-criteria`, `--effort-estimate`, `--poll`, `--mad`, `--a2a`.
- Validate immediately (name regex, purpose length, poll range).
- **ADOPT-001 / -002 / -004 gates (fail fast):**
  - If `--tier prod` and `--triage` absent → `rc=PROD_TRIAGE_REQUIRED`.
  - If `--tier ci` and `--triage` absent, check for `evals/fixtures/eval-certification.json` mtime within last 1h; if missing → `rc=CI_TRIAGE_REQUIRED`.
  - If `--triage` passed and `--acceptance-criteria` absent or <10 chars → `rc=TRIAGE_MISSING_CRITERIA`.
  - If `--owner <alias>` passed and does not match the creator alias (and no multi-member init) → `rc=OWNER_NOT_MEMBER`.
- On other validation failure → `rc=2` with specific message.

### 2. Run preflight

- Call `scripts/preflight.ps1 -Context council-open -Flags @{mad=<bool>; a2a=<bool>}`.
- Preflight script returns per-dep status + overall go/no-go.
- Render report with ✅ ⚠️ ❌ per dep.
- If Required failed → stop with `rc=4`.
- Prompt: `Proceed? (yes/no)`. On "no" → `rc=5`.

### 3. Check name collision

- `Test-Path ~/claude-data/channels/<name>/` — if exists, `rc=3`.

### 4. Generate run_id

- `$run_id = [guid]::NewGuid().ToString()`.
- Store in session-scope variable for use in channel.json + CronCreate prompt.

### 5. Load Agent Card (if --a2a)

- Read file at `--a2a` path.
- Parse JSON.
- Validate against A2A Agent Card schema (name, description, url, version, capabilities, skills, auth_schemes — all required fields present).
- On malformed → `rc=2` with specific field error.

### 6. Create directory structure

- Make `~/claude-data/channels/<name>/` and all subdirs atomically.
- If mkdir fails mid-way, rollback (delete partial structure).

### 7. Write initial state files

In order (dependency-aware):

1. `seq.json` first — atomic write, `{ "next_seq": 1 }`.
2. `digest.json` second — atomic write with initial state.
3. `channel.json` third — atomic write with:
   - `owner_alias` = `--owner` value or creator alias (ADOPT-001)
   - `environment_tier` = `--tier` value or `local` (ADOPT-004)
   - `status` = `triage` if `--triage` else `active` (ADOPT-002)
   - `acceptance_criteria`, `effort_estimate_hours` — only when `--triage`
   - `triaged_at_utc`, `triaged_by_alias` — null at creation (populated by council-resolve on TRIAGE_ACCEPT)
   - creator as sole `members[]` entry
4. `.sessions.json` fourth — atomic write with new channel membership.

Each via `scripts/atomic-write.ps1`.

### 8. MAD stubs (if --mad)

- Write `spec.md`, `plan.md`, `tasks.md` from templates in `scripts/mad-templates/`.
- Atomic write each.

### 9. Set up CronCreate (if available)

- Build prompt: `"/council-check <name>"` (use channel name, not path).
- Convert `--poll` seconds to cron expression (per CronCreate helper rules).
- Call `CronCreate` tool. Capture returned task_id.
- Update `channel.json.members[0].cron_task_id` via atomic re-write.

### 10. Emit output

- Render success report with channel stats, invitation text, preflight warnings (if any).

## Rollback plan

If step 6 or 7 fails mid-way:

- Delete `~/claude-data/channels/<name>/` recursively.
- Do NOT touch `.sessions.json` (not yet updated).
- Do NOT touch CronCreate (not yet created).
- Return `rc=4` with cleanup-performed note.

If step 9 fails but steps 1-8 succeeded:

- Keep channel state (valid without polling).
- Return `rc=1` (preflight-warning category) with note: "Channel created; manual-check mode (CronCreate unavailable)."

If step 10 fails (output rendering): ignore — state is valid; log for debug.

## Error messages (explicit list)

| Condition | Message |
|---|---|
| Name invalid | `"Invalid channel name '<n>'. Use alphanumeric + hyphens, lowercase, 2-63 chars."` |
| Purpose empty | `"Purpose required. Use: /council-open <name> \"<purpose>\""` |
| Purpose too long | `"Purpose exceeds 500 char limit."` |
| Poll out of range | `"--poll must be 60-600 seconds. Got <v>."` |
| Agent card path missing | `"Agent card file not found: <path>"` |
| Agent card malformed | `"Agent card validation failed: <specific-field> missing/invalid"` |
| Channel exists | `"Channel '<n>' exists. Use /council-join <n> --as \"<alias>\" to join, or pick a different name."` |
| `~/claude-data/` not writable | `"Cannot write to ~/claude-data/. Check permissions: <path>"` |
| User declined preflight | `"Cancelled. Channel not created."` |
| Prod tier without triage | `"--tier prod requires --triage. Per rules/triage-gate.md, production channels must have an acceptance-criteria gate before work begins."` |
| CI tier without triage + no recent cert | `"--tier ci requires --triage unless evals/fixtures/eval-certification.json is newer than 1h. Run the eval suite first or add --triage."` |
| `--triage` without acceptance-criteria | `"--triage requires --acceptance-criteria \"<text>\" (min 10 chars). Per rules/triage-gate.md, triage cannot be skipped."` |
| `--owner` mismatch | `"--owner <alias> must match the creator alias. Non-creator ownership requires a subsequent OWNERSHIP_TRANSFER verdict (rules/single-owner-accountability.md)."` |

## Test coverage targets

Per `tests.md` (sibling):

- All 6 return codes (0, 1, 2, 3, 4, 5) reachable + covered.
- Happy path: `/council-open` with and without `--mad` / `--a2a`.
- Validation failures: bad name, empty purpose, bad poll, malformed agent card.
- Collision: creating an existing channel.
- Preflight failures: non-writable dir, missing CronCreate (warn), missing MAD prereqs (warn).
- Rollback: simulated mid-creation failure → state clean.
- run_id propagation: generated + recorded + not displayed to user.

Coverage target: 95%+ of branches. Matches test-sentinel 95% critical-system threshold.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + validation | 2 |
| Preflight integration | 3 |
| State file initialization | 4 |
| MAD stub handling | 2 |
| CronCreate integration | 3 |
| Rollback logic | 3 |
| Error messages | 1 |
| Tests (against fixtures) | 6 |
| **Total** | **24 hours (3 working days)** |

Assumes `scripts/` iter-10 artifacts exist. If not, add ~8h for helper development (though helpers serve all skills, not just this one).

## Forward-links (created if needed)

- `evals/fixtures/council-open-happy-path/` — fixture dir for integration test.
- `evals/fixtures/council-open-malformed-agent-card/` — fixture dir for validation-failure test.
- `evals/layer-2-integration/council-open.test.md` — test plan referencing fixtures.

## Risks

| Risk | Mitigation |
|---|---|
| `.sessions.json` corrupted from prior bad close | Detect malformed JSON; offer user "reset sessions?" consent gate |
| Orphan `.tmp` files in `~/claude-data/channels/<name>/` | Preflight sweeps orphans >60s old |
| CronCreate task_id collision with prior session | Track by channel+alias; CronCreate's task_id is opaque to us |
| Agent card contains prompt-injection literal | Rule 1 scan at load time; warn if match; proceed with suspicious tag |
