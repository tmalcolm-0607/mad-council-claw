# TaskCompleted Hook - Validates mad-validate output and logs advisory warnings on failure
# Lifecycle: Fires after any task marked complete (TaskUpdate status=completed)
# Exit codes: 0 = always (TaskCompleted is advisory and cannot block)
#
# Claude Code delivers hook data as JSON on stdin. This hook reads stdin,
# extracts skill_name/work_item_id from the payload, and checks validation results.

param()

# Read and parse stdin JSON payload from Claude Code
# Fields vary by event; we look for task/skill context fields.
$stdinPayload = $null
try {
    $ErrorActionPreference = 'Stop'
    $rawInput = [Console]::In.ReadToEnd()
    if ($rawInput -and $rawInput.Trim().Length -gt 0) {
        $stdinPayload = $rawInput | ConvertFrom-Json
    }
} catch {
    # stdin empty or not valid JSON -- exit gracefully
    exit 0
} finally {
    $ErrorActionPreference = 'Continue'
}

if (-not $stdinPayload) {
    # No payload available -- nothing to validate
    exit 0
}

# Extract fields from the JSON payload.
# Claude Code TaskCompleted payloads may include: tool_name, tool_input,
# task_description, skill_name, work_item_id, or nested structures.
# We try multiple field names for resilience.
$skillName = $null
$workItemId = $null

# Try direct fields first, then nested under tool_input
foreach ($field in @('skill_name', 'skillName', 'task_name', 'taskName')) {
    $val = $stdinPayload.PSObject.Properties[$field]
    if ($val -and $val.Value) {
        $skillName = $val.Value
        break
    }
}

# Try tool_input nested fields if direct fields are not present
if (-not $skillName -and $stdinPayload.PSObject.Properties['tool_input']) {
    $toolInput = $stdinPayload.tool_input
    if ($toolInput -and $toolInput.PSObject.Properties['skill_name']) {
        $skillName = $toolInput.skill_name
    }
}

foreach ($field in @('work_item_id', 'workItemId', 'work_item')) {
    $val = $stdinPayload.PSObject.Properties[$field]
    if ($val -and $val.Value) {
        $workItemId = $val.Value
        break
    }
}

if (-not $workItemId -and $stdinPayload.PSObject.Properties['tool_input']) {
    $toolInput = $stdinPayload.tool_input
    if ($toolInput -and $toolInput.PSObject.Properties['work_item_id']) {
        $workItemId = $toolInput.work_item_id
    }
}

# Check if this is a mad-validate skill completion
if ($skillName -ne 'mad-validate') {
    # Not mad-validate, nothing to check
    exit 0
}

# Ensure work_item_id is available
if (-not $workItemId) {
    Write-Warning "TaskCompleted: work_item_id not found in payload -- cannot locate validation results"
    exit 0
}

# Construct validation results path
$validationJsonPath = ".claude/work-items/$workItemId/artifacts/validation/validation-results.json"

# Check if validation results exist
if (-not (Test-Path $validationJsonPath)) {
    Write-Warning "TaskCompleted: No validation results found at $validationJsonPath"
    exit 0
}

# Parse validation JSON
try {
    $ErrorActionPreference = 'Stop'
    $validationResults = Get-Content $validationJsonPath -Raw | ConvertFrom-Json
} catch {
    Write-Warning "TaskCompleted: Invalid validation JSON format at $validationJsonPath -- $($_.Exception.Message)"
    exit 0
} finally {
    $ErrorActionPreference = 'Continue'
}

# Check all 4 lens results
$lensNames = @('contract', 'spec', 'tests', 'living-docs')
$allPassed = $true

foreach ($lens in $lensNames) {
    if (-not $validationResults.PSObject.Properties.Name -contains $lens) {
        Write-Warning "TaskCompleted: Lens '$lens' missing from validation results"
        $allPassed = $false
        continue
    }

    $lensResult = $validationResults.$lens

    if ($lensResult.status -ne 'PASS') {
        Write-Warning "TaskCompleted FAIL: Lens '$lens' failed with status: $($lensResult.status)"
        $allPassed = $false
    } else {
        Write-Output "TaskCompleted PASS: Lens '$lens' passed"
    }
}

# Report result -- advisory only, always exit 0
if ($allPassed) {
    Write-Output "TaskCompleted: All validation lenses passed"
} else {
    Write-Warning "TaskCompleted: One or more validation lenses failed -- review results before proceeding"
}

exit 0
