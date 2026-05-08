# Tests: /council-open

Test plan for the council-open skill. References fixtures in `evals/fixtures/` (to be created in iter 11) and maps to the 6-layer test harness in `wiki/references.md` §13.

## Test matrix

### Layer 1 — Unit (deterministic)

| Test ID | Scenario | Expected | rc |
|---|---|---|---|
| T1-01 | Parse `council-open my-ch "a purpose"` | args: name=`my-ch`, purpose=`a purpose` | — |
| T1-02 | Parse `council-open my-ch "p" --poll 180 --mad` | args include mad=true, poll=180 | — |
| T1-03 | Name regex valid cases | accepts `a`, `a-b`, `test-1`, `abc-def-ghi` | — |
| T1-04 | Name regex invalid cases | rejects `A`, `a b`, `a_b`, empty, 100-char, starting-hyphen | `2` |
| T1-05 | Purpose empty | rejects | `2` |
| T1-06 | Purpose >500 chars | rejects | `2` |
| T1-07 | Poll below 60 | rejects | `2` |
| T1-08 | Poll above 600 | rejects | `2` |
| T1-09 | Agent Card path nonexistent | rejects | `2` |
| T1-10 | Agent Card malformed JSON | rejects with parse error | `2` |
| T1-11 | Agent Card missing `name` field | rejects with specific field error | `2` |
| T1-12 | Agent Card with only required fields | accepts | `0` |
| T1-13 | run_id generated is valid GUID v4 | matches regex `^[0-9a-f]{8}-...$` | — |

### Layer 2 — Integration (multi-step workflows)

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Happy path no flags | Channel created, single member, polling active, `rc=0` |
| T2-02 | Happy path with `--mad` | Channel created + spec.md/plan.md/tasks.md stubs exist |
| T2-03 | Happy path with `--a2a` | Channel created + `members[0].agent_card` populated |
| T2-04 | Happy path with `--mad --a2a --poll 60` | All flags honored; CronCreate at 60s interval |
| T2-05 | Existing channel name collision | `rc=3`; no state modified |
| T2-06 | CronCreate unavailable (mocked) | `rc=1`; channel created; manual-check mode noted |
| T2-07 | MAD prereqs missing (no dotnet-dev-kit) | `rc=1`; `--mad` warns; artifacts still created from local stubs |
| T2-08 | A2A bridge unreachable | `rc=1`; channel opens local-only; agent_card still published |
| T2-09 | User declines preflight confirmation | `rc=5`; no state created |
| T2-10 | `~/claude-data/` not writable | `rc=4`; preflight stops; clear error |

### Layer 3 — End-to-end + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Creation interrupted mid-write (kill process between state writes) | Next session: orphan partial dir detected; preflight offers cleanup |
| T3-02 | `.sessions.json` corrupted before invocation | Detect malformed JSON; consent-gate for reset |
| T3-03 | Disk fill during directory creation | `rc=4`; rollback deletes partial; no .sessions.json update |
| T3-04 | Clock drifted 5 min | Preflight warns; channel creates; timestamps reflect wall clock |
| T3-05 | Orphan `.tmp` files from prior session | Preflight sweeps >60s old orphans; creation succeeds |

### Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Channel name contains shell metacharacters (`; ls`, `$(whoami)`) | Regex rejects; `rc=2`; no shell execution |
| T4-02 | Purpose contains Rule-1 phrase ("Ignore previous instructions") | Channel creates; purpose stored as data (not executed); `/council-check` renders with ⚠️ |
| T4-03 | Agent Card contains prompt-injection payload in description | Channel creates; agent_card stored; `/council-check` renders with ⚠️ |
| T4-04 | Race: two `/council-open` same name same instant | First wins (`rc=0`); second gets `rc=3` |
| T4-05 | Symlink at target path pointing outside `~/claude-data/` | Detect + reject (security); `rc=4` |
| T4-06 | Path traversal in channel name (attempt via bypass of regex) | Regex enforces; impossible by validation |
| T4-07 | Agent Card file is a symlink to sensitive path (e.g., `~/.ssh/id_rsa`) | File read rejects if file is too large OR if content doesn't parse as valid Agent Card JSON; no disclosure |

### Layer 5 — CI gate

| Test ID | Scenario | Expected |
|---|---|---|
| T5-01 | All L1-L4 tests pass | CI gate passes |
| T5-02 | Any L1-L4 test fails | CI gate fails; PR blocked |
| T5-03 | Coverage below 95% | CI gate fails |
| T5-04 | Mutation testing: inject off-by-one in poll validation | Tests must catch |

## Fixture requirements

To be created in iter 11 under `evals/fixtures/council-open/`:

| Fixture | Purpose |
|---|---|
| `valid-agent-card.json` | Well-formed A2A Agent Card for happy-path tests |
| `malformed-agent-card.json` | JSON parse error |
| `incomplete-agent-card.json` | Missing `name` field |
| `injection-agent-card.json` | Valid structure but description contains "Ignore previous instructions" |
| `large-purpose.txt` | 501-char purpose string |
| `clean-claude-data/` | Starting `~/claude-data/` state for tests (empty) |
| `existing-channel-claude-data/` | Starting state with one channel already present (for collision tests) |
| `corrupt-sessions-claude-data/` | Starting state with malformed `.sessions.json` |
| `orphan-tmp-claude-data/` | Starting state with >60s orphan `.tmp` files |
| `mock-croncreate.ps1` | Mock CronCreate tool for T2-06 |
| `mock-readonly-fs.ps1` | Mock non-writable `~/claude-data/` for T2-10 |

## Coverage targets

- **Branch coverage ≥ 95%** (matches test-sentinel 95% critical-system threshold).
- **All 6 return codes reachable** by at least 1 test.
- **All 5 preflight deps** have at least 1 failure-mode test (L2-06 through L2-10).
- **All 4 adversarial scenarios** (T4-01 through T4-04) in regression set as permanent locked tests.

## Metrics to emit (for iter 12 metrics/)

Each test run emits (per OpenTelemetry GenAI conventions):

- `invoke_skill council-open` span with duration, rc, run_id.
- `execute_tool Write` sub-spans for each state file.
- `execute_tool CronCreate` sub-span (or skip marker).
- `tool.council_open.preflight.duration_ms` histogram.
- `tool.council_open.invocations_total` counter (labels: rc).

## Related

- `SKILL.md` — skill contract.
- `plan.md` — implementation plan.
- `evals/README.md` (future) — eval harness.
- `metrics/operational-metrics.md` (future) — observability targets.
- `mad.council.a2a.md` §11.1 — spec.
