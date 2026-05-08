<#
.SYNOPSIS
Pre-extract per-file content from a PR's source branch via `git show origin/<branch>:<path>`
so review-stage agents (Skeptic, Architect, Advocate) can Read each file directly without git access.

.DESCRIPTION
Solves a calibration finding from the 2026-05-01 LENS-CMS council review where a Skeptic agent
reported "the branch I have at LENS-CMS does NOT contain the metadata-first refactor" — agent's
working tree was on master, not the PR branch, and the agent's Read tool couldn't help.

This script reads the PR's changed-files list, runs `git show origin/<source-branch>:<path>` for each,
and writes the content into `<reviewDir>/files/<safe-path>` so subsequent agents can `Read` those files.

.PARAMETER PrId
ADO pull request ID. Used to locate `<reviewDir>` = `C:\source\CCGHCP\.mad\scratch\review-<PrId>`
(or wherever the consumer's collect script wrote the metadata).

.PARAMETER ReviewDir
Override the review directory.

.PARAMETER LensRepoRoot
Path to the LENS-CMS (or other) git checkout where `git show` runs. Defaults to LENS-CMS.

.PARAMETER SourceBranch
Source branch name (e.g. `users/lpilat/dft-agency-lookup`). If omitted, parses from pr-meta.md.

.PARAMETER MaxFiles
Cap the number of files extracted (default 50). Above this, file-by-file extraction is too slow;
agents should fall back to git-show-on-demand.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Prepare-PrBranchSources.ps1 -PrId 5155393

.NOTES
Calibration finding: 2026-05-01 council review on PR 5155393 + 5152767.
The previous workflow assumed agents would call `git -C <repo> show origin/<branch>:<path>` themselves;
in practice, multiple agents in parallel hit branch-resolution friction. Pre-extraction is reliable.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [int]$PrId,

  [string]$ReviewDir,

  [string]$LensRepoRoot = 'C:\Users\tonym\Repos\LENS-CMS',

  [string]$SourceBranch,

  [int]$MaxFiles = 50
)

$ErrorActionPreference = 'Stop'

if (-not $ReviewDir) {
  $ReviewDir = "C:\source\CCGHCP\.mad\scratch\review-$PrId"
}
if (-not (Test-Path $ReviewDir)) {
  Write-Error "Review dir not found: $ReviewDir (run Ado-PR-Collect.ps1 first)"
  exit 2
}

# Resolve source branch from pr-meta.md if not provided
if (-not $SourceBranch) {
  $meta = Get-Content (Join-Path $ReviewDir 'pr-meta.md')
  $line = $meta | Where-Object { $_ -match '^- \*\*Source\*\*: `([^`]+)`' }
  if ($line) {
    $null = $line[0] -match '`([^`]+)`'
    $SourceBranch = $matches[1]
  } else {
    Write-Error "Could not parse source branch from pr-meta.md; pass -SourceBranch explicitly"
    exit 2
  }
}

# Strip refs/heads/ prefix if present
$SourceBranch = $SourceBranch -replace '^refs/heads/', ''

Write-Host "PR:           #$PrId"
Write-Host "Source:       $SourceBranch"
Write-Host "Repo:         $LensRepoRoot"
Write-Host "Review dir:   $ReviewDir"

# Ensure branch is fetched
Push-Location $LensRepoRoot
try {
  & git fetch origin $SourceBranch 2>&1 | Out-Null
  $sha = (& git rev-parse --short "origin/$SourceBranch" 2>&1).Trim()
  Write-Host "Branch SHA:   $sha"
} finally { Pop-Location }

# Read changed-files.txt; if not present, derive from pr-diff.md
$changedFiles = Join-Path $ReviewDir 'changed-files.txt'
if (-not (Test-Path $changedFiles)) {
  $diffMd = Join-Path $ReviewDir 'pr-diff.md'
  if (-not (Test-Path $diffMd)) {
    Write-Error "Neither changed-files.txt nor pr-diff.md found in $ReviewDir"
    exit 2
  }
  (Select-String -Path $diffMd -Pattern '`(/[^`]+)`' -AllMatches).Matches.Value |
    ForEach-Object { $_.Trim('`') } | Sort-Object -Unique | Set-Content $changedFiles -Encoding UTF8
}

$files = Get-Content $changedFiles | Where-Object { $_.Trim() -ne '' }
$count = $files.Count
Write-Host "Files in PR:  $count"

if ($count -gt $MaxFiles) {
  Write-Warning "$count files > MaxFiles=$MaxFiles; capping. Agents needing more should fall back to git-show on demand."
  $files = $files | Select-Object -First $MaxFiles
}

$outRoot = Join-Path $ReviewDir 'files'
if (-not (Test-Path $outRoot)) { New-Item -ItemType Directory -Path $outRoot -Force | Out-Null }

$manifest = @()
$extracted = 0
$missing = 0

Push-Location $LensRepoRoot
try {
  foreach ($f in $files) {
    # Strip leading slash; git show wants a path relative to repo root
    $relPath = $f.TrimStart('/')

    # Safe local filename: replace path separators with __
    $safeName = ($relPath -replace '[\\/]', '__')
    $localPath = Join-Path $outRoot $safeName

    $content = & git show "origin/${SourceBranch}:${relPath}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $content) {
      Set-Content -Path $localPath -Value $content -Encoding UTF8
      $extracted++
      $manifest += [pscustomobject]@{
        pr_path = $f
        local_path = $localPath
        size = $content.Length
        status = 'extracted'
      }
    } else {
      $missing++
      $manifest += [pscustomobject]@{
        pr_path = $f
        local_path = $null
        size = 0
        status = 'missing-from-branch (likely added/deleted/renamed)'
      }
    }
  }
} finally { Pop-Location }

# Write manifest
$manifest | Export-Csv -Path (Join-Path $ReviewDir 'files-manifest.csv') -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Extracted:    $extracted / $count"
Write-Host "Missing:      $missing"
Write-Host "Out dir:      $outRoot"
Write-Host "Manifest:     $(Join-Path $ReviewDir 'files-manifest.csv')"
