#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify-CanonicalSkillFrontmatter.ps1 - Validate that one or more MAD
    artifacts carry the canonical frontmatter signature.

.DESCRIPTION
    For each input file, parses YAML frontmatter and checks the three
    required keys:
      generated-by         - must be /<expected-skill> based on filename
      generated-by-version - must be present (semver-shaped)
      skill-state-file-id  - must be present

    Recognized artifacts:
      spec.md             -> /mad-spec
      plan.md             -> /mad-plan
      tasks.md            -> /mad-tasks
      analysis-report.md  -> /mad-analyze
      test-plan.md        -> /testplan

    Exit codes:
      0 - all input files valid
      1 - at least one file missing or malformed signature

.PARAMETER Path
    One or more file paths or directories. If a directory, scans for the
    five recognized artifacts inside it.

.PARAMETER Strict
    Treat non-MAD files as errors (otherwise they're skipped).

.EXAMPLE
    .\Verify-CanonicalSkillFrontmatter.ps1 -Path specs/15-collab-engine/spec.md

.EXAMPLE
    .\Verify-CanonicalSkillFrontmatter.ps1 -Path specs/15-collab-engine/

.EXAMPLE
    Get-ChildItem specs/*/spec.md | .\Verify-CanonicalSkillFrontmatter.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName', 'PSPath')]
    [string[]]$Path,

    [switch]$Strict
)

begin {
    $ErrorActionPreference = 'Continue'
    $artifactSkillMap = @{
        'spec.md'             = 'mad-spec'
        'plan.md'             = 'mad-plan'
        'tasks.md'            = 'mad-tasks'
        'analysis-report.md'  = 'mad-analyze'
        'test-plan.md'        = 'testplan'
    }
    $allFailures = @()
    $allPasses = @()

    function Get-Frontmatter {
        param([string]$Content)
        if (-not $Content) { return $null }
        $match = [regex]::Match($Content, '^---\r?\n([\s\S]*?)\r?\n---', 'Multiline')
        if (-not $match.Success) { return $null }
        $block = $match.Groups[1].Value
        $fields = @{}
        foreach ($line in ($block -split "`r?`n")) {
            if ($line -match '^\s*([A-Za-z0-9_-]+)\s*:\s*(.+?)\s*$') {
                $fields[$matches[1].ToLowerInvariant()] = $matches[2].Trim()
            }
        }
        return $fields
    }

    function Test-OneFile {
        param([string]$FilePath)
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $expectedSkill = $artifactSkillMap[$fileName]
        if (-not $expectedSkill) {
            if ($Strict) {
                return @{ path = $FilePath; status = 'unrecognized'; issues = @("not a recognized MAD artifact: $fileName") }
            }
            return @{ path = $FilePath; status = 'skipped'; issues = @() }
        }

        if (-not (Test-Path $FilePath)) {
            return @{ path = $FilePath; status = 'fail'; issues = @('file not found') }
        }

        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        $fm = Get-Frontmatter -Content $content
        $issues = @()
        if (-not $fm) {
            $issues += 'no YAML frontmatter'
        } else {
            $genBy = $fm['generated-by']
            if (-not $genBy) {
                $issues += 'missing generated-by'
            } elseif (-not ($genBy -match $expectedSkill)) {
                $issues += "generated-by='$genBy' does not match expected /$expectedSkill"
            }
            if (-not $fm['generated-by-version']) {
                $issues += 'missing generated-by-version'
            } elseif ($fm['generated-by-version'] -notmatch '^\d+\.\d+\.\d+(?:[-+].+)?$') {
                $issues += "generated-by-version='$($fm['generated-by-version'])' is not semver"
            }
            if (-not $fm['skill-state-file-id']) {
                $issues += 'missing skill-state-file-id'
            }
        }

        if ($issues.Count -eq 0) {
            return @{ path = $FilePath; status = 'pass'; expected_skill = "/$expectedSkill"; issues = @() }
        }
        return @{ path = $FilePath; status = 'fail'; expected_skill = "/$expectedSkill"; issues = $issues }
    }
}

process {
    foreach ($p in $Path) {
        if (Test-Path -Path $p -PathType Container) {
            # Directory: enumerate the five artifacts
            foreach ($fileName in $artifactSkillMap.Keys) {
                $candidate = Join-Path $p $fileName
                if (Test-Path $candidate) {
                    $result = Test-OneFile -FilePath $candidate
                    if ($result.status -eq 'pass') { $allPasses += $result } elseif ($result.status -eq 'fail') { $allFailures += $result }
                }
            }
        } else {
            $result = Test-OneFile -FilePath $p
            if ($result.status -eq 'pass') { $allPasses += $result }
            elseif ($result.status -eq 'fail') { $allFailures += $result }
            elseif ($result.status -eq 'unrecognized') { $allFailures += $result }
        }
    }
}

end {
    foreach ($r in $allPasses) {
        Write-Host "[PASS] $($r.path) — canonical signature ($($r.expected_skill)) present"
    }
    foreach ($r in $allFailures) {
        Write-Host "[FAIL] $($r.path) — $($r.issues -join '; ')"
    }
    Write-Host ""
    Write-Host "Total: $($allPasses.Count) passed, $($allFailures.Count) failed"
    if ($allFailures.Count -gt 0) { exit 1 } else { exit 0 }
}
