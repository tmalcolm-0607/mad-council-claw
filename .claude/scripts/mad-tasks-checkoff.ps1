<#
.SYNOPSIS
  Atomically update [T###] task checkboxes in tasks.md to [x] when referenced
  in resolve messages.
  Phase-2 deliverable for skills/council-resolve/plan.md Step 4.

.DESCRIPTION
  Used by /council-resolve to mark MAD tasks as done when their IDs appear
  in a resolve-message summary or in thread messages. Reads tasks.md, finds
  lines of shape `- [ ] [T001] Task description` (GFM task list syntax),
  updates matching rows to `- [x] [T001] ...`, writes the result atomically.

  Task ID format: [T###] where ### is 1-4 digits (T1, T001, T1234 all valid).
  Case-sensitive on the 'T'; task IDs in tasks.md should always be uppercase.

  Idempotent: already-checked boxes are left as-is with no-op.
  Unknown task IDs: warned but not errors (resolve succeeds anyway per
  council-resolve/plan.md Step 4 fallback).

.PARAMETER TasksPath
  Path to tasks.md. Required.

.PARAMETER TaskIds
  Array of task ID strings (with or without surrounding brackets — both
  "T001" and "[T001]" accepted; normalized internally).

.PARAMETER WhatIf
  Standard -WhatIf support: show what would change, don't write.

.OUTPUTS
  PSCustomObject {
    tasks_path:      string
    requested_count: int
    checked_count:   int (newly set; idempotent no-ops not counted)
    not_found:       string[] (task IDs requested but not matched)
    already_checked: string[] (task IDs already [x] in input)
  }

.NOTES
  Atomic write via scripts/atomic-write.ps1 Write-AtomicJson equivalent —
  we use direct temp+rename here since tasks.md is text not JSON.
  Rule anchor: rules/concurrency-safety.md (atomic rename).
  Test coverage: scripts/mad-tasks-checkoff.Tests.ps1.

.EXAMPLE
  Invoke-MadTasksCheckoff -TasksPath 'specs/001-feat/tasks.md' -TaskIds @('T001','T003')
#>

Set-StrictMode -Version Latest

function script:Test-TaskIdFormat {
    param([string] $Id)
    # Accept with or without brackets. Normalize to "T###"
    $s = $Id.Trim() -replace '^\[', '' -replace '\]$', ''
    if ($s -match '^T(\d{1,4})$') { return $s }
    return $null
}

function Invoke-MadTasksCheckoff {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string] $TasksPath,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [string[]] $TaskIds
    )

    if (-not (Test-Path -LiteralPath $TasksPath -PathType Leaf)) {
        throw "tasks.md not found at: $TasksPath"
    }

    # Normalize IDs
    $requested = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($id in $TaskIds) {
        $norm = Test-TaskIdFormat -Id $id
        if ($norm) { [void]$requested.Add($norm) }
    }

    if ($requested.Count -eq 0) {
        return [pscustomobject]@{
            tasks_path      = $TasksPath
            requested_count = 0
            checked_count   = 0
            not_found       = @()
            already_checked = @()
        }
    }

    # Read file
    $original = Get-Content -LiteralPath $TasksPath -Raw -Encoding UTF8
    $lines = $original -split "`r?`n"

    $checked = @()
    $alreadyChecked = @()
    $matchedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Match patterns:
        #   - [ ] [T001] ...         (GFM task list)
        #   - [x] [T001] ...         (already checked)
        #   * [ ] [T001] ...         (alternate bullet)
        #   1. [ ] [T001] ...        (numbered)
        $m = [regex]::Match($line, '^(\s*(?:[-*]|\d+\.)\s*\[)([ xX])(\]\s*\[)(T\d{1,4})(\])(.*)$')
        if (-not $m.Success) { continue }
        $state = $m.Groups[2].Value
        $id = $m.Groups[4].Value
        if (-not $requested.Contains($id)) { continue }

        [void]$matchedIds.Add($id)

        if ($state -eq ' ') {
            # Mark checked
            $lines[$i] = "$($m.Groups[1].Value)x$($m.Groups[3].Value)$($m.Groups[4].Value)$($m.Groups[5].Value)$($m.Groups[6].Value)"
            $checked += $id
        } else {
            # already [x] or [X]
            $alreadyChecked += $id
        }
    }

    $notFound = @($requested | Where-Object { -not $matchedIds.Contains($_) })

    # Atomic write
    if ($checked.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($TasksPath, "Update $($checked.Count) task(s)")) {
            $newContent = $lines -join "`n"
            # atomic rename pattern: write temp, rename
            $tempPath = "$TasksPath.$(Get-Random).tmp"
            try {
                [System.IO.File]::WriteAllText($tempPath, $newContent, [System.Text.UTF8Encoding]::new($false))
                Move-Item -LiteralPath $tempPath -Destination $TasksPath -Force
            } catch {
                if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
                throw
            }
        }
    }

    return [pscustomobject]@{
        tasks_path      = $TasksPath
        requested_count = $requested.Count
        checked_count   = $checked.Count
        not_found       = $notFound
        already_checked = $alreadyChecked
    }
}
