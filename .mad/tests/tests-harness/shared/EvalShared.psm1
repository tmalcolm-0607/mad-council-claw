# EvalShared.psm1 - Shared utility functions for agent evaluation infrastructure
#
# Module Manifest:
#   Name: EvalShared
#   Version: 1.0.0
#   Description: Core utility functions extracted from Run-LocalEval.ps1 for reuse
#                across multiple eval types (Eval01-Eval07).
#   Exported Functions: Write-Status, Get-UtcTimestamp, Get-EpochSeconds, New-Assertion,
#                       Get-DirectoryHash, Get-WorkspaceChecksum, Invoke-SecretRedaction,
#                       Build-DebugReport

$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    $colors = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    $prefix = @{ Info = '[*]'; Success = '[+]'; Warning = '[!]'; Error = '[-]' }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Get-UtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Get-EpochSeconds {
    return [int][double]::Parse(
        (Get-Date -Date (Get-Date).ToUniversalTime() -UFormat '%s')
    )
}

function New-Assertion {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Expected = '',
        [string]$Actual = '',
        [string]$Message = ''
    )
    $obj = [ordered]@{ name = $Name; passed = $Passed }
    if ($null -ne $Expected -and $Expected -ne '') { $obj['expected'] = $Expected }
    if ($null -ne $Actual -and $Actual -ne '') { $obj['actual'] = $Actual }
    if ($null -ne $Message -and $Message -ne '') { $obj['message'] = $Message }
    return $obj
}

function Get-DirectoryHash {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Filter = '*.*'
    )
    if (-not (Test-Path $Path)) { return 'no-directory' }

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $files = Get-ChildItem -Path $Path -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue | Sort-Object FullName
        foreach ($f in $files) {
            $relPath = $f.FullName.Substring($Path.Length).TrimStart('\', '/')
            $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($relPath)
            $hash.AppendData($pathBytes)

            $stream = [System.IO.File]::OpenRead($f.FullName)
            try {
                $buffer = New-Object byte[] 8192
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $hash.AppendData($buffer, 0, $read)
                }
            } finally { $stream.Dispose() }
        }
        $hashBytes = $hash.GetHashAndReset()
        return [BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
    } finally {
        $hash.Dispose()
    }
}

function Get-WorkspaceChecksum {
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )
    # Hash all .cs files in workspace to detect scaffold drift
    return Get-DirectoryHash -Path $WorkDir -Filter '*.cs'
}

function Invoke-SecretRedaction {
    param(
        [string]$Content
    )
    if (-not $Content) { return '' }

    # Patterns that match key=value or key: value style secrets
    # Each replacement preserves the key and replaces only the value with [REDACTED]
    $patterns = @(
        @{ Pattern = '(?i)(password\s*[=:]\s*).+';           Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(key\s*[=:]\s*).+';                Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(token\s*[=:]\s*).+';              Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(secret\s*[=:]\s*).+';             Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(connection\s*string\s*[=:]\s*).+'; Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(AccountKey=)[^;]+';               Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(Bearer\s+)\S+';                       Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(sig=)[^&]+';                            Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)("(?:password|secret|token|key)"\s*:\s*")[^"]+(")'
           Replacement = '${1}[REDACTED]${2}' }
        @{ Pattern = '\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
           Replacement = '[REDACTED_JWT]' }
    )

    $result = $Content
    foreach ($p in $patterns) {
        $result = [regex]::Replace($result, $p.Pattern, $p.Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    }
    return $result
}

function Build-DebugReport {
    param(
        [string]$ScenarioName,
        [string]$EvalRunId,
        [string]$Status,
        [array]$AssertionResults,
        [string]$WorkDir
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
    $passedCount = @($AssertionResults | Where-Object { $_.passed -eq $true }).Count
    $failedCount = @($AssertionResults | Where-Object { $_.passed -eq $false }).Count
    $totalCount = $AssertionResults.Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Debug Report: $ScenarioName")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Field | Value |')
    [void]$sb.AppendLine('|-------|-------|')
    [void]$sb.AppendLine("| Scenario | $ScenarioName |")
    [void]$sb.AppendLine("| Run ID | $EvalRunId |")
    [void]$sb.AppendLine("| Timestamp | $timestamp |")
    [void]$sb.AppendLine("| Status | $Status |")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("- Total: $totalCount")
    [void]$sb.AppendLine("- Passed: $passedCount")
    [void]$sb.AppendLine("- Failed: $failedCount")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Per-Assertion Breakdown')
    [void]$sb.AppendLine('')

    foreach ($a in $AssertionResults) {
        $statusIcon = if ($a.passed) { 'PASS' } else { 'FAIL' }
        [void]$sb.AppendLine("### [$statusIcon] $($a.name)")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("- **Status**: $statusIcon")
        if ($a.expected) { [void]$sb.AppendLine("- **Expected**: $($a.expected)") }
        if ($a.actual)   { [void]$sb.AppendLine("- **Actual**: $($a.actual)") }
        if ($a.message)  { [void]$sb.AppendLine("- **Message**: $($a.message)") }

        # File excerpt: if the assertion message or actual value references a file path, show first 20 lines
        $refPath = $null
        $candidates = @($a.message, $a.actual, $a.expected) | Where-Object { $_ }
        foreach ($candidate in $candidates) {
            # Look for file paths (absolute or relative to WorkDir)
            $pathMatch = [regex]::Match($candidate, '(?:[A-Za-z]:\\|/)[\w\\/.\-]+\.\w+')
            if ($pathMatch.Success) {
                $testPath = $pathMatch.Value
                if (Test-Path $testPath) {
                    $refPath = $testPath
                    break
                }
                # Try relative to WorkDir
                if ($WorkDir) {
                    $relPath = Join-Path $WorkDir $testPath
                    if (Test-Path $relPath) {
                        $refPath = $relPath
                        break
                    }
                }
            }
        }
        if ($refPath -and $WorkDir) {
            $resolvedRef = [System.IO.Path]::GetFullPath($refPath)
            $resolvedWork = [System.IO.Path]::GetFullPath($WorkDir)
            if (-not $resolvedRef.StartsWith($resolvedWork, [System.StringComparison]::OrdinalIgnoreCase)) {
                $refPath = $null  # Refuse to read files outside workspace
            }
        }
        if ($refPath) {
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("**File excerpt** (``$refPath``):")
            [void]$sb.AppendLine('```')
            $lines = Get-Content $refPath -TotalCount 20 -ErrorAction SilentlyContinue
            if ($lines) {
                foreach ($line in $lines) { [void]$sb.AppendLine($line) }
            }
            [void]$sb.AppendLine('```')
        }
        [void]$sb.AppendLine('')
    }

    return $sb.ToString()
}

# Export all public functions
Export-ModuleMember -Function @(
    'Write-Status',
    'Get-UtcTimestamp',
    'Get-EpochSeconds',
    'New-Assertion',
    'Get-DirectoryHash',
    'Get-WorkspaceChecksum',
    'Invoke-SecretRedaction',
    'Build-DebugReport'
)
