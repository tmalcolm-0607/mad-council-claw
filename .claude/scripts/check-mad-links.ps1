<#
.SYNOPSIS
  Verify every internal cross-reference in MAD/**/*.md resolves to a real file.
  Phase-1b deliverable per `plans/phase-1b-polish-package-dogfood.md`.

.DESCRIPTION
  Walks the MAD tree, extracts refs matching the canonical folder-prefix regex
  (`rules`, `wiki`, `skills`, `scripts`, `evals`, `metrics`, `agents`, `plans`,
  `schemas`, `operations`, `docker`, `ui`), and verifies each reference points
  to a file that exists.

  Exemptions:
    - Matches preceded by a path separator (e.g., inside `plugins/zen-agents/agents/foo.md`)
      are NOT treated as MAD-local refs.
    - `CHECKLIST #N` breadcrumb references (per `wiki/references.md §Citation conventions`)
      are external pointers; not verified here.

  The 11 folder prefixes include `ui` from day 1 (per iter-39 audit) so
  Phase-1c doesn't need to re-bump the pattern.

.PARAMETER MadRoot
  Path to the MAD/ directory. Default: `<script-dir>/..`.

.PARAMETER ReportPath
  If set, write JSON report here. Default: stdout only.

.PARAMETER FailOnDangling
  If set, exit 1 on any dangling reference. Default: exit 0 (report-only).

.OUTPUTS
  PSCustomObject: { files_checked, refs_resolved, dangling_count, dangling: [...] }
  Writes the same object as JSON to ReportPath when set.

.NOTES
  Used by: sandbox smoke suite + optional pre-commit hook.
  Design source: `MAD/scripts/run-sandbox-tests.ps1` cross-link-integrity check;
  promoted to a standalone script per plans/phase-1b-polish-package-dogfood.md.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $MadRoot = $null,

    [Parameter(Mandatory = $false)]
    [string[]] $ExtraRoots = @(),

    [Parameter(Mandatory = $false)]
    [string] $ReportPath = $null,

    [Parameter(Mandatory = $false)]
    [switch] $FailOnDangling
)

Set-StrictMode -Version Latest

if (-not $MadRoot) {
    $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}
if (-not (Test-Path -LiteralPath $MadRoot)) {
    throw "MadRoot not found: $MadRoot"
}
$MadRoot = (Resolve-Path -LiteralPath $MadRoot).ProviderPath

# Resolve ExtraRoots to absolute paths, drop any that don't exist. This lets
# callers pass in the consumer-install sibling (e.g. `.claude/` alongside
# `.mad/`) so cross-root refs resolve.
$resolvedExtraRoots = @()
foreach ($er in $ExtraRoots) {
    if (-not $er) { continue }
    if (Test-Path -LiteralPath $er) {
        $resolvedExtraRoots += (Resolve-Path -LiteralPath $er).ProviderPath
    }
}

# Folder prefixes considered MAD-local. `ui` included from day 1 per CHK-069.
$folderAlts = 'rules|wiki|skills|scripts|evals|metrics|agents|plans|schemas|operations|docker|ui'
# Anchor: not preceded by a path separator or word character (avoids matching
# inside `plugins/xyz-agents/agents/foo.md` where the `agents/` is inside a wider path).
$linkPattern = "(?<![A-Za-z0-9/_-])($folderAlts)/[A-Za-z0-9/_.-]+\.(md|ps1|json|sh|ya?ml)"

# Build the set of known files (relative paths, forward-slashes, case-sensitive on Linux).
# Index across MadRoot + every ExtraRoot so a ref resolves if any root has it.
$knownFiles = New-Object System.Collections.Generic.HashSet[string]
$allRoots = @($MadRoot) + $resolvedExtraRoots
foreach ($root in $allRoots) {
    Get-ChildItem -Path $root -Recurse -File -Include '*.md', '*.ps1', '*.json', '*.sh', '*.yml', '*.yaml' `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            $rel = $_.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
            [void]$knownFiles.Add($rel)
        }
}

# Walk every .md across all roots, collect refs, check resolution.
$mdFiles = @()
foreach ($root in $allRoots) {
    $mdFiles += @(Get-ChildItem -Path $root -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object { [pscustomobject]@{ File = $_; Root = $root } })
}
$danglingRefs = [System.Collections.ArrayList]::new()
$totalMatches = 0

foreach ($entry in $mdFiles) {
    $mdFile = $entry.File
    $root = $entry.Root
    $content = Get-Content -LiteralPath $mdFile.FullName -Raw -Encoding UTF8
    $matches = [regex]::Matches($content, $linkPattern)
    foreach ($m in $matches) {
        $totalMatches++
        if (-not $knownFiles.Contains($m.Value)) {
            $relMd = $mdFile.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
            [void]$danglingRefs.Add([pscustomobject]@{
                from = $relMd
                to   = $m.Value
            })
        }
    }
}

$result = [pscustomobject]@{
    mad_root        = $MadRoot
    started_utc     = (Get-Date).ToUniversalTime().ToString('o')
    files_checked   = $mdFiles.Count
    refs_resolved   = $totalMatches - $danglingRefs.Count
    refs_total      = $totalMatches
    dangling_count  = $danglingRefs.Count
    dangling        = @($danglingRefs)
    status          = if ($danglingRefs.Count -eq 0) { 'OK' } else { 'Warn' }
}

if ($ReportPath) {
    $dir = Split-Path -Parent $ReportPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

Write-Host ("check-mad-links: {0} files, {1}/{2} refs resolved, {3} dangling." -f `
    $result.files_checked, $result.refs_resolved, $result.refs_total, $result.dangling_count)

if ($FailOnDangling -and $danglingRefs.Count -gt 0) {
    Write-Host 'Dangling references:' -ForegroundColor Yellow
    foreach ($d in @($danglingRefs | Select-Object -First 25)) {
        Write-Host "  $($d.from) -> $($d.to)"
    }
    if ($danglingRefs.Count -gt 25) {
        Write-Host "  ...and $($danglingRefs.Count - 25) more"
    }
    exit 1
}

# Return the result object for pipeline consumers.
return $result
