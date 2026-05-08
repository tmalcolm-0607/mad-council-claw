# lens-multi-model-review

Multi-model code review using Copilot CLI (GPT 5.5 + Claude Opus 4.7) with LENS-specific context injection.

## Why This Exists

Standard AI code reviews produce false positives and miss LENS-specific violations because they lack project context. A generic reviewer doesn't know about `ParameterContracts`, the org-wide `no var` rule, CRLF line endings, or the layered architecture prohibition on cross-layer access.

This skill injects the project's `CLAUDE.md` and `.claude/rules/` into the review prompt, so both models review against your project's actual standards — not generic best practices.

## Installation

```bash
claude plugin install ~/Repos/LENS-Common/sources/plugins/LENS/Quality/lens-multi-model-review
```

## Usage

```bash
# Review an ADO pull request
/lens-multi-model-review:multi-model-review 5069800
/lens-multi-model-review:multi-model-review https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-LRMS/pullrequest/5069800

# Review local branch changes against master
/lens-multi-model-review:multi-model-review --diff
/lens-multi-model-review:multi-model-review --diff --base develop
```

## What It Does

1. **Discovers** project conventions from CLAUDE.md + .claude/rules/*.md
2. **Injects** them and the S1–S15 security pitfalls checklist as mandatory review context into the Copilot CLI prompt
3. **Runs** GPT 5.5 (max effort) and Opus 4.7 (max effort) in parallel
4. **Two-pass review**: explicit security pass against S1–S15, then a convention/quality pass
5. **Analyzes** findings against LENS conventions to filter false positives
6. **Deduplicates** across models with cross-model agreement scoring
7. **Blocks on CRITICAL** S-findings; recommends prioritized fixes for the rest

## Finding Categories

| Category | Examples |
|----------|---------|
| **Security (S1–S15)** | AllowAnonymous on state-changing route, authorization fail-open in production, IDOR, client-spoofable identity headers, secret/PII in logs, IaC deployment-output leakage, WAF in Detection mode, MD5/PKCS#1 v1.5 use, accept-all TLS, path traversal, dependency confusion |
| LENS Convention Violations | `var` usage, missing ParameterContracts, nested IFs, architecture violations |
| Logic/Correctness | Bugs, edge cases, race conditions |
| Performance | N+1 queries, blocking async, unnecessary allocations |
| Test Coverage | Missing tests, untested edge cases |
| Documentation | Missing XML docs, stale comments |

See [`skills/multi-model-review/references/security-checklist.md`](skills/multi-model-review/references/security-checklist.md) for the full S1–S15 taxonomy.

## Copilot CLI Compatibility

The skill auto-detects your Copilot CLI setup on first run:
- `copilot` (standard installation)
- `agency copilot` (agency wrapper)

## Prerequisites

- Copilot CLI installed and authenticated
- Azure CLI with azure-devops extension (for PR mode)
- Git (for local diff mode)

## Safety

- **Read-only by default** — never modifies code unless you explicitly request fixes
- **Never pushes** — fixes are staged locally, never committed or pushed automatically
- **No secrets in prompts** — strips connection strings and tokens from diffs before sending
