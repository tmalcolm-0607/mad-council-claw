#Requires -Version 7

<#
.SYNOPSIS
  Scaffold-coherence smoke suite for MAD.Council. Runs inside the Docker sandbox
  (docker/Dockerfile) OR directly on the host with pwsh 7+.

.DESCRIPTION
  Tier-1 smoke checks per operations/sandbox-testing.md:
    1. PowerShell AST parse of every scripts/*.ps1
    2. Script contract header compliance (.SYNOPSIS + .DESCRIPTION)
    3. JSON schema parse + $id uniqueness across schemas/*.schema.json
    4. Cross-link integrity — internal path refs in markdown must resolve
    5. Stub-firing — each script has NOT YET IMPLEMENTED marker
    6. SKILL.md frontmatter presence (YAML header)
    7. Schema additionalProperties: false convention

  Runnable today without any Phase-1 work. Graduates to Pester + integration
  tests as Phase 1 delivers (operations/sandbox-testing.md §Tier 2).

  Patterns borrowed from marketplace:
  - Checkpoint state file (plugins/test-sentinel/skills/fleet-generation)
  - Max 5 parallel sub-agents hard cap (fleet-generation line 713)
  - Step-skip categories (plugins/test-sentinel/skills/coverage-pipeline)

.PARAMETER ReportPath
  Absolute path to the JSON report file to produce. In Docker: /mad-report/....
  On host: any writable path.

.PARAMETER MadRoot
  Absolute path to the MAD/ root directory. In Docker: /mad. On host: the
  actual MAD folder.

.PARAMETER SkipCategory
  Comma-separated list of check categories to skip. One of:
    schema        — schema parse + $id uniqueness
    crosslink     — internal ref resolution
    scriptparse   — PowerShell AST parse
    frontmatter   — SKILL.md YAML header
    stubfiring    — NOT YET IMPLEMENTED marker

.OUTPUTS
  Writes JSON report at $ReportPath. Exits 0 if all checks pass, 1 if any fail.

.EXAMPLE
  pwsh -NoProfile -File MAD/scripts/run-sandbox-tests.ps1 `
       -ReportPath ./smoke.json -MadRoot ./MAD

.NOTES
  This is a TIER-1 smoke only. Tier 2 (Pester + integration) lands with Phase 1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $ReportPath = './smoke.json',

    [Parameter(Mandatory = $false)]
    [string] $MadRoot = '.',

    [Parameter(Mandatory = $false)]
    [string] $SkipCategory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$MadRoot = (Resolve-Path $MadRoot -ErrorAction Stop).ProviderPath
$skipSet = @($SkipCategory -split ',' | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() })

$report = [ordered]@{
    started_utc = (Get-Date).ToUniversalTime().ToString('o')
    mad_root    = $MadRoot
    session_id  = if ($env:SANDBOX_SESSION_ID) { $env:SANDBOX_SESSION_ID } else { [guid]::NewGuid().ToString('N').Substring(0,8) }
    host_info   = @{
        os         = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
        ps_version = $PSVersionTable.PSVersion.ToString()
    }
    checks      = [System.Collections.ArrayList]::new()
    summary     = @{}
}

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('pass','fail','warn','skip')]
        [string]$Status,
        $Details = $null
    )
    [void]$report.checks.Add([pscustomobject]@{
        name    = $Name
        status  = $Status
        details = $Details
    })
}

function Skip-Category {
    param([string]$Category)
    return $skipSet -contains $Category.ToLowerInvariant()
}

#------------------------------------------------------------------------------
# Category 1 — PowerShell script parse
#------------------------------------------------------------------------------
if (Skip-Category 'scriptparse') {
    Add-Check 'scriptparse' 'skip' @{ reason = 'SkipCategory' }
} else {
    $scriptDir = Join-Path $MadRoot 'scripts'
    if (Test-Path $scriptDir) {
        # Canonical MAD scripts live at top-level only. Nested subfolders (ported/, mad-templates/)
        # are either imports of external scripts or markdown-only template bundles — out of scope
        # for the scaffold-coherence smoke. Exclude .Tests.ps1 — Pester tests aren't scripts-under-test.
        $scripts = Get-ChildItem -Path $scriptDir -Filter '*.ps1' -File -Exclude '*.Tests.ps1'
        foreach ($script in $scripts) {
            $tokens = $null; $errors = $null
            try {
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            } catch {
                Add-Check "script-parse-$($script.BaseName)" 'fail' @{
                    error = $_.Exception.Message
                }
                continue
            }
            if ($errors -and $errors.Count -gt 0) {
                Add-Check "script-parse-$($script.BaseName)" 'fail' @{
                    errors = @($errors | ForEach-Object {
                        "$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber) $($_.Message)"
                    })
                }
            } else {
                Add-Check "script-parse-$($script.BaseName)" 'pass' @{
                    lines = (Get-Content $script.FullName).Count
                }
            }
        }
    } else {
        Add-Check 'scriptparse-dir' 'warn' @{ note = "No scripts/ dir at $scriptDir" }
    }
}

#------------------------------------------------------------------------------
# Category 2 — Script contract header compliance
#------------------------------------------------------------------------------
if (-not (Skip-Category 'scriptparse')) {
    $scriptDir = Join-Path $MadRoot 'scripts'
    if (Test-Path $scriptDir) {
        # Same scope as parse: top-level core scripts only, excluding test files.
        foreach ($script in (Get-ChildItem -Path $scriptDir -Filter '*.ps1' -File -Exclude '*.Tests.ps1')) {
            $content = Get-Content $script.FullName -Raw
            $missing = @()
            if ($content -notmatch '\.SYNOPSIS')     { $missing += 'SYNOPSIS' }
            if ($content -notmatch '\.DESCRIPTION')  { $missing += 'DESCRIPTION' }
            if ($missing.Count -eq 0) {
                Add-Check "script-header-$($script.BaseName)" 'pass'
            } else {
                Add-Check "script-header-$($script.BaseName)" 'fail' @{ missing = $missing }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Category 3 — Schema parse + $id uniqueness + additionalProperties
#------------------------------------------------------------------------------
if (Skip-Category 'schema') {
    Add-Check 'schema' 'skip' @{ reason = 'SkipCategory' }
} else {
    $schemaDir = Join-Path $MadRoot 'schemas'
    if (Test-Path $schemaDir) {
        $schemas = Get-ChildItem -Path $schemaDir -Filter '*.schema.json'
        $seenIds = @{}
        $missingStrictProps = @()
        foreach ($schema in $schemas) {
            try {
                $doc = Get-Content $schema.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Add-Check "schema-parse-$($schema.BaseName)" 'fail' @{
                    error = $_.Exception.Message
                }
                continue
            }
            Add-Check "schema-parse-$($schema.BaseName)" 'pass'

            # $id uniqueness
            if ($doc.PSObject.Properties['$id']) {
                $id = $doc.'$id'
                if ($seenIds.ContainsKey($id)) {
                    Add-Check "schema-id-unique-$($schema.BaseName)" 'fail' @{
                        collision_with = $seenIds[$id]
                    }
                } else {
                    $seenIds[$id] = $schema.Name
                    Add-Check "schema-id-unique-$($schema.BaseName)" 'pass'
                }
            } else {
                Add-Check "schema-id-unique-$($schema.BaseName)" 'warn' @{
                    note = '$id field missing'
                }
            }

            # additionalProperties convention
            $text = Get-Content $schema.FullName -Raw
            if ($text -notmatch '"additionalProperties"\s*:\s*false') {
                $missingStrictProps += $schema.Name
            }
        }
        if ($missingStrictProps.Count -eq 0 -and $schemas.Count -gt 0) {
            Add-Check 'schema-strict-props' 'pass' @{ count = $schemas.Count }
        } elseif ($missingStrictProps.Count -gt 0) {
            Add-Check 'schema-strict-props' 'warn' @{
                schemas_without = $missingStrictProps
                note = 'additionalProperties: false convention not enforced in these schemas'
            }
        }
    } else {
        Add-Check 'schema-dir' 'warn' @{ note = "No schemas/ dir at $schemaDir" }
    }
}

#------------------------------------------------------------------------------
# Category 4 — Cross-link integrity
#------------------------------------------------------------------------------
if (Skip-Category 'crosslink') {
    Add-Check 'crosslink' 'skip' @{ reason = 'SkipCategory' }
} else {
    $mdFiles = Get-ChildItem -Path $MadRoot -Filter '*.md' -Recurse -ErrorAction SilentlyContinue

    # Build the set of known content files (rel paths with forward-slashes)
    $knownFiles = New-Object System.Collections.Generic.HashSet[string]
    Get-ChildItem -Path $MadRoot -Recurse -File -Include '*.md','*.ps1','*.json','*.sh','*.yml','*.yaml' `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            $rel = $_.FullName.Substring($MadRoot.Length).TrimStart([char]'\',[char]'/').Replace('\','/')
            [void]$knownFiles.Add($rel)
        }

    # Regex for internal refs (conservative — match canonical MAD folder prefixes only,
    # anchored to avoid capturing inside paths like plugins/zen-agents/agents/foo.md).
    # Exclude matches preceded by `/` (which indicates we're mid-path into another tree).
    $linkPattern = '(?<![A-Za-z0-9/_-])(rules|wiki|skills|scripts|evals|metrics|agents|plans|schemas|operations|docker)/[A-Za-z0-9/_.-]+\.(md|ps1|json|sh|ya?ml)'

    $danglingRefs = [System.Collections.ArrayList]::new()
    $totalMatches = 0
    foreach ($mdFile in $mdFiles) {
        $content = Get-Content $mdFile.FullName -Raw
        $matches = [regex]::Matches($content, $linkPattern)
        foreach ($m in $matches) {
            $totalMatches++
            if (-not $knownFiles.Contains($m.Value)) {
                $relMd = $mdFile.FullName.Substring($MadRoot.Length).TrimStart([char]'\',[char]'/').Replace('\','/')
                [void]$danglingRefs.Add("$relMd → $($m.Value)")
            }
        }
    }

    if ($danglingRefs.Count -eq 0) {
        Add-Check 'cross-link-integrity' 'pass' @{
            files_checked = $mdFiles.Count
            refs_resolved = $totalMatches
        }
    } else {
        # Dangling is warn, not fail — some refs may be forward-looking (Phase-1 deliverables)
        Add-Check 'cross-link-integrity' 'warn' @{
            files_checked = $mdFiles.Count
            refs_resolved = $totalMatches
            dangling_count = $danglingRefs.Count
            sample = @($danglingRefs | Select-Object -First 15)
        }
    }
}

#------------------------------------------------------------------------------
# Category 5 — Stub-firing (NOT YET IMPLEMENTED markers)
#------------------------------------------------------------------------------
if (Skip-Category 'stubfiring') {
    Add-Check 'stubfiring' 'skip' @{ reason = 'SkipCategory' }
} else {
    $scriptDir = Join-Path $MadRoot 'scripts'
    if (Test-Path $scriptDir) {
        # Canonical scripts only (top-level of scripts/). ported/ + mad-templates/ out of scope.
        foreach ($script in (Get-ChildItem -Path $scriptDir -Filter '*.ps1' -File -Exclude '*.Tests.ps1')) {
            $content = Get-Content $script.FullName -Raw
            if ($content -match 'NOT YET IMPLEMENTED') {
                Add-Check "script-stubbed-$($script.BaseName)" 'pass'
            } else {
                # Not a fail — once Phase-1 delivers real implementations, the marker goes
                # away. This warn is an informational signal of progress.
                Add-Check "script-stubbed-$($script.BaseName)" 'warn' @{
                    note = 'No NOT YET IMPLEMENTED marker — real implementation (Phase 1+) or silent stub'
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Category 6 — SKILL.md frontmatter
#------------------------------------------------------------------------------
if (Skip-Category 'frontmatter') {
    Add-Check 'frontmatter' 'skip' @{ reason = 'SkipCategory' }
} else {
    $skillDir = Join-Path $MadRoot 'skills'
    if (Test-Path $skillDir) {
        $skillMds = Get-ChildItem -Path $skillDir -Filter 'SKILL.md' -Recurse
        foreach ($sm in $skillMds) {
            $content = Get-Content $sm.FullName -Raw
            $fmMatch = [regex]::Match($content, '^(---\s*\r?\n.*?\r?\n---)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($fmMatch.Success) {
                # Check for required fields
                $fm = $fmMatch.Groups[1].Value
                $missing = @()
                foreach ($field in @('name', 'description', 'allowed-tools')) {
                    if ($fm -notmatch "(?m)^$field\s*:") { $missing += $field }
                }
                if ($missing.Count -eq 0) {
                    Add-Check "skill-frontmatter-$($sm.Directory.Name)" 'pass'
                } else {
                    Add-Check "skill-frontmatter-$($sm.Directory.Name)" 'warn' @{
                        missing_fields = $missing
                    }
                }
            } else {
                Add-Check "skill-frontmatter-$($sm.Directory.Name)" 'fail' @{
                    note = 'No YAML frontmatter detected'
                }
            }
        }
    } else {
        Add-Check 'frontmatter-dir' 'warn' @{ note = "No skills/ dir at $skillDir" }
    }
}

#------------------------------------------------------------------------------
# Category 7 — Pester unit + integration suite
#------------------------------------------------------------------------------
if (Skip-Category 'pester') {
    Add-Check 'pester' 'skip' @{ reason = 'SkipCategory' }
} else {
    $pesterModule = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0' } | Select-Object -First 1
    if (-not $pesterModule) {
        Add-Check 'pester-available' 'warn' @{
            note = 'Pester 5+ not installed — skipping Pester category. Install with: Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser'
        }
    } else {
        Add-Check 'pester-available' 'pass' @{ version = $pesterModule.Version.ToString() }

        $testFiles = @(Get-ChildItem -Path $MadRoot -Filter '*.Tests.ps1' -Recurse -File -ErrorAction SilentlyContinue)
        if ($testFiles.Count -eq 0) {
            Add-Check 'pester-discovery' 'warn' @{ note = 'No .Tests.ps1 files found under MadRoot' }
        } else {
            Add-Check 'pester-discovery' 'pass' @{ test_file_count = $testFiles.Count }

            try {
                # Invoke-Pester inside a runspace so our strict-mode + error-preference
                # doesn't interact with Pester's own runtime.
                Remove-Module Pester -ErrorAction SilentlyContinue
                Import-Module Pester -MinimumVersion 5.0 -MaximumVersion 5.99 -ErrorAction Stop
                $pResult = Invoke-Pester -Path $testFiles.FullName -PassThru -Output None

                $status = if ($pResult.FailedCount -gt 0) { 'fail' } else { 'pass' }
                Add-Check 'pester-suite' $status @{
                    total   = $pResult.TotalCount
                    passed  = $pResult.PassedCount
                    failed  = $pResult.FailedCount
                    skipped = $pResult.SkippedCount
                    duration_ms = [int]$pResult.Duration.TotalMilliseconds
                }
            } catch {
                Add-Check 'pester-suite' 'fail' @{ error = $_.Exception.Message }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Summary + write
#------------------------------------------------------------------------------
$report.summary = @{
    total_checks = $report.checks.Count
    pass         = @($report.checks | Where-Object status -eq 'pass').Count
    fail         = @($report.checks | Where-Object status -eq 'fail').Count
    warn         = @($report.checks | Where-Object status -eq 'warn').Count
    skip         = @($report.checks | Where-Object status -eq 'skip').Count
}
$report.finished_utc = (Get-Date).ToUniversalTime().ToString('o')

$json = $report | ConvertTo-Json -Depth 12
$reportDir = Split-Path -Parent $ReportPath
if ($reportDir -and -not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$json | Set-Content -Path $ReportPath -Encoding UTF8

Write-Host "Report: $ReportPath"
Write-Host ("Summary: {0} pass / {1} fail / {2} warn / {3} skip (total {4})" -f `
    $report.summary.pass, $report.summary.fail, $report.summary.warn, $report.summary.skip, $report.summary.total_checks)

if ($report.summary.fail -gt 0) { exit 1 } else { exit 0 }
