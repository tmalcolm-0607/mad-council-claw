---
paths:
  - "**/*.sh"
  - ".claude/hooks/**/*.js"
  - ".claude/scripts/**"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Windows Git Bash Patterns

Pitfalls when running Bash commands on Windows via Git Bash (MSYS2).

## Command Differences

| Pitfall | Wrong | Correct |
|---------|-------|---------|
| Perl regex unavailable | `grep -P '\d+'` | `grep -E '[0-9]+'` |
| `find -delete` fails | `find . -name "*.tmp" -delete` | `find . -name "*.tmp" -exec rm {} +` |
| PowerShell resolution | `powershell` | `powershell.exe` (always use `.exe` suffix) |
| MSYS path mangling | `az resource show --ids /sub/...` | `MSYS_NO_PATHCONV=1 az resource show --ids /sub/...` |
| Glob expansion | `rg --glob *.cs` | `rg --glob '*.cs'` (quote to prevent Git Bash expansion) |
| Dash-prefixed patterns | `grep -error` | `grep -- -error` (use `--` separator) |
| Line endings after base64 | `base64 -d <<< $VAR` | `base64 -d <<< $VAR | tr -d "\r"` |

## String & Escape Pitfalls

| Pitfall | Detail |
|---------|--------|
| `$'\n'` not portable | Use literal newline in heredoc or `printf '\n'` |
| `set -e` + arithmetic | `(( x++ ))` returns 1 when x=0, triggering exit |
| `eval` re-parsing | Unreliable with quoted strings; avoid or use arrays |
| Mixed CRLF/LF | Heredocs may get CRLF; pipe through `tr -d '\r'` |
| Single vs double quotes | Git Bash handles `$` expansion differently in some contexts |

## Path Handling

| Pitfall | Detail |
|---------|--------|
| `pwd` returns Windows paths | Use forward slashes: `pwd | tr '\\\\' '/'` |
| Spaces in paths | Always double-quote: `"$file_path"` |
| Drive letter prefix | `/c/Users/...` in Git Bash vs `C:\Users\...` in PowerShell |
| `Join-Path` limit | PowerShell `Join-Path` takes only 2 args; chain: `Join-Path (Join-Path $a $b) $c` |

## Safe Patterns

```bash
# Always set for az CLI commands with route-like params
export MSYS_NO_PATHCONV=1

# Always strip CR after base64 decode
echo "$encoded" | base64 -d | tr -d '\r'

# Always quote globs for tools that take glob args
rg --glob '*.cs' 'pattern'

# Always use grep -- for patterns that might start with dash
grep -- "$pattern" "$file"

# Always use powershell.exe not powershell
powershell.exe -NoProfile -File script.ps1
```
