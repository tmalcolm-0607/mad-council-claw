# TeammateIdle Hook - Cleanup and coordination when Agent Teams teammates idle
# Lifecycle: Fires when teammate enters idle state (completed, waiting, or error)
# Exit codes: 0 = always (TeammateIdle is advisory and cannot block)
#
# Claude Code delivers hook data as JSON on stdin. This hook reads stdin,
# extracts teammate_id, team_name, and idle_reason from the payload.

param()

# Read and parse stdin JSON payload from Claude Code
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
    # No payload available -- nothing to do
    exit 0
}

# Extract fields from the JSON payload.
# Try multiple field name conventions for resilience.
$teammateId = $null
$teamName = $null
$idleReason = $null

foreach ($field in @('teammate_id', 'teammateId', 'agent_id', 'agentId')) {
    $val = $stdinPayload.PSObject.Properties[$field]
    if ($val -and $val.Value) {
        $teammateId = $val.Value
        break
    }
}

foreach ($field in @('team_name', 'teamName')) {
    $val = $stdinPayload.PSObject.Properties[$field]
    if ($val -and $val.Value) {
        $teamName = $val.Value
        break
    }
}

foreach ($field in @('idle_reason', 'idleReason', 'reason', 'status')) {
    $val = $stdinPayload.PSObject.Properties[$field]
    if ($val -and $val.Value) {
        $idleReason = $val.Value
        break
    }
}

# Validate teammate_id is available
if (-not $teammateId) {
    Write-Warning "TeammateIdle: teammate_id not found in payload, cannot cleanup"
    exit 0
}

if (-not $teamName) {
    Write-Warning "TeammateIdle: team_name not found in payload, using default cleanup"
    $teamName = "unknown-team"
}

# Construct scratch directory path
$scratchDir = ".mad/scratch/agent-teams/$teamName/$teammateId"

# Check if scratch directory exists
if (-not (Test-Path $scratchDir)) {
    Write-Output "TeammateIdle: Scratch directory $scratchDir does not exist (already cleaned or never created)"
    exit 0
}

# Log handoff or error based on idle reason
if ($idleReason) {
    switch ($idleReason) {
        'completed' {
            Write-Output "TeammateIdle: Teammate $teammateId completed successfully"
        }
        'error' {
            Write-Warning "TeammateIdle: Teammate $teammateId encountered an error"
        }
        'waiting' {
            Write-Output "TeammateIdle: Teammate $teammateId is waiting (idle)"
        }
        default {
            Write-Output "TeammateIdle: Teammate $teammateId idle with reason: $idleReason"
        }
    }
}

# Cleanup scratch directory
try {
    $ErrorActionPreference = 'Stop'
    Remove-Item -Path $scratchDir -Recurse -Force
    Write-Output "TeammateIdle: Cleaned up scratch directory for teammate $teammateId"
} catch {
    Write-Warning "TeammateIdle: Failed to cleanup scratch directory $scratchDir -- $($_.Exception.Message)"
    # Don't block on cleanup failure
} finally {
    $ErrorActionPreference = 'Continue'
}

exit 0
