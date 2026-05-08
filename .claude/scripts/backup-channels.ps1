<#
.SYNOPSIS
  Back up MAD channel state via pwsh-native Copy-Item. Personal-DR script.
  Phase-1b deliverable per `plans/phase-1b-polish-package-dogfood.md` (Day 2).

.DESCRIPTION
  Copies `~/claude-data/` (or the specified -Source) to -Dest, excluding
  `*.tmp` and `.sessions.json` per `operations/backup-disaster-recovery.md`.
  Uses `Copy-Item -Recurse -Exclude` — no robocopy/rsync dependency (iter-39
  audit CHK-068).

  Default destination layout: `<Dest>/backup-<yyyy-MM-dd-HHmmss>/` — one
  timestamped dir per run so you can hold a rolling window of snapshots.

.PARAMETER Source
  Path to copy from. Default: `$HOME/claude-data`.

.PARAMETER Dest
  Root destination. Timestamped subdir is created inside it. Required.

.PARAMETER DryRun
  Plan only — no files copied. Returns the would-be report with counts as if
  it had run.

.PARAMETER IncludeArchive
  Include `<Source>/archive/` subtree. Default: yes. Pass `-IncludeArchive:$false`
  to skip archived channels.

.OUTPUTS
  PSCustomObject: { source, dest, started_utc, finished_utc, files_copied,
  files_skipped, bytes_copied, elapsed_ms, status }

.NOTES
  Scope: personal laptop DR. Not a multi-machine replication tool. Matches
  `operations/backup-disaster-recovery.md §Backup strategy` recommended cadence.

  Excluded from backup:
    - `*.tmp`             — in-flight atomic writes
    - `.sessions.json`    — session-bound; regenerates on next start

  Not excluded (intentional): `consent-log.jsonl` (audit trail travels with
  the backup), `retros/**`, `verdict.json` (all persistent state).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Source = $null,

    [Parameter(Mandatory = $true)]
    [string] $Dest,

    [Parameter(Mandatory = $false)]
    [switch] $DryRun,

    [Parameter(Mandatory = $false)]
    [bool] $IncludeArchive = $true
)

Set-StrictMode -Version Latest

if (-not $Source) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $Source = Join-Path $homeDir 'claude-data'
}

if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source not found: $Source"
}

$Source = (Resolve-Path -LiteralPath $Source).ProviderPath
$startUtc = (Get-Date).ToUniversalTime()
$stamp = $startUtc.ToString('yyyy-MM-dd-HHmmss')
$targetRoot = Join-Path $Dest "backup-$stamp"

# Inventory — walk source, filter out excluded files, compute would-be work.
$excludePatterns = @('*.tmp')
# -Force so Linux picks up dotfiles like .sessions.json (hidden by default on
# POSIX; Windows has no such concept). We then explicitly exclude .sessions.json
# below — see-and-skip is more portable than rely-on-platform-default.
$includeAll = Get-ChildItem -LiteralPath $Source -Recurse -File -Force -ErrorAction SilentlyContinue
$candidates = @($includeAll | Where-Object {
    # Exclude *.tmp by extension
    if ($_.Name -like '*.tmp') { return $false }
    # Exclude .sessions.json (any location)
    if ($_.Name -eq '.sessions.json') { return $false }
    # Optional: skip archive/ subtree
    if (-not $IncludeArchive) {
        $rel = $_.FullName.Substring($Source.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
        if ($rel -like 'archive/*' -or $rel -like 'archive') { return $false }
    }
    return $true
})
$skipped = @($includeAll | Where-Object { $_ -notin $candidates })

$bytesTotal = 0
foreach ($f in $candidates) { $bytesTotal += $f.Length }

if ($DryRun) {
    $endUtc = (Get-Date).ToUniversalTime()
    return [pscustomobject]@{
        source         = $Source
        dest           = $targetRoot
        started_utc    = $startUtc.ToString('o')
        finished_utc   = $endUtc.ToString('o')
        files_copied   = 0
        files_planned  = $candidates.Count
        files_skipped  = $skipped.Count
        bytes_copied   = 0
        bytes_planned  = $bytesTotal
        elapsed_ms     = [int]($endUtc - $startUtc).TotalMilliseconds
        status         = 'DryRun'
        dry_run        = $true
    }
}

# Real copy. Create target root + per-file copy preserving relative structure.
if (-not (Test-Path -LiteralPath $targetRoot)) {
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
}

$copied = 0
$bytesCopied = 0
foreach ($f in $candidates) {
    $rel = $f.FullName.Substring($Source.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
    $targetFile = Join-Path $targetRoot $rel
    $targetDir = Split-Path -Parent $targetFile
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $f.FullName -Destination $targetFile -Force
    $copied++
    $bytesCopied += $f.Length
}

$endUtc = (Get-Date).ToUniversalTime()
return [pscustomobject]@{
    source         = $Source
    dest           = $targetRoot
    started_utc    = $startUtc.ToString('o')
    finished_utc   = $endUtc.ToString('o')
    files_copied   = $copied
    files_skipped  = $skipped.Count
    bytes_copied   = $bytesCopied
    elapsed_ms     = [int]($endUtc - $startUtc).TotalMilliseconds
    status         = 'OK'
    dry_run        = $false
}
