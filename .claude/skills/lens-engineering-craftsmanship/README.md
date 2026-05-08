# lens-engineering-craftsmanship

A LENS-wide voice-aware authoring toolkit. The plugin itself ships **no user-specific style rules**. It ships the *workflow* for learning a voice from real WorkIQ communication artifacts, persisting the learned profile, and validating new content against it.

## What this plugin gives you

- **A learn-then-validate workflow** for any LENS engineer:
  1. Run `learn-voice-from-workiq.ps1` to capture WorkIQ-derived observations of the user's communication style.
  2. The orchestrator (Claude Code) executes the WorkIQ queries and produces a per-user `style-reference.md` profile.
  3. Run `style-lint.ps1` against any draft using that profile to enforce the user's actual voice.
  4. Re-run the learn step periodically as the user's voice evolves.
- **A generic throttle-aware batch loop** (`loop-with-backoff.ps1`) usable by any WorkIQ-heavy or rate-limited workflow. Documented in [`docs/BACKOFF-PATTERNS.md`](docs/BACKOFF-PATTERNS.md).
- **A Connect-form validator** (`connect-validate.ps1`) that combines section-level character limits with profile-driven style linting.
- **Generic templates** in [`templates/`](templates/) for Connect sections, setbacks, peer feedback, and new skills. No user-specific content baked in.
- **Evals** in [`evals/`](evals/) with synthetic good/bad fixtures.

## Why this exists

Voice rules tend to live in tribal knowledge or scattered memory files, and they vary per engineer. This plugin codifies the **process** of capturing those rules empirically (from real WorkIQ artifacts) and applying them mechanically (via lint), so:

1. Each engineer gets a voice profile derived from their actual communication, not someone else's.
2. Rule violations are caught by a script, not by a reviewer's eye.
3. The plugin installs in any LENS repo and can bootstrap a profile for the active user on first run.

## Quick start

### Bootstrap a voice profile (Phase 1)
```powershell
# Step 1a: emit WorkIQ query plan
powershell.exe -NoProfile -File .claude/skills/lens-engineering-craftsmanship/scripts/learn-voice-from-workiq.ps1 -User <alias> -Mode sample -Days 60

# Step 1b: orchestrator (Claude Code) executes the queries via MCP, captures
#          responses to .mad/voice-profiles/<alias>/responses/, using
#          loop-with-backoff for throttle handling.

# Step 1c: synthesize the profile from captured responses
powershell.exe -NoProfile -File .claude/skills/lens-engineering-craftsmanship/scripts/learn-voice-from-workiq.ps1 -User <alias> -Mode analyze
# (Outputs a scaffold style-reference.md; orchestrator populates the YAML rules
#  by reading raw-observations.md.)
```

### Lint a draft against the learned profile
```powershell
powershell.exe -NoProfile -File .claude/skills/lens-engineering-craftsmanship/scripts/style-lint.ps1 `
    -Path my-draft.md `
    -Profile .mad/voice-profiles/<alias>/style-reference.md
```

### Validate a Connect draft (limits + style)
```powershell
powershell.exe -NoProfile -File .claude/skills/lens-engineering-craftsmanship/scripts/connect-validate.ps1 `
    -Path connect-draft.md `
    -Profile .mad/voice-profiles/<alias>/style-reference.md
```

### Background review while you keep editing
The orchestrator should fire `style-lint.ps1` with `-Watch` via Claude Code's Bash `run_in_background: true`. Lint reports stream to `.mad/scratch/lint-watch-<timestamp>.json` while the foreground draft session keeps moving.

## Installation

This plugin is intended for the LENS plugin marketplace (Tony's scaffold). For now, drop the directory into any consumer repo's `.claude/skills/`:

```bash
cp -r lens-engineering-craftsmanship /path/to/your-repo/.claude/skills/
```

When the LENS marketplace ships its registry, install via:
```bash
.claude/scripts/registry-install.ps1 -PluginName lens-engineering-craftsmanship
```

## When NOT to use this plugin

- You're writing **code**, not communication. (Use `code-implementer`, language patterns instead.)
- You're doing **deployment work**. (Use `Ev2-Deploy.ps1`, `rules/deployment-scripts.md`.)
- You need **ADO API access** for PR data. (Use `Ado-PR-Collect.ps1`.)
- You need **WorkIQ queries** without orchestration. (Use the MCP tool directly.)

This plugin is for the human-readable text layer of engineering work and the meta-work of creating new skills.

## Authoring

Owner: Tony Malcolm (tonym@microsoft.com).
Contributions welcome via PR. Run `style-lint.ps1` on any new content before committing.
