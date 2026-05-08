# Sandbox Testing — what runs now vs what needs Phase 1

The question: **"Can we deploy MAD into a Docker sandbox, run tests, tear down?"**

Short answer: **yes for scaffold-coherence smoke; no for functional end-to-end until Phase 1 ships.**

The kit is currently 100% scaffold + stubs — all 7 PowerShell scripts raise `throw "NOT YET IMPLEMENTED"` on call. So an "end-to-end" test today would crash on the first atomic-write attempt. But a **meaningful smoke suite** covering schema validity, PowerShell parse, cross-link integrity, stub-firing, and frontmatter conformance IS runnable today and produces real signal.

## Two tiers of sandbox

### Tier 1 — scaffold-coherence smoke (today; 30 seconds)

Runnable RIGHT NOW, with stubs intact. Answers: "does the kit hang together?"

| Check | What it proves | Runs today? |
|---|---|---|
| PowerShell AST parse of every `scripts/*.ps1` | Stubs are syntactically valid PowerShell; no broken brace / mis-typed cmdlet | ✅ |
| `$id` uniqueness + JSON parse across all schemas | Schemas load cleanly; no duplicate identifiers | ✅ |
| Cross-link integrity | Every `rules/*.md`, `wiki/.../*.md`, `scripts/*.ps1`, `schemas/*.json` reference in any markdown file resolves | ✅ |
| SKILL.md frontmatter presence | Every skill has the required YAML header | ✅ |
| Stub-firing — each script raises `NOT YET IMPLEMENTED` on invocation | Wiring is correct; no silent pass-through | ✅ |
| Script contract headers — every `.ps1` has `.SYNOPSIS` + `.DESCRIPTION` | Scripts are documentation-ready for Phase 1 implementation | ✅ |
| JSON Schema parse + `additionalProperties: false` check | Schemas are usable by `Test-Json` + ajv | ✅ |
| Fixture → schema validation (no fixtures yet; skipped cleanly) | Contract ready | ⏭ (materializes in Phase 1) |

### Tier 2 — functional end-to-end (after Phase 1 M1/M2; ~7 weeks effort)

Requires real script bodies + real skill executables + real Pester tests.

| Check | What it proves | Requires |
|---|---|---|
| Full 6-layer eval run per `operations/validation-strategy.md` | Skills actually work; agents actually produce verdicts | Phase 1 M1 scripts + M2 skills |
| Concurrency stress (10-agent simulated posts on same thread) | Atomic-write + seq-increment hold under contention | M1 scripts real |
| Adversarial Layer-4 regression | Rule-1 ban list catches; consent-bypass blocked; session-id spoofing rejected | M1+M2 real |
| Perf benchmarks (operations/performance-benchmarks.md) | SLOs met on reference env | M1+M2 real + M3 eval harness |
| Council review with mocked models | `/council-review` orchestrates 3 roles + produces verdict.json | Phase 2 + mock-model harness |

**We ship Tier 1 today.** Tier 2 comes online as Phase 1 delivers.

## Docker sandbox shape

```
┌─────────────────────────────────────────────────────────────┐
│  Host (Windows / macOS / Linux)                              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Container: mad-sandbox:latest                       │    │
│  │  Base: mcr.microsoft.com/powershell:7.4-ubuntu-24.04 │    │
│  │  Installed: Pester, PSScriptAnalyzer, ajv-cli        │    │
│  │                                                      │    │
│  │  /mad (read-only bind mount) ← host's MAD/ tree      │    │
│  │  /mad-report (rw bind mount) ← host's reports dir    │    │
│  │                                                      │    │
│  │  ENTRYPOINT: scripts/run-sandbox-tests.ps1           │    │
│  │    → JSON report written to /mad-report/             │    │
│  │    → exit 0 if all pass, 1 on any fail               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Teardown: --rm on docker run (container self-deletes)       │
└─────────────────────────────────────────────────────────────┘
```

**Why bind-mount instead of COPY at build time:**
- Iterate on MAD content without rebuilding the image.
- Report lands on host for review after container exits.
- Cleaner teardown: no data in container.

**Why `--rm`:**
- Container self-deletes after exit; no manual `docker rm` needed.
- Image stays cached for quick re-runs.

**Why read-only mount on `/mad`:**
- Sandbox CANNOT mutate the kit. Failed tests can't corrupt the source tree.
- Reports flow only through the designated `/mad-report` rw volume.

## What the sandbox does NOT do

- **Does not call external LLM APIs.** Model calls are Phase 2+ concern; in sandbox, mock them.
- **Does not execute skills end-to-end.** Today — stubs throw. Post-Phase-1 — mocked runs against fixtures.
- **Does not persist state between runs.** Every run is a clean invocation; fixtures are read-only copies from the host tree.
- **Does not need network.** Tier 1 is fully offline. Tier 2 optionally hits mocked services on a Docker network.
- **Does not touch host `~/claude-data/`.** Sandbox uses its own ephemeral `/tmp/sandbox-claude-data/` inside the container.

## Runbook (Tier 1, today)

### On Windows (PowerShell — the usual)

```powershell
cd C:\Users\tonym\Repos\playground-main\MAD\docker
.\run-sandbox.ps1
```

That's it. The script:
1. Builds the image (only rebuilds if Dockerfile changed).
2. Runs the container with `--rm` + bind-mounts.
3. Writes `reports/smoke-<timestamp>.json` to the `docker/` folder.
4. Prints a summary to console.
5. Returns non-zero exit if any check failed.

### On macOS / Linux (bash)

```bash
cd ~/Repos/playground-main/MAD/docker
./run-sandbox.sh
```

Same behavior.

### Without Docker (pwsh-only smoke)

If you have pwsh 7+ installed and don't want to Docker:

```powershell
pwsh -NoProfile -File MAD/scripts/run-sandbox-tests.ps1 -ReportPath ./smoke.json -MadRoot ./MAD
```

This runs the exact same smoke suite against the local tree. Docker adds isolation + reproducibility but not extra checks for Tier 1.

## Teardown

With `--rm` on `docker run`, there's nothing to tear down — container exits, filesystem layer freed. The cached image remains for fast subsequent runs. To fully clean up:

```powershell
docker image rm mad-sandbox:latest
docker builder prune -f    # reclaim build cache
```

The `run-sandbox.ps1` script has a `-Cleanup` flag that does this.

## What the report looks like

```json
{
  "started_utc": "2026-04-18T22:15:00Z",
  "mad_root": "/mad",
  "checks": [
    { "name": "script-parse-atomic-write", "status": "pass" },
    { "name": "script-parse-seq-increment", "status": "pass" },
    { "name": "schema-parse-channel", "status": "pass" },
    { "name": "schema-id-unique-channel", "status": "pass" },
    { "name": "cross-link-integrity", "status": "pass", "details": { "files_checked": 80 } },
    { "name": "script-stubbed-atomic-write", "status": "pass" },
    { "name": "skill-frontmatter-council-open", "status": "pass" },
    ...
  ],
  "summary": {
    "total_checks": 72,
    "pass": 71,
    "fail": 0,
    "warn": 1,
    "skip": 0
  },
  "finished_utc": "2026-04-18T22:15:28Z"
}
```

## Integrating with CI

`docker/run-sandbox.ps1` is a well-behaved CI citizen:
- Exits 0 on success, non-zero on any fail.
- Report JSON is machine-parseable.
- No interactive prompts.
- Can be piped into GitHub Actions / ADO / Jenkins.

Phase-1 CI gate:

```yaml
- name: MAD scaffold smoke
  run: |
    pwsh MAD/docker/run-sandbox.ps1
  timeout-minutes: 5
```

## Graduation path

As Phase 1 lands:

1. **Week 1-3**: scripts real → sandbox smoke picks up real parse + basic Pester unit tests.
2. **Week 4-7**: skills real → sandbox adds Layer-2 integration tests + mock-model Council review.
3. **Week 8-9**: Layer-4 adversarial fixtures → sandbox runs red-team regression.
4. **Week 9+**: Phase 1 acceptance — sandbox becomes the merge-gate.

The sandbox isn't replaced by CI; it IS the CI. One runnable artifact, same behavior locally and in pipeline.

## Patterns borrowed from the marketplace

The `plugins/test-sentinel/` plugin has three skills that inform this sandbox design. We lift patterns verbatim where the marketplace version is already battle-tested.

### From `plugins/test-sentinel/skills/fleet-generation/SKILL.md`

- **Checkpoint state file** — `.github/test-sentinel-state.json` records completed / failed classes + batches with status, so a crash or context-compaction mid-run is resumable. We adopt: `MAD/docker/reports/sandbox-state.json` with the same `version / sessionId / completedChecks / failedChecks / batches` shape. Layer-1+ sandbox runs (Phase-1) resume from checkpoint.
- **Max 5 parallel sub-agents** (hard limit). When the sandbox later fans out to run per-skill Pester tests in parallel, cap is 5. Source: fleet-generation line 713.
- **Stop after 3 consecutive build failures** — matches `wiki/patterns/bounded-iteration-caps.md`. Sandbox halts after 3 consecutive failing checks rather than plowing through a broken state.
- **Fail-fast build gate between batches** — `dotnet build` (or for MAD, `Test-Json` + `pwsh -NoProfile -c { . ./script.ps1 }`) runs between batches; broken batch blocks the next.

### From `plugins/test-sentinel/skills/integration-scaffolding/SKILL.md`

- **Ephemeral-resource Testcontainers pattern** — Phase 2+ sandbox expansion (when actual skills run in the container) uses `Testcontainers` library (or pwsh-native equivalent) for ephemeral real services. `WebApplicationFactory` + in-memory DB + WireMock is the `.NET` shape; ours will be "ephemeral `~/claude-data/` under `/tmp/sandbox-claude-data-<guid>/` per run" — same philosophy: spin up, run, dispose.
- **Unique isolation IDs** — `Guid.NewGuid()` per test instance. In our sandbox: `$sessionId = [guid]::NewGuid()` tags every report + every `/tmp/sandbox-claude-data-$sessionId/` workspace.
- **Max 3 parallel for heavy workloads** — integration tests are heavier than units, so cap is 3 not 5. MAD's Layer-2 integration sandbox uses the same 3-cap.

### From `plugins/test-sentinel/skills/coverage-pipeline/SKILL.md`

- **Backup / restore with SHA256 verification** — `.sentinel-backup` files + hash check before restore guarantees cleanup integrity even after crash mid-run. For our sandbox, the read-only bind-mount avoids modifications entirely (Tier 1). But when the sandbox graduates to writing fixtures or running migrations, adopt this backup pattern verbatim: compute SHA256 before modify; on finish (or cleanup), verify and restore.
- **Idempotent re-run** — safe to invoke the sandbox multiple times; it skips already-completed work per state file.
- **Step-skip flags** — `-SkipStep 1,2,3` in coverage-pipeline; our sandbox adopts `-SkipCategory schema,crosslink,...` for targeted re-runs during development.

### Not adopted (but considered)

- **fleet-orchestration from `ai-native-team`** — broader agent-coordination skill, not isolation/deployment focused; its patterns are already surfaced in `wiki/patterns/orchestrator-worker.md` and `plans/phase-5-intelligence.md`. We don't borrow from it for the sandbox.

## Related

- `docker/Dockerfile` — image definition.
- `docker/run-sandbox.ps1` — Windows entrypoint.
- `docker/run-sandbox.sh` — Unix entrypoint.
- `docker/README.md` — operator manual.
- `scripts/run-sandbox-tests.ps1` — the smoke suite itself.
- `operations/validation-strategy.md` — full 6-layer framework the sandbox graduates into.
- `plans/phase-1-mvp.md §Ownership & rollout` — when each layer starts running.
- `plugins/test-sentinel/skills/fleet-generation/SKILL.md` — state-checkpoint + parallel-subagent + build-gate source.
- `plugins/test-sentinel/skills/integration-scaffolding/SKILL.md` — ephemeral-resource + unique-ID source.
- `plugins/test-sentinel/skills/coverage-pipeline/SKILL.md` — backup/restore/SHA256 + idempotent source.
