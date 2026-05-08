# lens-standards-audit

> Audit LENS repositories for documentation standards, code conventions, and infrastructure compliance.

This plugin extracts engineering standards from LENS-Docs and rates each LENS repo's compliance with confidence scores. It uses a 3-tier obligation model (REQUIREMENT / STANDARD / RECOMMENDATION) to avoid severity inflation.

## Installation

### From the LENS marketplace

First, add the LENS-Common marketplace (one-time setup). Run this slash command inside Claude Code:

```
/plugin marketplace add https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-Common
```

Then install:

```
/plugin install lens-standards-audit
```

### Locally (no marketplace)

```bash
claude --plugin-dir ./sources/plugins/LENS/Quality/lens-standards-audit
```

## Components

| Component | File | Type | Description |
|-----------|------|------|-------------|
| `standards-audit` | `skills/standards-audit/SKILL.md` | Skill | `/lens-standards-audit:standards-audit` -- full compliance audit |

## Usage

```
/lens-standards-audit:standards-audit                          # Full audit of all LENS-* repos
/lens-standards-audit:standards-audit --repos LENS-CMS,LENS-LRMS  # Audit specific repos
/lens-standards-audit:standards-audit --standards-only         # Extract and display standards only
/lens-standards-audit:standards-audit --category security      # Audit specific category
```

## Repository Discovery

The plugin discovers LENS repos using this priority:

1. `--repos` parameter (explicit list)
2. `${LENS_REPOS_ROOT}` environment variable, scanning for `LENS-*` directories
3. `$HOME/Repos/` default path, scanning for `LENS-*` directories
4. `references/` directory in the current working directory

## Severity Model

All LENS-Docs documents are marked "preview state." The audit uses a 3-tier obligation model:

| Tier | Weight | Trigger Phrases | Failure Label |
|------|--------|-----------------|---------------|
| REQUIREMENT | 3x | "must", "must not", "blocks check-in", "do not" | NON-COMPLIANT |
| STANDARD | 2x | "is the LENS standard", "Use [tool]", "We use [X]" | NON-COMPLIANT |
| RECOMMENDATION | 1x | "should", "recommended", "target", "preferred" | NOT-ADOPTED (informational) |

A repo that does not follow a RECOMMENDATION is scored as NOT-ADOPTED, not NON-COMPLIANT.

## Output

| Artifact | Path |
|----------|------|
| Standards catalog | `{cwd}/lens-standards-audit/standards-catalog.md` |
| Per-repo findings | `{cwd}/lens-standards-audit/repo-{name}.md` |
| Final report | `{cwd}/lens-standards-audit/audit-report.md` |

## License

Microsoft internal. Not licensed for external distribution.
