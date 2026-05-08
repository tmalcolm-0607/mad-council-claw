<#
.SYNOPSIS
  Validate JSON artifacts against their matching MAD schemas.
  Phase-1b deliverable per `plans/phase-1b-polish-package-dogfood.md`.

.DESCRIPTION
  Walks a target tree (default: `MAD/evals/fixtures/`), matches each `*.json`
  file to its schema by filename convention + parent dir, runs `Test-Json
  -Schema`, emits structured report.

  Filename-to-schema map:
    channel.json                       → schemas/channel.schema.json
    seq.json                           → schemas/seq.schema.json
    digest.json                        → schemas/digest.schema.json
    thread.json                        → schemas/thread.schema.json
    verdict.json                       → schemas/verdict.schema.json
    .sessions.json                     → schemas/sessions.schema.json
    read-markers/<alias>.json          → schemas/read-marker.schema.json
    messages/<seq>-<ts>-<alias>.json   → schemas/message.schema.json
    retros/<ts>-<alias>.json           → schemas/retro.schema.json
    leave-reports/<alias>-<ts>.json    → schemas/completion-report.schema.json

  Unknown filenames produce a 'skip' entry (not a fail) so fixtures authors
  can add new artifact types without breaking existing validation.

.PARAMETER Path
  Target file or directory. Default: `<MadRoot>/evals/fixtures`. If directory,
  recurses. If file, validates that one.

.PARAMETER MadRoot
  MAD root. Default: `<script-dir>/..`.

.PARAMETER ReportPath
  If set, writes JSON report here.

.PARAMETER FailOnInvalid
  If set, exit 1 when any file fails schema validation. Default: report-only.

.OUTPUTS
  PSCustomObject: { files_scanned, valid, invalid, skipped, results: [...] }.

.NOTES
  Used by: sandbox smoke (future), optional pre-commit hook, ad-hoc diagnosis
  of `~/claude-data/channels/` state.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Path = $null,

    [Parameter(Mandatory = $false)]
    [string] $MadRoot = $null,

    [Parameter(Mandatory = $false)]
    [string] $ReportPath = $null,

    [Parameter(Mandatory = $false)]
    [switch] $FailOnInvalid
)

Set-StrictMode -Version Latest

if (-not $MadRoot) {
    $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}
if (-not (Test-Path -LiteralPath $MadRoot)) {
    throw "MadRoot not found: $MadRoot"
}
$MadRoot = (Resolve-Path -LiteralPath $MadRoot).ProviderPath
$schemaDir = Join-Path $MadRoot 'schemas'

if (-not $Path) {
    # In the consumer-install layout, schemas live under .claude/ but eval
    # fixtures stay under .mad/. Probe MadRoot first; fall back to sibling .mad/.
    $probe = Join-Path $MadRoot 'evals' 'fixtures'
    if (Test-Path -LiteralPath $probe) {
        $Path = $probe
    } else {
        $siblingMad = Join-Path (Split-Path $MadRoot -Parent) '.mad'
        $fallback = Join-Path $siblingMad 'evals' 'fixtures'
        if (Test-Path -LiteralPath $fallback) { $Path = $fallback } else { $Path = $probe }
    }
}

# ---- Schema map ------------------------------------------------------------
function script:Resolve-SchemaForFile {
    param([System.IO.FileInfo] $file)

    $name = $file.Name
    $parent = $file.Directory.Name

    # Direct filename match
    switch ($name) {
        'channel.json'      { return 'channel.schema.json' }
        'seq.json'          { return 'seq.schema.json' }
        'digest.json'       { return 'digest.schema.json' }
        'thread.json'       { return 'thread.schema.json' }
        'verdict.json'      { return 'verdict.schema.json' }
        '.sessions.json'    { return 'sessions.schema.json' }
        'consent-log.jsonl' { return 'consent-log.schema.json' }
    }

    # Parent-directory-based match
    switch ($parent) {
        'read-markers' { return 'read-marker.schema.json' }
        'messages'     { return 'message.schema.json' }
        'retros'       { return 'retro.schema.json' }
        'leave-reports'{ return 'completion-report.schema.json' }
    }

    return $null   # unknown — caller emits 'skip'
}

# ---- Cache compiled schemas -----------------------------------------------
$schemaCache = @{}
function script:Load-Schema {
    param([string] $SchemaName)
    if ($schemaCache.ContainsKey($SchemaName)) {
        return $schemaCache[$SchemaName]
    }
    $p = Join-Path $schemaDir $SchemaName
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Schema file missing: $p"
    }
    $content = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    $schemaCache[$SchemaName] = $content
    return $content
}

# ---- Gather target files --------------------------------------------------
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Path not found: $Path — nothing to validate." -ForegroundColor Yellow
    $emptyResult = [pscustomobject]@{
        path            = $Path
        started_utc     = (Get-Date).ToUniversalTime().ToString('o')
        files_scanned   = 0
        valid           = 0
        invalid         = 0
        skipped         = 0
        results         = @()
        status          = 'OK'
    }
    if ($ReportPath) {
        $emptyResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    }
    return $emptyResult
}

$targets = @()
if ((Get-Item -LiteralPath $Path).PSIsContainer) {
    $targets = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue)
} else {
    $targets = @(Get-Item -LiteralPath $Path)
}

# ---- Validate each --------------------------------------------------------
$results = [System.Collections.ArrayList]::new()
$validCount = 0
$invalidCount = 0
$skippedCount = 0

foreach ($f in $targets) {
    $schemaName = script:Resolve-SchemaForFile -file $f
    if (-not $schemaName) {
        [void]$results.Add([pscustomobject]@{
            file   = $f.FullName
            schema = $null
            status = 'skip'
            reason = 'no schema match — unknown filename/parent-dir convention'
        })
        $skippedCount++
        continue
    }

    try {
        $schema = script:Load-Schema -SchemaName $schemaName
    } catch {
        [void]$results.Add([pscustomobject]@{
            file   = $f.FullName
            schema = $schemaName
            status = 'invalid'
            reason = $_.Exception.Message
        })
        $invalidCount++
        continue
    }

    $json = $null
    try {
        $json = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    } catch {
        [void]$results.Add([pscustomobject]@{
            file   = $f.FullName
            schema = $schemaName
            status = 'invalid'
            reason = "cannot read: $($_.Exception.Message)"
        })
        $invalidCount++
        continue
    }

    $isValid = $false
    $errorMsg = $null
    try {
        $isValid = Test-Json -Json $json -Schema $schema -ErrorAction Stop
    } catch {
        $errorMsg = $_.Exception.Message
    }

    if ($isValid) {
        [void]$results.Add([pscustomobject]@{
            file   = $f.FullName
            schema = $schemaName
            status = 'valid'
        })
        $validCount++
    } else {
        [void]$results.Add([pscustomobject]@{
            file   = $f.FullName
            schema = $schemaName
            status = 'invalid'
            reason = if ($errorMsg) { $errorMsg } else { 'Test-Json returned false without error' }
        })
        $invalidCount++
    }
}

$overall = if ($invalidCount -gt 0) { 'Fail' } elseif ($validCount -eq 0 -and $skippedCount -eq 0) { 'OK' } else { 'OK' }

$result = [pscustomobject]@{
    path            = $Path
    started_utc     = (Get-Date).ToUniversalTime().ToString('o')
    files_scanned   = $targets.Count
    valid           = $validCount
    invalid         = $invalidCount
    skipped         = $skippedCount
    results         = @($results)
    status          = $overall
}

if ($ReportPath) {
    $dir = Split-Path -Parent $ReportPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

Write-Host ("validate-schemas: {0} scanned, {1} valid, {2} invalid, {3} skipped." -f `
    $result.files_scanned, $result.valid, $result.invalid, $result.skipped)

if ($FailOnInvalid -and $invalidCount -gt 0) {
    Write-Host 'Invalid files:' -ForegroundColor Yellow
    foreach ($r in @($results | Where-Object status -eq 'invalid' | Select-Object -First 10)) {
        Write-Host "  $($r.file) [$($r.schema)]: $($r.reason)"
    }
    exit 1
}

return $result
