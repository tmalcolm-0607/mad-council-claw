# Layer 0 — Data Source Certification

The foundation layer. Certifies every input MAD.Council skills will process: fixture JSON files, mock tool responses, external dependencies (MCP servers), environment state. If Layer 0 fails, no upper layer is trustworthy.

## Purpose

Before running any test:

1. **Verify fixtures are well-formed.** A test that uses a malformed `channel.json` fixture tests nothing; the malformation IS the bug. Layer 0 catches it at certification.
2. **Verify mock tools behave deterministically.** A mock `CronCreate` that sometimes returns task_id and sometimes throws breaks reproducibility.
3. **Verify external deps are in a known state.** MCP server mocks, file system state, environment variables — all certified.

Per `wiki/references.md` §13 (6-layer harness source): *"Layer 0 certifies every data source before evals run."*

## Certification checklist (runs before any other layer)

### Fixture integrity

For each fixture dir under `fixtures/`:

- [ ] All JSON files parse (`ConvertFrom-Json` succeeds).
- [ ] `channel.json` fixtures conform to schema from `mad.council.a2a.md` §7.1.
- [ ] `digest.json` fixtures conform to §7.5.
- [ ] Message files match `<seq>-<timestamp>-<alias>.json` filename pattern.
- [ ] Message JSON conforms to §7.3 schema.
- [ ] `verdict.json` fixtures match `skills/council-review/SKILL.md` §Step 9 schema.
- [ ] Reference `run_id` values are valid GUIDs.
- [ ] Timestamps are ISO-8601 UTC (`.ToString('o')` format).

### Mock tool behaviors

- [ ] `fixtures/shared/mock-croncreate.ps1` — deterministic: same input → same task_id.
- [ ] `fixtures/shared/mock-cron-delete.ps1` — returns success for known task_ids; fails for unknown.
- [ ] `fixtures/shared/mock-a2a-bridge-server/` — HTTP server returning known payloads at known endpoints.
- [ ] `fixtures/shared/mock-alas-hub/` — receives POSTs; returns 200 (or 500 per fixture variant).
- [ ] `fixtures/shared/mock-prompts-*.ps1` — AskUserQuestion mocks with scripted responses.

### Environment state

- [ ] `fixtures/shared/clean-claude-data/` — empty starting state for tests that need it.

### Cross-link integrity (repo-internal)

The MAD kit makes heavy use of internal cross-references between rules, wiki patterns, skill SKILL.md / plan.md files, scripts, evals, metrics, and agent specs. If any of those links rot (file renamed, pattern removed, section anchor changed), readers hit dead ends — which is especially corrosive in a scaffold-before-implementation kit where nothing "obviously" breaks at runtime.

Layer 0 runs a link-integrity check before any upper layer. The check is a single PowerShell script invoked from CI:

- [ ] `scripts/check-mad-links.ps1` (Phase-1 deliverable; add to script inventory) walks every `MAD/**/*.md` file and:
  1. Extracts markdown-style links, backticked file paths, and `rules/*.md` / `wiki/**/*.md` / `skills/**/*.md` / `scripts/*.ps1` / `evals/*.md` / `metrics/*.md` / `agents/**/*.md` references.
  2. For each reference, verifies the target file exists on disk.
  3. For section-anchor references (`file.md#section-name`), verifies the header exists in the target file (case-insensitive match on slugified header text).
  4. Flags dangling references with file + line number of the broken ref.
  5. Emits a machine-readable report + returns non-zero exit code if any dangling ref found.

- [ ] External URL link-rot scanning is **out of scope for Layer 0** (handled separately on a link-rot-audit cadence; see `wiki/references.md §Link rot policy`). Layer 0 is repo-internal only to keep the check fast and network-free.

- [ ] CHECKLIST `#N` references to the external `loop-scratch/skills-review/CHECKLIST.md` are **exempt** per the `#N` stability contract in `wiki/references.md §Citation conventions` — they are breadcrumbs, not load-bearing links.

Test fixture: `fixtures/shared/link-integrity-break/` — a synthetic MAD tree with 3 intentional broken links. Layer-0 must catch all 3; zero false positives on the canonical repo state.
- [ ] `fixtures/shared/filesystem-readonly.ps1` — simulates `~/claude-data/` unwritable.
- [ ] `fixtures/shared/clock-skew-*.ps1` — set system clock to known drift for preflight tests.
- [ ] PowerShell 7+ available (required by all scripts).
- [ ] Pester 5.x available (required by Layer 1 unit tests).

### Schema validation harness

`fixtures/shared/schema-validators.ps1` exports:

- `Test-ChannelJson` — validates a `channel.json` blob against the canonical schema.
- `Test-DigestJson` — validates `digest.json`.
- `Test-MessageJson` — validates a message.
- `Test-VerdictJson` — validates a verdict.
- `Test-CompletionReport` — validates a Completion Report.
- `Test-RetroJson` — validates a retro.
- `Test-AgentCard` — validates an A2A Agent Card.

Schema definitions live in `fixtures/shared/schemas/*.json` (JSON Schema draft-07).

## Running Layer 0

```
./run-evals.ps1 -Layer 0
```

Output:

```
Layer 0 — Data Source Certification
  ✅ Fixture integrity: 47 fixtures, 312 files, all schemas pass
  ✅ Mock tools: 9 mocks certified deterministic
  ✅ Environment: PowerShell 7.4, Pester 5.5, clock drift <1s
  
Total: 368 certification checks PASS
Time: 2.4s
```

If any check fails, Layers 1-5 are NOT run. Layer 0 is a gate.

## Fixture naming convention

Under `fixtures/<skill>/<scenario>/`:

- **Descriptive name**: `council-post-body-overflow`, not `council-post-test-7`.
- **Scenario-specific state**: fixture dirs contain exactly the state needed for that scenario — no reuse.
- **Mock scripts colocated**: `mock-*.ps1` in the same dir as the fixture that uses it.

**Shared fixtures**: under `fixtures/shared/` — e.g., mock HTTP servers, schema validators, clean base states.

## Coverage

Every skill's `tests.md` lists its fixture requirements. Layer 0 ensures all listed fixtures exist + conform.

| Skill | Fixture count required | Certified |
|---|---|---|
| council-open | 11 | ⏸ |
| council-join | 10 | ⏸ |
| council-post | 15 | ⏸ |
| council-check | 18 | ⏸ |
| council-leave | 12 | ⏸ |
| council-list | 13 | ⏸ |
| council-review | 17 | ⏸ |
| council-verdict | 9 | ⏸ |
| council-resolve | 6 | ⏸ |
| council-retro | 9 | ⏸ |
| scripts (Pester tests) | ~30 per-function | ⏸ |
| shared | ~15 | ⏸ |

**Total target: ~165 fixtures.**

## Failure modes

| Failure | Action |
|---|---|
| Schema validation fails on fixture X | Fail certification; log which file + which schema; do not run any test using X |
| Mock tool behavior changes between runs | Flaky; investigate; block test suite until resolved |
| Missing dependency (pwsh, Pester) | Install + retry; or block with clear instructions |
| Fixture dir missing entirely | Fail with `"Fixture '<name>' not found. Required by tests: <list>. Expected at <path>."` |

## Related

- `fixtures/README.md` — fixture naming + organization.
- Every skill's `tests.md` — enumerates fixture needs.
- `wiki/references.md` §13 — 6-layer harness source.
