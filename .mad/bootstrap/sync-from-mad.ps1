#Requires -Version 7

<#
.SYNOPSIS
  Sync plugin content from MAD/ source of truth. Copies skills / scripts /
  schemas / rules into plugins/mad-council/.

.DESCRIPTION
  Fat-plugin pattern: `${CLAUDE_PLUGIN_ROOT}` resolves only to files INSIDE
  the plugin dir, so the plugin needs its own copy of runtime content.
  MAD/ stays authoritative — this script refreshes the copy whenever MAD/
  changes.

  Scope cuts:
    - MAD/skills/workflow/ (45+ imported skills) NOT copied. Plugin focuses
      on Phase-1 council-* skills (CHK-063).
    - Pester .Tests.ps1 files ARE copied so the plugin is testable from
      its own tree.

.PARAMETER MadRoot
  Source MAD/ dir. Default: `<this-script-dir>/../../../MAD`.

.PARAMETER PluginRoot
  Target plugin dir. Default: `<this-script-dir>/..`.

.PARAMETER DryRun
  Report planned actions without changing disk.

.OUTPUTS
  PSCustomObject: { copied, unchanged, removed, status }.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string] $MadRoot = $null,
    [Parameter(Mandatory = $false)] [string] $PluginRoot = $null,
    [Parameter()] [switch] $DryRun
)

Set-StrictMode -Version Latest

if (-not $PluginRoot) {
    $PluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}
if (-not $MadRoot) {
    $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' 'MAD')).ProviderPath
}

# Phase-1 MVP skills only — the 6 council-* ones with real bodies.
$phase1Skills = @('council-open', 'council-join', 'council-list', 'council-post', 'council-check', 'council-leave')

$copied = [System.Collections.ArrayList]::new()
$skipped = [System.Collections.ArrayList]::new()

function script:Sync-Dir {
    param([string] $SrcDir, [string] $DstDir, [string] $Filter = '*')
    if (-not (Test-Path -LiteralPath $SrcDir)) { return }
    if (-not (Test-Path -LiteralPath $DstDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $DstDir -Force | Out-Null }
    }
    foreach ($f in (Get-ChildItem -LiteralPath $SrcDir -File -Filter $Filter -ErrorAction SilentlyContinue)) {
        $target = Join-Path $DstDir $f.Name
        if ($DryRun) {
            [void]$copied.Add("$($f.FullName) → $target")
        } else {
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force
            [void]$copied.Add($target)
        }
    }
}

# --- 1. skills/council-* (only the 6 Phase-1 ones) --------------------------
foreach ($skill in $phase1Skills) {
    $src = Join-Path $MadRoot 'skills' $skill
    $dst = Join-Path $PluginRoot 'skills' $skill
    if (-not (Test-Path -LiteralPath $src)) {
        [void]$skipped.Add("skills/$skill (source missing)")
        continue
    }
    if (-not (Test-Path -LiteralPath $dst) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }
    # Copy SKILL.md + plan.md + tests.md + .ps1 + .Tests.ps1
    script:Sync-Dir -SrcDir $src -DstDir $dst -Filter '*.md'
    script:Sync-Dir -SrcDir $src -DstDir $dst -Filter '*.ps1'
}

# --- 2. scripts/ ------------------------------------------------------------
$srcScripts = Join-Path $MadRoot 'scripts'
$dstScripts = Join-Path $PluginRoot 'scripts'
if (-not (Test-Path -LiteralPath $dstScripts) -and -not $DryRun) {
    New-Item -ItemType Directory -Path $dstScripts -Force | Out-Null
}
# Top-level only (avoid the ported/ subtree)
foreach ($f in (Get-ChildItem -LiteralPath $srcScripts -File -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
    $target = Join-Path $dstScripts $f.Name
    if ($DryRun) {
        [void]$copied.Add("$($f.FullName) → $target")
    } else {
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
        [void]$copied.Add($target)
    }
}
# + README.md from scripts/
$scriptsReadme = Join-Path $srcScripts 'README.md'
if (Test-Path -LiteralPath $scriptsReadme) {
    $target = Join-Path $dstScripts 'README.md'
    if ($DryRun) {
        [void]$copied.Add("$scriptsReadme → $target")
    } else {
        Copy-Item -LiteralPath $scriptsReadme -Destination $target -Force
        [void]$copied.Add($target)
    }
}

# --- 3. schemas/ ------------------------------------------------------------
script:Sync-Dir -SrcDir (Join-Path $MadRoot 'schemas') -DstDir (Join-Path $PluginRoot 'schemas') -Filter '*.json'
script:Sync-Dir -SrcDir (Join-Path $MadRoot 'schemas') -DstDir (Join-Path $PluginRoot 'schemas') -Filter '*.md'

# --- 4. rules/ --------------------------------------------------------------
script:Sync-Dir -SrcDir (Join-Path $MadRoot 'rules') -DstDir (Join-Path $PluginRoot 'rules') -Filter '*.md'

# --- 5. ui/ + ui/web/** (Phase-1c) -----------------------------------------
$srcUi = Join-Path $MadRoot 'ui'
$dstUi = Join-Path $PluginRoot 'ui'
if (Test-Path -LiteralPath $srcUi) {
    script:Sync-Dir -SrcDir $srcUi -DstDir $dstUi -Filter '*.ps1'
    # Recursive copy of web/ static assets
    $srcWeb = Join-Path $srcUi 'web'
    $dstWeb = Join-Path $dstUi 'web'
    if (Test-Path -LiteralPath $srcWeb) {
        if (-not (Test-Path -LiteralPath $dstWeb) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $dstWeb -Force | Out-Null
        }
        foreach ($f in (Get-ChildItem -LiteralPath $srcWeb -File -Recurse -ErrorAction SilentlyContinue)) {
            $rel = $f.FullName.Substring($srcWeb.Length).TrimStart([char]'\', [char]'/')
            $target = Join-Path $dstWeb $rel
            $targetDir = Split-Path -Parent $target
            if (-not $DryRun) {
                if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                Copy-Item -LiteralPath $f.FullName -Destination $target -Force
            }
            [void]$copied.Add($target)
        }
    }
}

$verb = if ($DryRun) { 'planned' } else { 'copied' }
Write-Host ("sync-from-mad: {0} file(s) {1}; {2} skipped." -f $copied.Count, $verb, $skipped.Count)

return [pscustomobject]@{
    mad_root    = $MadRoot
    plugin_root = $PluginRoot
    copied      = $copied.Count
    skipped     = @($skipped)
    dry_run     = [bool]$DryRun
    status      = 'OK'
}
