---
paths:
  - "**/*.ps1"
  - "**/*.psm1"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# PowerShell Conventions

Standards for PowerShell scripts in this project. These rules prevent the most common bugs found across 175 sessions.

## Reserved Variables

NEVER use these as parameter or variable names:

| Variable | Why It's Reserved |
|----------|-------------------|
| `$args` | Automatic variable — contains unbound arguments |
| `$input` | Automatic variable — pipeline input enumerator |
| `$_` / `$PSItem` | Current pipeline object |
| `$PSCmdlet` | Cmdlet instance in advanced functions |
| `$this` | Current object in script blocks |
| `$Error` | Array of recent errors |
| `$Host` | PowerShell host object |
| `$Matches` | Regex match results |

**Use instead**: `$Arguments`, `$InputData`, `$Params`, or descriptive named parameters.

## Parameter Declaration

Always use `[CmdletBinding()]` and typed parameters:

```powershell
# Correct
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [string]$RolloutId = ''
)

# Wrong — uses $args (reserved) and no CmdletBinding
param($args)
```

## String Quoting

| Use | When |
|-----|------|
| Single quotes `'...'` | Literal strings, regex, paths with `$`, patterns with `#` |
| Double quotes `"..."` | Variable interpolation needed |
| Here-strings `@'...'@` | Multi-line literals (JSON bodies, scripts) |
| Here-strings `@"..."@` | Multi-line with interpolation |

**Note**: Here-string closing delimiters (`'@` or `"@`) must appear at the start of a new line with no leading whitespace.

### Common Traps

```powershell
# WRONG: # and $ get interpreted
$pattern = "## Phase $count — Results"

# CORRECT: Single quotes for literal text
$pattern = '## Phase $count - Results'

# WRONG: Em dash (—) can cause encoding issues in some terminals
$msg = "Step — complete"

# CORRECT: Use ASCII hyphen
$msg = 'Step - complete'
```

**Rule**: Always validate string interpolation in a dry-run (`Write-Host`) before committing.

## StrictMode and Optional JSON Fields

Do NOT use `Set-StrictMode` in scripts that parse JSON with optional fields. `ConvertFrom-Json` returns `PSCustomObject`, which yields `$null` for missing properties -- the desired behavior for optional fields. `Set-StrictMode -Version Latest` turns those property accesses into terminating exceptions.

```powershell
# WRONG - breaks on optional fields
Set-StrictMode -Version Latest
$data = $json | ConvertFrom-Json
$cost = $data.cost  # Throws if 'cost' not in JSON

# CORRECT - allow null for missing fields
$data = $json | ConvertFrom-Json
$cost = $data.cost  # Returns $null if missing
if ($cost) { Write-Host "Cost: $cost" }
```

**Real-world example**: The statusline script (`.claude/scripts/statusline.ps1`) deliberately omits `Set-StrictMode` because Claude Code's status JSON omits optional fields like `todos`, `cost`, and `session_id`. With StrictMode enabled, the outer `try/catch` swallows the exception and the entire statusline blanks out.

| Pattern | Status |
|---------|--------|
| `Set-StrictMode` in scripts parsing JSON with optional fields | **REJECT** |
| Accessing PSCustomObject properties that may not exist (by design) | ALLOW (produces `$null`) |

---

## Error Handling

### `$ErrorActionPreference = 'Stop'`

This converts ALL non-terminating errors to terminating — including **native command stderr output**.

```powershell
# DANGEROUS: 'Stop' converts native command stderr to terminating errors
$ErrorActionPreference = 'Stop'
git push origin main  # git writes progress to stderr — this throws

# SAFE: Use $LASTEXITCODE for native commands
git push origin main
if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }
```

### Pattern: Hybrid Error Handling

```powershell
# Use 'Stop' for cmdlets, $LASTEXITCODE for native commands
$ErrorActionPreference = 'Stop'

try {
    # PowerShell cmdlets — 'Stop' works correctly
    $result = Invoke-RestMethod -Uri $uri

    # Native commands — check exit code explicitly
    $ErrorActionPreference = 'Continue'
    dotnet build
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }
    $ErrorActionPreference = 'Stop'
}
catch {
    Write-Error "Operation failed: $_"
    exit 1
}
```

## Enforcement

| Pattern | Status |
|---------|--------|
| `$args` as variable name | **REJECT** |
| `$input` as variable name | **REJECT** |
| Missing `[CmdletBinding()]` on scripts with params | WARN |
| Double-quoted strings with no interpolation | WARN |
| `$ErrorActionPreference='Stop'` without `'Continue'` toggle before native commands | **REJECT** |
| Unquoted paths with spaces | **REJECT** |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| `param($args)` | Shadows automatic variable | Use named parameters |
| `"literal with no $vars"` | Unnecessary double quotes | Use single quotes |
| `$ErrorActionPreference='Stop'` globally | Breaks native command stderr | Hybrid: 'Stop' for cmdlets, $LASTEXITCODE for native |
| `$ErrorActionPreference='Stop'` with native commands | Stderr becomes terminating error | Toggle to `'Continue'` before native calls, check `$LASTEXITCODE` |
| Inline `Write-Output` for return values | Pollutes pipeline | Use `return` or assign to variable |
| Missing `-NoProfile` in `powershell.exe` calls | Profile scripts add latency and side effects | Always use `powershell.exe -NoProfile -File` |

---

## UTF-8 BOM Gotcha (PowerShell 5.1)

PowerShell 5.1 (.NET Framework) `Out-File -Encoding utf8` writes a BOM (Byte Order Mark). Tools like `az devops invoke --in-file` reject BOM with `JSONDecodeError`.

```powershell
# WRONG: Writes BOM in PS 5.1
$json | Out-File -FilePath $file -Encoding utf8

# CORRECT: Write UTF-8 without BOM
[System.IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding $false))
```

### az CLI WARNING Filtering

`az CLI` emits WARNING/INFO lines before JSON that break `ConvertFrom-Json`:

```powershell
# WRONG: WARNING lines break JSON parsing
$result = az some-command 2>&1 | ConvertFrom-Json

# CORRECT: Filter non-JSON lines
$result = az some-command 2>&1 |
    Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' } |
    ConvertFrom-Json
```

| Pattern | Status |
|---------|--------|
| `Out-File -Encoding utf8` for tool-consumed files | **REJECT** |
| `az` output piped to `ConvertFrom-Json` without WARNING filter | **WARN** |
