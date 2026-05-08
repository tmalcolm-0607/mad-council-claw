#Requires -Version 7

<#
.SYNOPSIS
  Localhost HTTP server for the MAD UI. Pure pwsh — no external deps beyond
  what pwsh 7 provides.

.DESCRIPTION
  Phase-1c Day 1 deliverable per `plans/phase-1c-local-ui.md`. Binds
  `127.0.0.1:<port>` via `System.Net.HttpListener`. Serves static files from
  `MAD/ui/web/` and exposes read-only JSON APIs that scan `~/claude-data/`.

  Routes:
    GET /                          → index.html
    GET /channel/<name>            → channel.html
    GET /channel/<n>/thread/<id>   → thread.html
    GET /metrics                   → metrics.html
    GET /help[/...]                → help.html
    GET /js/*, /css/*, /vendor/*   → static asset from web/
    GET /api/channels              → list channels the current session sees
    GET /api/channels/<name>       → channel + digest + threads summary
    GET /api/channels/<n>/thread/<id>
                                   → thread + messages
    GET /api/metrics               → derived-from-disk stats
    GET /api/help                  → command catalog + schema + rule index

  Runnable modes:
    - Direct script: `pwsh MAD/ui/server.ps1 -Port 9292` — blocks until Ctrl+C.
    - Dot-source for tests: `. ./server.ps1`, then `Start-MadUIServer` +
      `Stop-MadUIServer`.

.PARAMETER Port
  TCP port to bind on 127.0.0.1. Default: 9292.

.PARAMETER MadRoot
  MAD/ directory. Default: `<script-dir>/..`.

.PARAMETER ClaudeDataRoot
  Override for channel-state root. Default: `$HOME/claude-data`.

.PARAMETER BindAll
  Bind 0.0.0.0 (LAN-reachable). Rejected unless env var MAD_UI_ALLOW_BIND_ALL=yes.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [int] $Port = 9292,
    [Parameter(Mandatory = $false)] [string] $MadRoot = $null,
    [Parameter(Mandatory = $false)] [string] $ClaudeDataRoot = $null,
    [Parameter(Mandatory = $false)] [switch] $BindAll
)

Set-StrictMode -Version Latest

if (-not $MadRoot) {
    $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}

# Dot-source helper scripts so their functions (Get-MadMetrics, Get-HelpCatalog)
# are available to the route dispatcher. Both scripts follow the pattern of
# exposing a reusable function + only running their entrypoint when NOT
# dot-sourced, so this side-effect is safe.
$script:MetricsScript = Join-Path $PSScriptRoot 'derive-metrics.ps1'
$script:HelpScript    = Join-Path $PSScriptRoot 'extract-help-catalog.ps1'
if (Test-Path -LiteralPath $script:MetricsScript) { . $script:MetricsScript }
if (Test-Path -LiteralPath $script:HelpScript)    { . $script:HelpScript }

$script:MimeMap = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
    '.txt'  = 'text/plain; charset=utf-8'
    '.md'   = 'text/plain; charset=utf-8'
}

# -- JSON helpers -----------------------------------------------------------
function script:Write-JsonResponse {
    param(
        [System.Net.HttpListenerContext] $Ctx,
        [object] $Payload,
        [int] $StatusCode = 200
    )
    $Ctx.Response.StatusCode = $StatusCode
    $Ctx.Response.ContentType = 'application/json; charset=utf-8'
    $json = $Payload | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Ctx.Response.ContentLength64 = $bytes.Length
    $Ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Ctx.Response.OutputStream.Close()
}

function script:Write-TextResponse {
    param(
        [System.Net.HttpListenerContext] $Ctx,
        [string] $Text,
        [int] $StatusCode = 200,
        [string] $ContentType = 'text/plain; charset=utf-8'
    )
    $Ctx.Response.StatusCode = $StatusCode
    $Ctx.Response.ContentType = $ContentType
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Ctx.Response.ContentLength64 = $bytes.Length
    $Ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Ctx.Response.OutputStream.Close()
}

function script:Write-StaticFile {
    param(
        [System.Net.HttpListenerContext] $Ctx,
        [string] $FilePath
    )
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        script:Write-TextResponse -Ctx $Ctx -Text '404 Not Found' -StatusCode 404
        return
    }
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $mime = if ($script:MimeMap.ContainsKey($ext)) { $script:MimeMap[$ext] } else { 'application/octet-stream' }
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $Ctx.Response.StatusCode = 200
    $Ctx.Response.ContentType = $mime
    $Ctx.Response.ContentLength64 = $bytes.Length
    $Ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Ctx.Response.OutputStream.Close()
}

# -- Handlers ---------------------------------------------------------------
function script:Get-ChannelsListPayload {
    param([string] $Root)
    $channelsDir = Join-Path $Root 'channels'
    if (-not (Test-Path -LiteralPath $channelsDir)) {
        return @()
    }
    $rows = @()
    foreach ($chDir in (Get-ChildItem -LiteralPath $channelsDir -Directory -ErrorAction SilentlyContinue)) {
        $chJson = Join-Path $chDir.FullName 'channel.json'
        if (-not (Test-Path -LiteralPath $chJson)) { continue }
        try {
            $ch = Get-Content -LiteralPath $chJson -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { continue }

        $digestJson = Join-Path $chDir.FullName 'digest.json'
        $threadCount = 0
        $totalMessages = 0
        if (Test-Path -LiteralPath $digestJson) {
            try {
                $d = Get-Content -LiteralPath $digestJson -Raw -Encoding UTF8 | ConvertFrom-Json
                $threadCount = @($d.threads).Count
                if ($d.PSObject.Properties['total_messages']) { $totalMessages = [int]$d.total_messages }
            } catch { }
        }

        $memberCount = @($ch.members).Count
        $activeMembers = @($ch.members | Where-Object status -eq 'active').Count

        $rows += [pscustomobject]@{
            name             = $ch.name
            purpose          = $ch.purpose
            tier             = if ($ch.PSObject.Properties['environment_tier']) { $ch.environment_tier } else { 'local' }
            status           = if ($ch.PSObject.Properties['status']) { $ch.status } else { 'active' }
            owner_alias      = if ($ch.PSObject.Properties['owner_alias']) { $ch.owner_alias } else { $null }
            created_utc      = $ch.created_utc
            member_count     = $memberCount
            active_members   = $activeMembers
            thread_count     = $threadCount
            total_messages   = $totalMessages
        }
    }
    return $rows
}

function script:Get-ChannelDetailPayload {
    param([string] $Root, [string] $Name)
    $chDir = Join-Path $Root 'channels' $Name
    $chJson = Join-Path $chDir 'channel.json'
    if (-not (Test-Path -LiteralPath $chJson)) { return $null }
    $ch = Get-Content -LiteralPath $chJson -Raw -Encoding UTF8 | ConvertFrom-Json

    $digestJson = Join-Path $chDir 'digest.json'
    $digest = $null
    if (Test-Path -LiteralPath $digestJson) {
        try {
            $digest = Get-Content -LiteralPath $digestJson -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { }
    }

    $threads = @()
    $threadsDir = Join-Path $chDir 'threads'
    if (Test-Path -LiteralPath $threadsDir) {
        foreach ($td in (Get-ChildItem -LiteralPath $threadsDir -Directory -ErrorAction SilentlyContinue)) {
            $tjPath = Join-Path $td.FullName 'thread.json'
            if (Test-Path -LiteralPath $tjPath) {
                try {
                    $tj = Get-Content -LiteralPath $tjPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    $hasVerdict = Test-Path -LiteralPath (Join-Path $td.FullName 'verdict.json')
                    $msgCount = 0
                    $msgDir = Join-Path $td.FullName 'messages'
                    if (Test-Path -LiteralPath $msgDir) {
                        $msgCount = @(Get-ChildItem -LiteralPath $msgDir -Filter '*.json' -File -ErrorAction SilentlyContinue).Count
                    }
                    $threads += [pscustomobject]@{
                        thread_id     = $tj.thread_id
                        status        = if ($tj.PSObject.Properties['status']) { $tj.status } else { 'active' }
                        message_count = $msgCount
                        last_msg_seq  = if ($tj.PSObject.Properties['last_seq']) { $tj.last_seq } elseif ($tj.PSObject.Properties['first_seq']) { $tj.first_seq } else { 0 }
                        last_msg_utc  = if ($tj.PSObject.Properties['last_msg_utc']) { $tj.last_msg_utc } else { $null }
                        has_verdict   = $hasVerdict
                        title         = if ($tj.PSObject.Properties['title']) { $tj.title } else { $null }
                    }
                } catch { }
            }
        }
    }

    return [pscustomobject]@{
        channel = $ch
        digest  = $digest
        threads = @($threads)
    }
}

function script:Get-ThreadPayload {
    param([string] $Root, [string] $Name, [string] $ThreadId)
    $td = Join-Path $Root 'channels' $Name 'threads' $ThreadId
    if (-not (Test-Path -LiteralPath $td)) { return $null }
    $thread = $null
    $tjPath = Join-Path $td 'thread.json'
    if (Test-Path -LiteralPath $tjPath) {
        try { $thread = Get-Content -LiteralPath $tjPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }
    $messages = @()
    $msgDir = Join-Path $td 'messages'
    if (Test-Path -LiteralPath $msgDir) {
        foreach ($mf in (Get-ChildItem -LiteralPath $msgDir -Filter '*.json' -File | Sort-Object Name)) {
            try {
                $m = Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $messages += $m
            } catch { }
        }
    }
    $verdict = $null
    $vPath = Join-Path $td 'verdict.json'
    if (Test-Path -LiteralPath $vPath) {
        try { $verdict = Get-Content -LiteralPath $vPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }
    return [pscustomobject]@{
        thread   = $thread
        messages = @($messages)
        verdict  = $verdict
    }
}

# -- Traversal guard (extracted so Pester can unit-test it) ----------------
function script:Test-TraversalAttempt {
    param([string] $RawUrl, [string] $Path)
    if (-not $RawUrl) { return $false }
    # Literal `..` segment in either raw or normalised path.
    if ($RawUrl -match '(^|[/\\])\.\.($|[/\\])') { return $true }
    if ($Path   -and $Path   -match '(^|[/\\])\.\.($|[/\\])') { return $true }
    # Percent-encoded `.` in any mixed-case combination.
    if ($RawUrl -match '(?i)(%2e){2}') { return $true }
    if ($RawUrl -match '(?i)%2e\.') { return $true }
    if ($RawUrl -match '(?i)\.%2e') { return $true }
    # Double-encoding (%252e → %2e → .).
    if ($RawUrl -match '(?i)(%252e){2}') { return $true }
    return $false
}

# -- Route dispatcher -------------------------------------------------------
function script:Invoke-Route {
    param(
        [System.Net.HttpListenerContext] $Ctx,
        [string] $MadRoot,
        [string] $ClaudeDataRoot
    )
    $url = $Ctx.Request.Url
    $path = $url.AbsolutePath
    $rawUrl = $Ctx.Request.RawUrl

    # Reject directory-traversal attempts — defence-in-depth. HTTP.sys/System.Uri
    # normalise most `..` sequences out before we see them, but this catches
    # anything that slips through.
    if (script:Test-TraversalAttempt -RawUrl $rawUrl -Path $path) {
        script:Write-TextResponse -Ctx $Ctx -Text '400 Bad Request' -StatusCode 400
        return
    }

    # Normalize: strip trailing slash except for root
    if ($path.Length -gt 1 -and $path.EndsWith('/')) {
        $path = $path.TrimEnd('/')
    }

    $webRoot = Join-Path $MadRoot 'ui' 'web'

    # API routes first
    if ($path -eq '/api/channels') {
        script:Write-JsonResponse -Ctx $Ctx -Payload (script:Get-ChannelsListPayload -Root $ClaudeDataRoot)
        return
    }
    if ($path -eq '/api/metrics') {
        if (Get-Command Get-MadMetrics -ErrorAction SilentlyContinue) {
            script:Write-JsonResponse -Ctx $Ctx -Payload (Get-MadMetrics -Root $ClaudeDataRoot)
        } else {
            script:Write-JsonResponse -Ctx $Ctx -Payload @{ error = 'derive-metrics.ps1 not loaded' } -StatusCode 500
        }
        return
    }
    if ($path -eq '/api/help') {
        if (Get-Command Get-HelpCatalog -ErrorAction SilentlyContinue) {
            script:Write-JsonResponse -Ctx $Ctx -Payload (Get-HelpCatalog -MadRoot $MadRoot)
        } else {
            script:Write-JsonResponse -Ctx $Ctx -Payload @{ error = 'extract-help-catalog.ps1 not loaded' } -StatusCode 500
        }
        return
    }
    if ($path -match '^/api/channels/([A-Za-z0-9][A-Za-z0-9-]*)/thread/(.+)$') {
        $name = $Matches[1]
        $tid  = $Matches[2]
        $payload = script:Get-ThreadPayload -Root $ClaudeDataRoot -Name $name -ThreadId $tid
        if (-not $payload) {
            script:Write-JsonResponse -Ctx $Ctx -Payload @{ error = 'thread not found' } -StatusCode 404
            return
        }
        script:Write-JsonResponse -Ctx $Ctx -Payload $payload
        return
    }
    if ($path -match '^/api/channels/([A-Za-z0-9][A-Za-z0-9-]*)$') {
        $name = $Matches[1]
        $payload = script:Get-ChannelDetailPayload -Root $ClaudeDataRoot -Name $name
        if (-not $payload) {
            script:Write-JsonResponse -Ctx $Ctx -Payload @{ error = 'channel not found' } -StatusCode 404
            return
        }
        script:Write-JsonResponse -Ctx $Ctx -Payload $payload
        return
    }

    # HTML routes → serve matching static file
    $staticFile = switch -Regex ($path) {
        '^/$'                                        { Join-Path $webRoot 'index.html' }
        '^/channel/[^/]+/thread/.+$'                 { Join-Path $webRoot 'thread.html' }
        '^/channel/[^/]+$'                           { Join-Path $webRoot 'channel.html' }
        '^/metrics$'                                 { Join-Path $webRoot 'metrics.html' }
        '^/help(/.*)?$'                              { Join-Path $webRoot 'help.html' }
        default { $null }
    }
    if ($staticFile) {
        script:Write-StaticFile -Ctx $Ctx -FilePath $staticFile
        return
    }

    # Static assets: /js/*, /css/*, /vendor/*
    if ($path -match '^/(js|css|vendor)/(.+)$') {
        $assetFile = Join-Path $webRoot $Matches[1] $Matches[2]
        # Safety: reject any `..` in the path (directory traversal)
        if ($Matches[2].Contains('..')) {
            script:Write-TextResponse -Ctx $Ctx -Text '400 Bad Request' -StatusCode 400
            return
        }
        script:Write-StaticFile -Ctx $Ctx -FilePath $assetFile
        return
    }

    script:Write-TextResponse -Ctx $Ctx -Text '404 Not Found' -StatusCode 404
}

# -- Server control ---------------------------------------------------------
function Start-MadUIServer {
    <#
    .SYNOPSIS
      Start the listener + return a handle (Listener + runspace).
    #>
    [CmdletBinding()]
    param(
        [int] $Port = 9292,
        [string] $MadRoot = $null,
        [string] $ClaudeDataRoot = $null,
        [switch] $BindAll
    )

    if (-not $MadRoot) {
        $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
    }
    if (-not $ClaudeDataRoot) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
    }

    $bindHost = if ($BindAll -and $env:MAD_UI_ALLOW_BIND_ALL -eq 'yes') { '+' } else { '127.0.0.1' }
    if ($BindAll -and $env:MAD_UI_ALLOW_BIND_ALL -ne 'yes') {
        throw 'Refusing -BindAll without explicit MAD_UI_ALLOW_BIND_ALL=yes env-var.'
    }

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://${bindHost}:${Port}/")
    $listener.Start()

    # Run in a background runspace so the caller can continue.
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    # Dot-source this script inside the runspace so handler functions are available.
    # Runtime params are named distinctly ($RuntimeMadRoot/$RuntimeDataRoot) so that
    # the dot-sourced script's own param block can't shadow them with its defaults.
    [void]$ps.AddScript({
        param($ListenerRef, $ServerScriptPath, $RuntimeMadRoot, $RuntimeDataRoot)
        . $ServerScriptPath
        while ($ListenerRef.IsListening) {
            try {
                $ctx = $ListenerRef.GetContext()
                try {
                    script:Invoke-Route -Ctx $ctx -MadRoot $RuntimeMadRoot -ClaudeDataRoot $RuntimeDataRoot
                } catch {
                    try {
                        $ctx.Response.StatusCode = 500
                        $msg = "500 " + $_.Exception.Message
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
                        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                        $ctx.Response.OutputStream.Close()
                    } catch { }
                }
            } catch {
                # Listener stopped or error; exit loop
                break
            }
        }
    })
    [void]$ps.AddArgument($listener)
    [void]$ps.AddArgument($PSCommandPath)
    [void]$ps.AddArgument($MadRoot)
    [void]$ps.AddArgument($ClaudeDataRoot)
    $async = $ps.BeginInvoke()

    return [pscustomobject]@{
        Listener   = $listener
        PowerShell = $ps
        Async      = $async
        Runspace   = $runspace
        Port       = $Port
        BindHost   = $bindHost
    }
}

function Stop-MadUIServer {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Handle)
    try { $Handle.Listener.Stop() } catch { }
    try { $Handle.Listener.Close() } catch { }
    try { $Handle.PowerShell.Stop() } catch { }
    try { $Handle.PowerShell.Dispose() } catch { }
    try { $Handle.Runspace.Close() } catch { }
    try { $Handle.Runspace.Dispose() } catch { }
}

# -- Script entrypoint (when NOT dot-sourced) -------------------------------
# Use MyInvocation to detect: if dot-sourced, $MyInvocation.InvocationName is '.'.
if ($MyInvocation.InvocationName -ne '.') {
    $handle = Start-MadUIServer -Port $Port -MadRoot $MadRoot -ClaudeDataRoot $ClaudeDataRoot -BindAll:$BindAll
    Write-Host "MAD UI listening on http://$($handle.BindHost):$($handle.Port)/" -ForegroundColor Green
    Write-Host "MAD root: $MadRoot"
    Write-Host "Channel data: $ClaudeDataRoot"
    Write-Host 'Press Ctrl+C to stop.' -ForegroundColor Yellow
    try {
        while ($handle.Listener.IsListening) {
            Start-Sleep -Seconds 1
        }
    } finally {
        Stop-MadUIServer -Handle $handle
    }
}
