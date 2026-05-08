<#
.SYNOPSIS
    Lints a markdown file against a learned voice profile.

.DESCRIPTION
    Reads rules from a user-specific style-reference.md (or any profile file
    matching the documented schema) and checks the target document for violations.
    The script ships NO hard-coded rules. All rules come from the profile.

    The profile schema is documented in docs/ARCHITECTURE.md. Briefly: a profile
    has a YAML frontmatter section listing `banned_phrases`, `banned_patterns`,
    `required_patterns`, `character_limits`, etc., plus prose sections that
    describe the voice for human readers.

.PARAMETER Path
    Path to the markdown file to lint. Required.

.PARAMETER Profile
    Path to the profile (style-reference.md). Required.

.PARAMETER Strict
    Treat warnings as errors. Returns non-zero exit code on any violation.

.PARAMETER Watch
    Loop continuously, re-running on file modifications. Useful for background
    review while drafting.

.PARAMETER OutputJson
    Write results as JSON to .mad/scratch/style-lint-{timestamp}.json instead
    of stdout.

.EXAMPLE
    .\style-lint.ps1 -Path my-draft.md -Profile .mad/voice-profiles/myalias/style-reference.md

.EXAMPLE
    .\style-lint.ps1 -Path my-draft.md -Profile <profile> -Watch
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Profile,

    [switch]$Strict,
    [switch]$Watch,
    [switch]$OutputJson
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) { Write-Error "File not found: $Path"; exit 2 }
if (-not (Test-Path $Profile)) { Write-Error "Profile not found: $Profile"; exit 2 }

# --- Load rules from profile ---
function Read-Profile {
    param([string]$Path)
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    # Extract YAML frontmatter
    if ($raw -match "(?s)^---\s*\n(.*?)\n---\s*\n") {
        $yaml = $Matches[1]
    } else {
        Write-Error "Profile $Path is missing YAML frontmatter."
        exit 2
    }
    # Parse YAML manually (avoid module dependency). We only need the lists we
    # care about; treat each `key:` followed by `- item` lines as a list.
    $rules = @{
        banned_phrases    = @()
        banned_patterns   = @()
        required_patterns = @()
        character_limits  = @{}
    }
    $currentKey = $null
    foreach ($line in ($yaml -split "`n")) {
        if ($line -match '^(\w+):\s*$') {
            $currentKey = $Matches[1]
            continue
        }
        if ($line -match '^(\w+):\s*(.+?)\s*$') {
            $currentKey = $Matches[1]
            # Inline value
            $val = $Matches[2]
            if ($rules.ContainsKey($currentKey) -and $rules[$currentKey] -is [hashtable]) {
                # nothing - need indented sub-keys
            } elseif ($rules.ContainsKey($currentKey)) {
                $rules[$currentKey] = $val
            }
            continue
        }
        if ($line -match '^\s+-\s+(.+?)\s*$' -and $currentKey -and $rules.ContainsKey($currentKey)) {
            if ($rules[$currentKey] -is [array] -or $rules[$currentKey] -is [System.Collections.IList]) {
                $rules[$currentKey] += $Matches[1]
            }
        }
        if ($line -match '^\s+(\w[\w.]*):\s*(\d+)\s*$' -and $currentKey -eq 'character_limits') {
            $rules.character_limits[$Matches[1]] = [int]$Matches[2]
        }
    }
    return $rules
}

$rules = Read-Profile -Path $Profile

# --- Build rule list from profile ---
$ruleSet = @()
foreach ($phrase in $rules.banned_phrases) {
    if (-not $phrase) { continue }
    $ruleSet += @{
        Name     = "banned-phrase:$phrase"
        Severity = "error"
        Pattern  = [regex]::Escape($phrase)
        Message  = "Banned phrase per profile: '$phrase'."
    }
}
foreach ($pattern in $rules.banned_patterns) {
    if (-not $pattern) { continue }
    $ruleSet += @{
        Name     = "banned-pattern:$($pattern.Substring(0, [Math]::Min(30, $pattern.Length)))"
        Severity = "warning"
        Pattern  = $pattern
        Message  = "Banned pattern per profile: matches /$pattern/."
    }
}

# --- Read target file ---
$content = Get-Content -Path $Path -Raw -Encoding UTF8
$lines = $content -split "`r?`n"

# --- Run lint pass ---
$violations = @()
$lineNumber = 0
foreach ($line in $lines) {
    $lineNumber++
    foreach ($rule in $ruleSet) {
        try {
            if ($line -match $rule.Pattern) {
                $violations += [PSCustomObject]@{
                    Line     = $lineNumber
                    Rule     = $rule.Name
                    Severity = $rule.Severity
                    Message  = $rule.Message
                    Sample   = $line.Trim().Substring(0, [Math]::Min(120, $line.Trim().Length))
                }
            }
        } catch {
            # Bad regex in profile; skip but warn
            Write-Warning "Skipping invalid pattern: $($rule.Pattern)"
        }
    }
}

# --- Required-patterns check (per-document, not per-line) ---
foreach ($pattern in $rules.required_patterns) {
    if (-not $pattern) { continue }
    if ($content -notmatch $pattern) {
        $violations += [PSCustomObject]@{
            Line     = 0
            Rule     = "required-pattern:$($pattern.Substring(0, [Math]::Min(30, $pattern.Length)))"
            Severity = "warning"
            Message  = "Required pattern not found in document: /$pattern/."
            Sample   = "(document-level)"
        }
    }
}

# --- Report ---
$errorCount = ($violations | Where-Object Severity -eq "error").Count
$warningCount = ($violations | Where-Object Severity -eq "warning").Count

if ($OutputJson) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outDir = ".mad/scratch"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $outPath = Join-Path $outDir "style-lint-$stamp.json"
    [PSCustomObject]@{
        File         = $Path
        Profile      = $Profile
        Generated    = (Get-Date -Format "o")
        ErrorCount   = $errorCount
        WarningCount = $warningCount
        Violations   = $violations
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "Style-lint report written to: $outPath" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "=== Style Lint: $Path ===" -ForegroundColor Cyan
    Write-Host ("Profile: {0}" -f $Profile) -ForegroundColor DarkGray
    Write-Host ""
    if ($violations.Count -eq 0) {
        Write-Host "Clean. No violations found." -ForegroundColor Green
    } else {
        foreach ($v in $violations) {
            $color = if ($v.Severity -eq "error") { "Red" } else { "Yellow" }
            $linePart = if ($v.Line -gt 0) { "line $($v.Line)" } else { "(doc)" }
            Write-Host ("[{0}] {1}: {2}" -f $v.Severity.ToUpper(), $linePart, $v.Rule) -ForegroundColor $color
            Write-Host ("        {0}" -f $v.Message) -ForegroundColor $color
            Write-Host ("        Sample: {0}" -f $v.Sample) -ForegroundColor DarkGray
            Write-Host ""
        }
    }
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host ("  Errors:   {0}" -f $errorCount) -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    Write-Host ("  Warnings: {0}" -f $warningCount) -ForegroundColor $(if ($warningCount -gt 0) { "Yellow" } else { "Green" })
    Write-Host ""
}

if ($Watch) {
    Write-Host "Watch mode: monitoring $Path (Ctrl+C to stop)..." -ForegroundColor Cyan
    $lastWriteTime = (Get-Item $Path).LastWriteTime
    while ($true) {
        Start-Sleep -Seconds 2
        $current = (Get-Item $Path).LastWriteTime
        if ($current -ne $lastWriteTime) {
            $lastWriteTime = $current
            Write-Host ""
            Write-Host "(file modified, re-linting...)" -ForegroundColor DarkGray
            & $PSCommandPath -Path $Path -Profile $Profile -Strict:$Strict
        }
    }
}

if ($errorCount -gt 0) { exit 1 }
if ($Strict -and $warningCount -gt 0) { exit 1 }
exit 0
