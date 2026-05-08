# MAD.Council Docker Sandbox

Isolated environment for running scaffold-coherence smoke tests against the MAD kit. See `../operations/sandbox-testing.md` for design + graduation path.

## Contents

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition: pwsh 7 + Pester + PSScriptAnalyzer + ajv-cli |
| `.dockerignore` | Ensures the image never COPYs the MAD tree (bind-mounted at runtime). |
| `run-sandbox.ps1` | Windows / PowerShell-native entrypoint. |
| `run-sandbox.sh` | macOS / Linux / Git Bash entrypoint. |
| `reports/` | Report JSONs land here after each run (gitignored — not committed). |

## Quick start

### Windows

```powershell
cd C:\Users\tonym\Repos\playground-main\MAD\docker
pwsh .\run-sandbox.ps1
```

### macOS / Linux / Git Bash on Windows

```bash
cd ~/Repos/playground-main/MAD/docker
./run-sandbox.sh
```

First run: ~1-2 min to build the image (cached afterwards). Subsequent runs: ~15-30 sec.

## Options

| Flag (ps1 / sh) | Purpose |
|---|---|
| `-SkipBuild` / `--skip-build` | Reuse cached image. Use when iterating on `scripts/run-sandbox-tests.ps1` and the Dockerfile hasn't changed. |
| `-SkipCategory schema,crosslink` / `--skip-category schema,crosslink` | Skip specific check categories. Categories: `schema`, `crosslink`, `scriptparse`, `frontmatter`, `stubfiring`. |
| `-Cleanup` / `--cleanup` | After the run, remove the image + build cache. Use end-of-day or before switching branches. |

## What the sandbox checks (Tier 1)

- **PowerShell parse** of every `scripts/*.ps1` (no syntax errors).
- **Script header compliance** (`.SYNOPSIS` + `.DESCRIPTION` required).
- **JSON schema parse** + `$id` uniqueness across `schemas/*.schema.json`.
- **Cross-link integrity** — every internal ref resolves.
- **Stub-firing** — every script has `NOT YET IMPLEMENTED` (proves wiring).
- **SKILL.md frontmatter** — every skill has YAML header.

Tier 2 (functional, post-Phase-1): full Pester + adversarial regression + Council mock-model review.

## Isolation guarantees

- **Image base**: `mcr.microsoft.com/powershell:7.4-ubuntu-24.04` — official pwsh image, minimal Ubuntu.
- **Read-only root FS** in the container (`--read-only` + 64MB tmpfs at `/tmp`).
- **MAD tree mounted read-only** at `/mad` — sandbox cannot mutate the source.
- **Reports volume** at `/mad-report` is the only writable path that persists.
- **No network** by default (add `--network mad-test` via editing the wrapper if you need it for Phase 2+ tests).
- **`--rm` on run** — container self-deletes after exit; no manual teardown.

## Teardown

Normal teardown is automatic (`--rm`). For a full clean-slate:

```powershell
pwsh .\run-sandbox.ps1 -Cleanup
```

Or manually:

```powershell
docker image rm mad-sandbox:latest
docker builder prune -f
```

## Reading a report

Reports are JSON, one file per run, in `reports/smoke-<timestamp>-<sessionId>.json`:

```json
{
  "started_utc": "2026-04-18T22:15:00Z",
  "mad_root": "/mad",
  "session_id": "a1b2c3d4",
  "checks": [
    { "name": "script-parse-atomic-write", "status": "pass" },
    { "name": "schema-id-unique-channel",  "status": "pass" },
    { "name": "cross-link-integrity",      "status": "warn", "details": { "dangling_count": 2, "sample": [...] } }
  ],
  "summary": { "total_checks": 72, "pass": 71, "fail": 0, "warn": 1, "skip": 0 },
  "finished_utc": "2026-04-18T22:15:28Z"
}
```

`status` is `pass`, `fail`, `warn`, or `skip`. The script exits non-zero if any `fail` is present; `warn` is allowed through.

## Running without Docker

If you have pwsh 7+ locally and don't want Docker:

```powershell
pwsh -NoProfile -File ../scripts/run-sandbox-tests.ps1 -ReportPath ./smoke.json -MadRoot ..
```

Same checks; Docker adds the reproducibility layer but not more signal.

## CI integration

The sandbox is a well-behaved CI citizen — no interactive prompts, deterministic exit codes, machine-readable JSON report. Phase-1 CI gate shape:

```yaml
- name: MAD scaffold smoke
  shell: pwsh
  run: pwsh MAD/docker/run-sandbox.ps1
  timeout-minutes: 5
- name: Upload report
  uses: actions/upload-artifact@v4
  with:
    name: mad-sandbox-report
    path: MAD/docker/reports/smoke-*.json
```

## Troubleshooting

**"Docker is not available"**

Install Docker Desktop (Windows/macOS) or Docker Engine (Linux). On Windows, ensure WSL2 backend + Docker Desktop started.

**"Cannot connect to the Docker daemon"**

Docker daemon not running. Start Docker Desktop / `sudo systemctl start docker`.

**Build fails downloading Pester or ajv**

Behind a corporate proxy? Add proxy env vars to the Dockerfile's `RUN` step or use `--build-arg HTTP_PROXY=...`.

**Report not produced**

Container crashed before writing. Re-run with `-SkipBuild` and add `--entrypoint /bin/bash` to the docker run for an interactive shell.

## Related

- `../operations/sandbox-testing.md` — strategy + Tier 1 vs Tier 2 graduation.
- `../operations/validation-strategy.md` — 6-layer validation the sandbox graduates into.
- `../scripts/run-sandbox-tests.ps1` — the smoke suite itself.
- `plugins/test-sentinel/skills/fleet-generation/SKILL.md` — state-checkpoint pattern we borrowed.
- `plugins/test-sentinel/skills/coverage-pipeline/SKILL.md` — backup/restore pattern we'll borrow in Tier 2.
