#Requires -Version 7
<#
.SYNOPSIS
  Foreground launcher for the MAD UI.
  Phase-1c Day 4 deliverable per `plans/phase-1c-local-ui.md`.

.DESCRIPTION
  Starts `server.ps1` + opens the default browser to
  http://127.0.0.1:<port>/. Ctrl+C stops the listener cleanly.

.PARAMETER Port
  TCP port (default 9292).

.PARAMETER NoBrowser
  Don't auto-open the browser.

.PARAMETER BindAll
  Bind 0.0.0.0 instead of 127.0.0.1. Rejected unless
  `$env:MAD_UI_ALLOW_BIND_ALL='yes'`.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [int] $Port = 9292,
    [Parameter(Mandatory = $false)] [switch] $NoBrowser,
    [Parameter(Mandatory = $false)] [switch] $BindAll,
    [Parameter(Mandatory = $false)] [string] $MadRoot = $null,
    [Parameter(Mandatory = $false)] [string] $ClaudeDataRoot = $null
)

Set-StrictMode -Version Latest

$server = Join-Path $PSScriptRoot 'server.ps1'
if (-not (Test-Path -LiteralPath $server)) { throw "server.ps1 not found at $server" }

. $server

if (-not $MadRoot) { $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath }
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}

if ($BindAll -and $env:MAD_UI_ALLOW_BIND_ALL -ne 'yes') {
    throw 'Refusing -BindAll without explicit MAD_UI_ALLOW_BIND_ALL=yes env-var.'
}

$handle = Start-MadUIServer -Port $Port -MadRoot $MadRoot -ClaudeDataRoot $ClaudeDataRoot -BindAll:$BindAll

$bindHost = if ($BindAll) { '0.0.0.0' } else { '127.0.0.1' }
$displayHost = if ($BindAll) { $bindHost } else { '127.0.0.1' }
$url = "http://${displayHost}:$Port/"

Write-Host ''
Write-Host "MAD UI listening on $url" -ForegroundColor Green
Write-Host "MAD root: $MadRoot"
Write-Host "Channel data: $ClaudeDataRoot"
Write-Host ''
Write-Host 'Press Ctrl+C to stop.' -ForegroundColor Yellow

if (-not $NoBrowser) {
    try {
        if ($IsWindows) {
            Start-Process $url | Out-Null
        } elseif ($IsMacOS) {
            & open $url
        } else {
            # Linux / other POSIX
            & xdg-open $url 2>$null
        }
    } catch {
        Write-Warning "Couldn't auto-open browser: $($_.Exception.Message)"
        Write-Host "Open $url manually."
    }
}

try {
    while ($handle.Listener.IsListening) {
        Start-Sleep -Seconds 1
    }
} finally {
    Stop-MadUIServer -Handle $handle
    Write-Host 'MAD UI stopped.' -ForegroundColor Yellow
}
