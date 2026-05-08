<#
.SYNOPSIS
  Atomic JSON write via .tmp + rename pattern. The concurrency primitive underlying
  every mutable state file in MAD.Council (channel.json, digest.json, seq.json,
  thread.json, read-marker, verdict.json, retro.json, Completion Reports).

.DESCRIPTION
  Writes JSON content to a temporary file, then atomically renames to the target
  path. `rename()` is atomic on POSIX (ext4, btrfs, HFS+, APFS) and on Windows NTFS
  via MoveFileEx with MOVEFILE_REPLACE_EXISTING. Readers see either the pre-update
  or the post-update file — never a half-written state.

  Failure modes:
    - Temp write fails (permission, disk full) → throws; no target change.
    - Rename fails (target held open, cross-filesystem) → throws; .tmp orphan
      remains for cleanup by preflight.ps1 on next session.
    - Target file partially written and rename succeeded → impossible by design.

  Retry: 2 attempts on rename failure with 50ms backoff. After 2 retries, throws.
  (Matches mad.council.a2a.md §10.2 retry table: "channel.json atomic write: 2 retries, 10s timeout".)

.PARAMETER Path
  Absolute path to the target file. Must be writable by the current user.

.PARAMETER Content
  The object to serialize as JSON. Uses ConvertTo-Json with -Depth 20 to handle
  nested structures (messages with mentions, members with agent_cards, etc.).

.PARAMETER Encoding
  File encoding. Default: UTF8 (BOM-less, matches most editors' defaults on modern
  tooling).

.PARAMETER MaxRetries
  Number of rename retries on failure. Default: 2.

.PARAMETER RetryDelayMs
  Milliseconds between retries. Default: 50.

.OUTPUTS
  None. Throws on unrecoverable error.

.NOTES
  Invariants enforced:
    1. Target file either has pre-state or post-state; never half-written.
    2. On PowerShell pwsh 7+, Move-Item -Force provides atomic rename semantics
       matching OS primitives.
    3. The .tmp file is uniquely named per-writer to avoid collisions when two
       writers race on the same target.

  Used by: every mutable-state write in every skill. Cited in:
    - rules/concurrency-safety.md §2 (atomic-write pattern)
    - skills/council-open/plan.md step 7
    - skills/council-join/plan.md step 7, step 10
    - skills/council-post/plan.md step 10, 11, 12
    - skills/council-check/plan.md step 3h, 3i
    - skills/council-leave/plan.md step 6, 7, 8
    - skills/council-review/plan.md step 11
    - skills/council-verdict/plan.md step 6, 7
    - skills/council-resolve/plan.md step 4
    - skills/council-retro/plan.md step 6
#>

Set-StrictMode -Version Latest

function Write-AtomicJson {
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object] $Content,

        [Parameter(Mandatory = $false)]
        [string] $Encoding = 'UTF8',

        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 2,

        [Parameter(Mandatory = $false)]
        [int] $RetryDelayMs = 50
    )

    # 1. Serialize content (Depth 20 handles deeply-nested channel.json / verdict.json).
    $json = $Content | ConvertTo-Json -Depth 20

    # 2. Unique .tmp path per writer — GUID suffix defeats concurrent-writer collisions.
    $tmpSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $tmp = "${Path}.${tmpSuffix}.tmp"

    # 3. Write serialized JSON to .tmp. Out-File -Encoding UTF8 emits BOM-less UTF-8 on pwsh 7+.
    try {
        $json | Out-File -FilePath $tmp -Encoding $Encoding -NoNewline -Force
    } catch {
        throw "Cannot write temp file at ${tmp}: $($_.Exception.Message)"
    }

    # 4. Atomic rename with bounded retry.
    $attempt = 0
    while ($true) {
        try {
            Move-Item -LiteralPath $tmp -Destination $Path -Force -ErrorAction Stop
            break
        } catch {
            if ($attempt -ge $MaxRetries) {
                # Leave $tmp for preflight.ps1 sweep.
                throw "Atomic rename failed after $MaxRetries retries: ${Path} (temp at ${tmp}; will be swept by next preflight). Underlying: $($_.Exception.Message)"
            }
            $attempt++
            Start-Sleep -Milliseconds $RetryDelayMs
        }
    }

    # 5. Sanity check — target must be readable post-rename.
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Rename succeeded but target not readable: ${Path}"
    }
}

function Read-AtomicJson {
    <#
    .SYNOPSIS
      Paired read helper. Opens for shared-read; tolerates concurrent writers
      doing atomic rename.

    .DESCRIPTION
      Reads JSON with `-Raw` for whole-file atomicity. If a writer renames during
      our read, we either get the pre- or post-state (both valid). No locking.

    .PARAMETER Path
      Absolute path to the JSON file.

    .PARAMETER MaxRetries
      On JSON parse failure (indicates we caught a racing write mid-rename on some
      filesystems), retry up to this many times. Default: 1.

    .OUTPUTS
      Deserialized PSCustomObject. Throws on unrecoverable error (file missing,
      persistent parse error, permission denied).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 1,

        [Parameter(Mandatory = $false)]
        [int] $RetryDelayMs = 50
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: ${Path}"
    }

    $attempt = 0
    while ($true) {
        $raw = $null
        try {
            $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
            # Empty file is a legitimate failure; don't silently return $null.
            if ([string]::IsNullOrWhiteSpace($raw)) {
                throw "Empty or whitespace-only file: ${Path}"
            }
            return $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            if ($attempt -ge $MaxRetries) {
                throw "Failed to read JSON from ${Path} after $MaxRetries retries: $($_.Exception.Message)"
            }
            $attempt++
            Start-Sleep -Milliseconds $RetryDelayMs
        }
    }
}

# Export (for dot-sourcing):
# . ./atomic-write.ps1
# Write-AtomicJson -Path /path/to/file.json -Content $obj
# $obj = Read-AtomicJson -Path /path/to/file.json
