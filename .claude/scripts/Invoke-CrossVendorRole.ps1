<#
.SYNOPSIS
    Invoke a Council role on a non-Anthropic model via Copilot CLI.
    Returns a strict-JSON role output that matches the same schema as Anthropic-routed
    Task-tool roles (advocate / skeptic / architect agent.md output contracts).

.DESCRIPTION
    /council-review uses this by default to route the Skeptic role onto a
    different vendor than Opus, so cross-model agreement becomes a genuine
    independent-vendor signal rather than three-roles-of-the-same-model.

    Copilot CLI (`copilot`) brokers GPT models. We invoke it with --yolo (non-interactive
    capture) + --model + a stdin prompt, capture stdout, validate it parses as JSON
    with the role's required fields, and return.

    On any failure (CLI absent, auth, timeout, malformed output), we write a
    structured error JSON the orchestrator can treat as `completed: false` and
    proceed with surviving roles per rules/degradation-fallback-policy.md Rule 5.

.PARAMETER Role
    Which Council role contract to apply. Determines required output fields.

.PARAMETER BriefFile
    Path to the role brief markdown file written by /council-review Step 3.

.PARAMETER OutputFile
    Where to write the parsed role-output JSON.

.PARAMETER Model
    Copilot CLI --model identifier. Default: gpt-5.5.

.PARAMETER CopilotCommand
    Override the resolved Copilot CLI command. Default: auto-detect (copilot vs agency copilot).

.PARAMETER TimeoutSeconds
    Hard ceiling per CHK-043 (4 min stays under the 5-min Claude Code stream abort).

.PARAMETER WhatIf
    Compose the prompt and validate inputs without invoking Copilot.

.EXAMPLE
    .\Invoke-CrossVendorRole.ps1 -Role skeptic `
        -BriefFile .mad/scratch/review-12345/skeptic-brief.md `
        -OutputFile .mad/scratch/review-12345/skeptic-result.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('advocate', 'skeptic', 'architect')]
    [string]$Role,

    [Parameter(Mandatory)]
    [string]$BriefFile,

    [Parameter(Mandatory)]
    [string]$OutputFile,

    [string]$Model = 'gpt-5.5',

    [string]$CopilotCommand,

    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'

# --- Validate inputs ---
if (-not (Test-Path $BriefFile)) {
    Write-Error "Brief file not found: $BriefFile"
}

$briefText = Get-Content $BriefFile -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($briefText)) {
    Write-Error "Brief file is empty: $BriefFile"
}

# --- Resolve Copilot CLI command ---
if (-not $CopilotCommand) {
    $ErrorActionPreference = 'Continue'
    $copilotResolved = (Get-Command copilot -ErrorAction SilentlyContinue).Source
    if (-not $copilotResolved) {
        $copilotResolved = (Get-Command agency -ErrorAction SilentlyContinue).Source
        if ($copilotResolved) { $CopilotCommand = 'agency copilot' }
    }
    else {
        $CopilotCommand = 'copilot'
    }
    $ErrorActionPreference = 'Stop'
}

if (-not $CopilotCommand) {
    $errPayload = @{
        role             = $Role
        role_confidence  = 0
        findings         = @()
        evidence_incomplete = $true
        completed        = $false
        error            = 'copilot CLI not found on PATH; install from https://aka.ms/copilot-cli'
    } | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
    Write-Host "FAIL: copilot CLI not found." -ForegroundColor Red
    exit 2
}

# --- Compose role-specific output-format addendum ---
# The brief itself contains role mindset + inputs + constraints. We append a strict
# JSON-only response directive matching the Anthropic-side agent.md output contract.
$roleSchemaHint = switch ($Role) {
    'advocate' {
        @'
You are the Advocate (defender) in a 3-role Council review. Reconstruct intent,
flag uncertainties the author themselves had. Output STRICT JSON ONLY (no prose,
no fences) matching this schema:

{
  "role": "Advocate",
  "role_confidence": 0.0-1.0,
  "findings": [
    {
      "id": "advocate-01",
      "severity": "CRITICAL|HIGH|MEDIUM|LOW|OBSERVATION",
      "category": "intent|uncertainty|defense",
      "evidence": "<file:line or message-id>",
      "title": "<short>",
      "description": "<full>",
      "confidence": 0.0-1.0,
      "annotations": []
    }
  ],
  "evidence_incomplete": false
}
'@
    }
    'skeptic' {
        @'
You are the Skeptic (attacker) in a 3-role Council review. Assume there is a
flaw; find it. Trace data flow, races, boundaries, auth, dependency failures.
Output STRICT JSON ONLY (no prose, no fences) matching this schema:

{
  "role": "Skeptic",
  "role_confidence": 0.0-1.0,
  "findings": [
    {
      "id": "skeptic-01",
      "severity": "CRITICAL|HIGH|MEDIUM|LOW|OBSERVATION",
      "category": "correctness|race|boundary|auth|dependency|input-attack|silent-fail",
      "evidence": "<file:line or message-id>",
      "title": "<short>",
      "description": "<full -- include the attack scenario or failure path>",
      "confidence": 0.0-1.0,
      "proposed_impact": "<what breaks if unfixed>",
      "annotations": []
    }
  ],
  "evidence_incomplete": false
}

Rules: every finding needs file:line evidence + concrete failure path.
Max 10-12 findings. Prioritize runtime behaviour over style. Do not pad
confidence; 0.4 is a legitimate value.
'@
    }
    'architect' {
        @'
You are the Architect (evaluator) in a 3-role Council review. Evaluate
direction, coupling, single-source-of-truth violations, evolutionary fit.
Output STRICT JSON ONLY (no prose, no fences) matching this schema:

{
  "role": "Architect",
  "role_confidence": 0.0-1.0,
  "findings": [
    {
      "id": "architect-01",
      "severity": "CRITICAL|HIGH|MEDIUM|LOW|OBSERVATION",
      "category": "coupling|duplication|sot-violation|direction|fitness",
      "evidence": "<file:line or section reference>",
      "title": "<short>",
      "description": "<full>",
      "confidence": 0.0-1.0,
      "annotations": []
    }
  ],
  "evidence_incomplete": false
}
'@
    }
}

$composedPrompt = $briefText + "`n`n---`n`n" + $roleSchemaHint

# Persist composed prompt for auditability
$promptDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $promptDir)) { New-Item -ItemType Directory -Path $promptDir -Force | Out-Null }
$promptFile = Join-Path $promptDir "$Role-prompt.md"
[System.IO.File]::WriteAllText($promptFile, $composedPrompt, [System.Text.UTF8Encoding]::new($false))

Write-Host "=== Cross-Vendor Council Role ===" -ForegroundColor Cyan
Write-Host "Role:    $Role"
Write-Host "Model:   $Model"
Write-Host "CLI:     $CopilotCommand"
Write-Host "Brief:   $BriefFile"
Write-Host "Prompt:  $promptFile"
Write-Host "Output:  $OutputFile"
Write-Host "Timeout: ${TimeoutSeconds}s"
Write-Host ""

if ($PSCmdlet.ShouldProcess("Copilot CLI ($Model)", "Invoke role=$Role")) {
    # --- Invoke Copilot CLI with timeout ---
    # Pattern: pass prompt via -p; capture stdout to file; --yolo for non-interactive
    $stdoutFile = "$OutputFile.raw"
    $stderrFile = "$OutputFile.err"

    $copilotArgs = @('--yolo', '--model', $Model, '-p', $composedPrompt)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $CopilotCommand.Split(' ')[0]
    if ($CopilotCommand -match ' ') {
        # e.g. "agency copilot": first arg is "copilot"
        $extra = $CopilotCommand.Split(' ', 2)[1]
        $startInfo.ArgumentList.Add($extra) | Out-Null
    }
    foreach ($a in $copilotArgs) { $startInfo.ArgumentList.Add($a) | Out-Null }
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $startInfo
    $proc.Start() | Out-Null

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $exited = $proc.WaitForExit($TimeoutSeconds * 1000)

    if (-not $exited) {
        try { $proc.Kill($true) } catch { }
        $errPayload = @{
            role             = $Role
            role_confidence  = 0
            findings         = @()
            evidence_incomplete = $true
            completed        = $false
            timed_out        = $true
            error            = "copilot CLI exceeded ${TimeoutSeconds}s timeout"
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
        Write-Host "FAIL: timeout after ${TimeoutSeconds}s" -ForegroundColor Red
        exit 4
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    [System.IO.File]::WriteAllText($stdoutFile, $stdout, [System.Text.UTF8Encoding]::new($false))
    if ($stderr) { [System.IO.File]::WriteAllText($stderrFile, $stderr, [System.Text.UTF8Encoding]::new($false)) }

    if ($proc.ExitCode -ne 0) {
        $errPayload = @{
            role             = $Role
            role_confidence  = 0
            findings         = @()
            evidence_incomplete = $true
            completed        = $false
            error            = "copilot CLI exit $($proc.ExitCode); stderr=$($stderr.Substring(0, [Math]::Min(500, $stderr.Length)))"
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
        Write-Host "FAIL: copilot exit $($proc.ExitCode)" -ForegroundColor Red
        exit 3
    }

    # --- Validate JSON shape ---
    # Copilot may emit trailing prose around a fenced JSON block; extract first JSON object.
    $jsonText = $stdout
    $match = [regex]::Match($jsonText, '(?s)\{.*\}')
    if (-not $match.Success) {
        $errPayload = @{
            role             = $Role
            role_confidence  = 0
            findings         = @()
            evidence_incomplete = $true
            completed        = $false
            error            = "no JSON object found in copilot output (raw saved to $stdoutFile)"
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
        Write-Host "FAIL: malformed output -- no JSON object found" -ForegroundColor Red
        exit 5
    }
    $jsonOnly = $match.Value

    try {
        $parsed = $jsonOnly | ConvertFrom-Json
    }
    catch {
        $errPayload = @{
            role             = $Role
            role_confidence  = 0
            findings         = @()
            evidence_incomplete = $true
            completed        = $false
            error            = "JSON parse failed: $_"
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
        Write-Host "FAIL: JSON parse error" -ForegroundColor Red
        exit 5
    }

    # Required fields per role agent.md output contracts
    foreach ($field in @('role', 'role_confidence', 'findings')) {
        if (-not $parsed.PSObject.Properties.Name.Contains($field)) {
            $errPayload = @{
                role             = $Role
                role_confidence  = 0
                findings         = @()
                evidence_incomplete = $true
                completed        = $false
                error            = "JSON missing required field: $field"
            } | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($OutputFile, $errPayload, [System.Text.UTF8Encoding]::new($false))
            Write-Host "FAIL: missing required field '$field'" -ForegroundColor Red
            exit 5
        }
    }

    # Annotate vendor metadata so the orchestrator can apply cross-vendor agreement scoring
    $augmented = [ordered]@{
        role               = $parsed.role
        role_confidence    = $parsed.role_confidence
        findings           = $parsed.findings
        evidence_incomplete = if ($parsed.PSObject.Properties.Name.Contains('evidence_incomplete')) { $parsed.evidence_incomplete } else { $false }
        completed          = $true
        vendor             = 'openai'
        model_id           = $Model
    }
    $augmentedJson = $augmented | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($OutputFile, $augmentedJson, [System.Text.UTF8Encoding]::new($false))

    $findingCount = if ($parsed.findings) { $parsed.findings.Count } else { 0 }
    Write-Host "OK: role=$Role findings=$findingCount confidence=$($parsed.role_confidence)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "WHATIF: would invoke '$CopilotCommand --yolo --model $Model -p <$($composedPrompt.Length) chars>'" -ForegroundColor DarkYellow
    Write-Host "Composed prompt saved to: $promptFile"
    exit 0
}
