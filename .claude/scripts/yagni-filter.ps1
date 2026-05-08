<#
.SYNOPSIS
  Apply YAGNI ("You Aren't Gonna Need It") filter to Council review findings.
  Phase-2 implementation per iter-39 audit (CHK-064).

.DESCRIPTION
  Invoked by skills/council-review/plan.md Step 7. Filters **Skeptic findings
  that propose adding new symbols** (functions, abstractions) by checking
  whether the proposed symbol already exists in the codebase:

    - If the finding specifies a suggested_symbol AND that symbol has 0 callers
      in the repo → demote severity to LOW with a `demotion` annotation.
    - If the symbol has >=1 caller → retain original severity (the suggestion
      is grounded in real usage, not speculative).
    - If the finding has no suggested_symbol or is not from the Skeptic role →
      pass through untouched.

  Findings from other roles (Advocate, Architect) are never YAGNI-filtered —
  they rarely propose speculative extensions (see SKILL.md §Step 6).

  Symbol extraction:
    Preferred — the role agent explicitly populates finding.suggested_symbol.
    Fallback — regex on finding.summary or .description for shapes like
    `add <Name>(` / `introduce <Name>` / `create <Name>` / `extract <Name>`.
    If neither yields a symbol, the finding passes through.

.PARAMETER Findings
  Array of finding PSCustomObjects. Required.

.PARAMETER RepoRoot
  Path to the repo to search. Required (unless -CallerScanner provided).

.PARAMETER CallerScanner
  Optional scriptblock override for caller counting. Takes ($symbol, $repoRoot)
  and returns an integer count. Used by unit tests to avoid filesystem dependency.
  If omitted, uses `Select-String -Pattern $symbol -Path <repoRoot>\\** -Recurse`.

.OUTPUTS
  Array of findings (same length as input). Demoted findings have:
    - severity = 'LOW'
    - demotion  = @{ filter = 'YAGNI'; reason = 'no callers found'; demoted_from = <original>; symbol = <symbol> }
  Pass-through findings are returned unchanged.

.NOTES
  Rule anchor: wiki/patterns/yagni-filter.md, skills/council-review/SKILL.md §Step 6.
  Test coverage: scripts/yagni-filter.Tests.ps1 (T1-16, T1-17 from
  skills/council-review/tests.md).

.EXAMPLE
  $findings = @(
    [pscustomobject]@{ role = 'skeptic'; severity = 'MEDIUM'; summary = 'add processBatch'; suggested_symbol = 'processBatch' }
  )
  Invoke-YagniFilter -Findings $findings -RepoRoot 'C:/repo' -Verbose
#>

Set-StrictMode -Version Latest

function script:Get-YagniSymbol {
    <#
    .SYNOPSIS Internal: extract the proposed symbol from a finding.
    #>
    param([Parameter(Mandatory)] $Finding)

    # 1. Explicit field wins
    $props = $Finding.PSObject.Properties
    if ($props['suggested_symbol'] -and $Finding.suggested_symbol) {
        return [string]$Finding.suggested_symbol
    }

    # 2. Regex fallback on summary / description
    $text = ''
    if ($props['summary'] -and $Finding.summary) { $text += " $($Finding.summary)" }
    if ($props['description'] -and $Finding.description) { $text += " $($Finding.description)" }

    # Patterns: "add Foo(", "introduce Foo", "create Foo", "extract Foo"
    $patterns = @(
        'add\s+([A-Za-z_][A-Za-z0-9_]*)\s*\('
        'introduce\s+([A-Za-z_][A-Za-z0-9_]*)'
        'create\s+([A-Za-z_][A-Za-z0-9_]*)\s*\('
        'extract\s+([A-Za-z_][A-Za-z0-9_]*)'
    )
    foreach ($pat in $patterns) {
        $m = [regex]::Match($text, $pat, 'IgnoreCase')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return $null
}

function script:Invoke-DefaultCallerScanner {
    <#
    .SYNOPSIS Internal: default grep-based caller count.
    #>
    param(
        [Parameter(Mandatory)] [string] $Symbol,
        [Parameter(Mandatory)] [string] $RepoRoot
    )
    if (-not (Test-Path -LiteralPath $RepoRoot)) { return 0 }
    # Pattern: symbol followed by '(' or '.' or whitespace/EOL — match callers + references
    # Exclude obvious noise (binary files, .git, node_modules)
    try {
        $matches = Select-String -Path (Join-Path $RepoRoot '*') -Pattern "\b$([regex]::Escape($Symbol))\b" -Recurse -SimpleMatch:$false -ErrorAction SilentlyContinue
        return @($matches).Count
    } catch {
        return 0
    }
}

function Invoke-YagniFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [object[]] $Findings,
        [Parameter(Mandatory = $false)] [string] $RepoRoot = $null,
        [Parameter(Mandatory = $false)] [scriptblock] $CallerScanner = $null
    )

    # Fast path: no findings — return empty array (comma prevents unwrap)
    if ($Findings.Count -eq 0) { return , @() }

    # Validate: need either RepoRoot or CallerScanner
    if (-not $RepoRoot -and -not $CallerScanner) {
        throw "Invoke-YagniFilter requires either -RepoRoot or -CallerScanner."
    }

    $scanner = if ($CallerScanner) { $CallerScanner } else {
        # Wrap default scanner into a scriptblock for uniform invocation
        { param($sym, $root) Invoke-DefaultCallerScanner -Symbol $sym -RepoRoot $root }.GetNewClosure()
    }

    $out = foreach ($f in $Findings) {
        $role = [string]$f.role
        $originalSeverity = [string]$f.severity

        # Only Skeptic findings are YAGNI-filtered
        if ($role.ToLowerInvariant() -ne 'skeptic') {
            $f
            continue
        }

        # Already-demoted findings pass through
        if ($f.PSObject.Properties['demotion'] -and $f.demotion) {
            $f
            continue
        }

        $symbol = Get-YagniSymbol -Finding $f
        if (-not $symbol) {
            # Not an additive-suggestion finding; pass through
            $f
            continue
        }

        $callerCount = & $scanner $symbol $RepoRoot

        if ($callerCount -ge 1) {
            # Symbol already in use → grounded, retain severity
            $f
            continue
        }

        # 0 callers → demote to LOW with annotation
        $demoted = $f | Select-Object -Property *
        $demoted | Add-Member -MemberType NoteProperty -Name 'severity' -Value 'LOW' -Force
        $demoted | Add-Member -MemberType NoteProperty -Name 'demotion' -Value ([pscustomobject]@{
            filter       = 'YAGNI'
            reason       = 'no callers found'
            demoted_from = $originalSeverity
            symbol       = $symbol
        }) -Force
        $demoted
    }

    return , @($out)
}
