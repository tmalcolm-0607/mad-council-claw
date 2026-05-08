#Requires -Version 7
# Pester 5.x suite for MAD/ui/server.ps1.
# Starts the listener on a random high port into a temp ClaudeDataRoot, hits it
# via Invoke-WebRequest, then tears it down. Pure pwsh — no external HTTP deps.

BeforeAll {
    $script:ServerScript = Join-Path $PSScriptRoot 'server.ps1'
    if (-not (Test-Path -LiteralPath $script:ServerScript)) {
        throw "server.ps1 not found at $script:ServerScript"
    }
    . $script:ServerScript

    # Build a throwaway channel-data root
    $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mad-ui-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $channelsDir = Join-Path $script:TempRoot 'channels'
    New-Item -ItemType Directory -Path $channelsDir -Force | Out-Null

    # Channel A: two threads, one with a verdict
    $chA = Join-Path $channelsDir 'test-alpha'
    New-Item -ItemType Directory -Path (Join-Path $chA 'threads' 'topic-1' 'messages') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $chA 'threads' 'topic-2' 'messages') -Force | Out-Null
    @{
        name             = 'test-alpha'
        purpose          = 'test channel alpha'
        tier             = 'local'
        environment_tier = 'local'
        status           = 'active'
        owner_alias      = 'alice'
        created_utc      = '2026-04-18T00:00:00.0000000Z'
        members          = @(@{ alias = 'alice'; status = 'active' })
        schema_version   = 2
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chA 'channel.json') -Encoding UTF8
    @{
        channel_seq    = 3
        threads        = @(
            @{ thread_id = 'topic-1'; last_seq = 2 },
            @{ thread_id = 'topic-2'; last_seq = 1 }
        )
        total_messages = 3
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chA 'digest.json') -Encoding UTF8
    @{
        thread_id  = 'topic-1'
        first_seq  = 1
        last_seq   = 2
        title      = 'seed thread'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 'topic-1' 'thread.json') -Encoding UTF8
    @{
        thread_id  = 'topic-2'
        first_seq  = 3
        last_seq   = 3
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 'topic-2' 'thread.json') -Encoding UTF8
    @{
        seq = 1; type = 'question'; body = 'hello world'; alias = 'alice'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 'topic-1' 'messages' '0001.json') -Encoding UTF8
    @{
        thread_id  = 'topic-1'
        verdict    = 'ACCEPT'
        issued_utc = '2026-04-18T00:05:00Z'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 'topic-1' 'verdict.json') -Encoding UTF8

    # Channel B: minimal, no digest
    $chB = Join-Path $channelsDir 'test-beta'
    New-Item -ItemType Directory -Path $chB -Force | Out-Null
    @{
        name             = 'test-beta'
        purpose          = 'test channel beta'
        tier             = 'local'
        environment_tier = 'local'
        status           = 'triage'
        owner_alias      = 'bob'
        created_utc      = '2026-04-18T00:01:00.0000000Z'
        members          = @(@{ alias = 'bob'; status = 'active' })
        schema_version   = 2
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chB 'channel.json') -Encoding UTF8

    # Pick a random high port; retry if bind-conflict
    $script:Port = Get-Random -Minimum 40000 -Maximum 49999
    $attempts = 0
    $script:Handle = $null
    while (-not $script:Handle -and $attempts -lt 5) {
        try {
            $script:Handle = Start-MadUIServer -Port $script:Port -MadRoot (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath -ClaudeDataRoot $script:TempRoot
        } catch {
            $script:Port = Get-Random -Minimum 40000 -Maximum 49999
            $attempts++
        }
    }
    if (-not $script:Handle) { throw "failed to bind a listener after 5 attempts" }

    # Small pause so listener is actually ready
    Start-Sleep -Milliseconds 200

    $script:BaseUrl = "http://127.0.0.1:$($script:Port)"
}

AfterAll {
    if ($script:Handle) {
        try { Stop-MadUIServer -Handle $script:Handle } catch { }
    }
    if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot)) {
        Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'MAD UI server — API endpoints' {

    It '/api/channels returns array with known seeded channels' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/api/channels" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'application/json'
        $data = $r.Content | ConvertFrom-Json
        @($data).Count | Should -BeGreaterOrEqual 2
        @($data | Where-Object name -eq 'test-alpha').Count | Should -Be 1
        @($data | Where-Object name -eq 'test-beta').Count  | Should -Be 1
    }

    It '/api/channels enriches rows with thread_count + total_messages when digest present' {
        $data = (Invoke-WebRequest -Uri "$script:BaseUrl/api/channels" -UseBasicParsing).Content | ConvertFrom-Json
        $alpha = $data | Where-Object name -eq 'test-alpha'
        $alpha.thread_count   | Should -Be 2
        $alpha.total_messages | Should -Be 3
        $alpha.status         | Should -Be 'active'
        $alpha.owner_alias    | Should -Be 'alice'
    }

    It '/api/channels by-name returns channel + digest + threads' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/api/channels/test-alpha" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $d = $r.Content | ConvertFrom-Json
        $d.channel.name | Should -Be 'test-alpha'
        $d.digest.channel_seq | Should -Be 3
        @($d.threads).Count | Should -Be 2
        # Verdict flag should be true for topic-1 and false for topic-2
        $t1 = $d.threads | Where-Object thread_id -eq 'topic-1'
        $t2 = $d.threads | Where-Object thread_id -eq 'topic-2'
        $t1.has_verdict | Should -BeTrue
        $t2.has_verdict | Should -BeFalse
    }

    It '/api/channels missing-name returns 404 JSON' {
        $status = $null
        try {
            Invoke-WebRequest -Uri "$script:BaseUrl/api/channels/does-not-exist" -UseBasicParsing | Out-Null
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
        }
        $status | Should -Be 404
    }

    It '/api/channels thread by-id returns thread + messages + verdict' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/api/channels/test-alpha/thread/topic-1" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $d = $r.Content | ConvertFrom-Json
        $d.thread.thread_id | Should -Be 'topic-1'
        @($d.messages).Count | Should -Be 1
        $d.verdict.verdict | Should -Be 'ACCEPT'
    }

    It '/api/channels thread missing-id returns 404' {
        $status = $null
        try {
            Invoke-WebRequest -Uri "$script:BaseUrl/api/channels/test-alpha/thread/nope" -UseBasicParsing | Out-Null
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
        }
        $status | Should -Be 404
    }
}

Describe 'MAD UI server — HTML routes' {

    It 'GET / serves index.html when present' {
        $webRoot = Join-Path (Split-Path $script:ServerScript -Parent) 'web'
        if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
            Set-ItResult -Skipped -Because 'index.html not yet authored'
            return
        }
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/html'
    }

    It 'GET channel page serves channel.html' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/channel/test-alpha" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/html'
        $r.Content | Should -Match 'MAD\.Council'
    }

    It 'GET thread page serves thread.html' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/channel/test-alpha/thread/topic-1" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/html'
    }

    It 'GET /css/main.css serves static CSS' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/css/main.css" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/css'
    }

    It 'GET /metrics serves metrics.html' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/metrics" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/html'
    }

    It 'GET /help serves help.html' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/help" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'text/html'
    }

    It 'GET /api/metrics returns the derived metrics object' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/api/metrics" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $r.Headers['Content-Type'] | Should -Match 'application/json'
        $d = $r.Content | ConvertFrom-Json
        $d.channels.total  | Should -BeGreaterOrEqual 2
        $d.threads.total   | Should -BeGreaterOrEqual 2
        $d.messages.total  | Should -BeGreaterOrEqual 1
    }

    It 'GET /api/help returns catalog of commands + schemas + rules' {
        $r = Invoke-WebRequest -Uri "$script:BaseUrl/api/help" -UseBasicParsing
        $r.StatusCode | Should -Be 200
        $d = $r.Content | ConvertFrom-Json
        # Commands should exist (we have skills/council-* in the real MAD root)
        @($d.commands).Count | Should -BeGreaterThan 0
        @($d.schemas).Count  | Should -BeGreaterThan 0
        @($d.rules).Count    | Should -BeGreaterThan 0
    }

    It 'GET /unknown returns 404' {
        $status = $null
        try {
            Invoke-WebRequest -Uri "$script:BaseUrl/totally-not-a-page" -UseBasicParsing | Out-Null
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
        }
        $status | Should -Be 404
    }
}

Describe 'MAD UI server — security' {

    It 'Test-TraversalAttempt catches literal and encoded dot-dot patterns' {
        # Unit-test the guard directly — HTTP.sys and Invoke-WebRequest both
        # normalise `..` on the way in, so an integration-level test can't
        # reliably reach the server-side guard. Testing the predicate itself
        # guarantees defence-in-depth remains correct regardless of how the
        # request arrives.
        script:Test-TraversalAttempt -RawUrl '/js/../../etc/passwd' -Path '/js/../../etc/passwd' | Should -BeTrue
        script:Test-TraversalAttempt -RawUrl '/js/%2e%2e/%2e%2e/etc/passwd' -Path '/js/../../etc/passwd' | Should -BeTrue
        script:Test-TraversalAttempt -RawUrl '/js/%2E%2E/evil' -Path '/evil' | Should -BeTrue
        script:Test-TraversalAttempt -RawUrl '/js/%252e%252e/evil' -Path '/evil' | Should -BeTrue
        script:Test-TraversalAttempt -RawUrl '/js/%2e./evil' -Path '/evil' | Should -BeTrue
        # Benign paths — no match.
        script:Test-TraversalAttempt -RawUrl '/js/main.js' -Path '/js/main.js' | Should -BeFalse
        script:Test-TraversalAttempt -RawUrl '/api/channels' -Path '/api/channels' | Should -BeFalse
        script:Test-TraversalAttempt -RawUrl '/channel/foo-bar' -Path '/channel/foo-bar' | Should -BeFalse
        # File with a dot in name (not a dot-dot) — must not match.
        script:Test-TraversalAttempt -RawUrl '/css/main.v2.css' -Path '/css/main.v2.css' | Should -BeFalse
    }

    It 'traversal attempt over HTTP never returns 200 (defence-in-depth)' {
        # Whether the platform normalises `..` on the client or we catch it
        # server-side, the critical property is: the attacker never gets 200 +
        # /etc/passwd. Both outcomes (400 from our guard, 404 after
        # normalisation) are acceptable.
        $status = 200
        try {
            $r = Invoke-WebRequest -Uri "$script:BaseUrl/js/../../etc/passwd" -UseBasicParsing
            $status = $r.StatusCode
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
        }
        $status | Should -Not -Be 200
    }

    It 'Start-MadUIServer -BindAll without env var throws' {
        $orig = $env:MAD_UI_ALLOW_BIND_ALL
        $env:MAD_UI_ALLOW_BIND_ALL = $null
        try {
            { Start-MadUIServer -Port 59999 -BindAll } | Should -Throw '*MAD_UI_ALLOW_BIND_ALL*'
        } finally {
            if ($orig) { $env:MAD_UI_ALLOW_BIND_ALL = $orig }
        }
    }
}

Describe 'MAD UI server — lifecycle' {

    It 'Stop-MadUIServer stops listening' {
        # Spin up a throwaway second instance and stop it
        $port2 = Get-Random -Minimum 50000 -Maximum 59999
        $h2 = Start-MadUIServer -Port $port2 -MadRoot (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath -ClaudeDataRoot $script:TempRoot
        Start-Sleep -Milliseconds 150
        $h2.Listener.IsListening | Should -BeTrue
        Stop-MadUIServer -Handle $h2
        Start-Sleep -Milliseconds 100
        $h2.Listener.IsListening | Should -BeFalse
    }
}
