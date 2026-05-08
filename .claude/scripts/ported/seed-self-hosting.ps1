#Requires -Version 7
# One-shot script to open mad-self-hosting + seed threads + author verdicts.
# Phase-1b Day 4 deliverable. Safe to re-run — wipes prior state first.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$env:MAD_CRONCREATE_OK = 'true'
$MAD   = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
$root  = Join-Path $env:USERPROFILE 'claude-data'
$alias = 'tonym'
$sess  = "sess-$alias-20260418"
$channelName = 'mad-self-hosting'
$channelDir  = Join-Path $root 'channels' $channelName

# Clean slate
if (Test-Path -LiteralPath $channelDir) {
    Write-Host "Wiping prior $channelDir"
    Remove-Item -LiteralPath $channelDir -Recurse -Force
}

# 1. Open channel with triage-gate
Write-Host "`n=== Opening $channelName ==="
$r = & (Join-Path $MAD 'skills/council-open/council-open.ps1') `
    -Name $channelName `
    -Purpose 'Dogfood MAD.Council to track its own Phase-1b, Phase-1c, and Phase-2 work. Real persistence; real audit trail.' `
    -Tier local -Alias $alias -SessionId $sess `
    -Triage `
    -AcceptanceCriteria 'Phase-1b Days 1-4 shipped (scripts real + plugin fat-bundled + 5 hand-authored verdicts). Channel itself becomes the record of that work.' `
    -EffortEstimate 100
Write-Host "[open] status=$($r.status) tier=$($r.tier) owner=$($r.owner) run_id=$($r.run_id)"
if ($r.status -ne 'OK') { throw "open failed: $($r.error_code) — $($r.message)" }

# 2. Post 5 triage-context threads (channel is in triage; only triage-* types allowed)
$threads = @(
    @{ id = 'phase-1b-day1'; body = 'Day 1 polish: check-mad-links.ps1 real + 6 Pester tests; validate-schemas.ps1 real + 8 tests; 3 frontmatter fixes on MAD/skills/workflow/; 3 Phase-2 Council-script stubs (yagni-filter, pattern-verify, verdict-compute). Sandbox warns 4 -> 1.' }
    @{ id = 'phase-1b-day2'; body = 'Day 2: backup-channels.ps1 pwsh-native Copy-Item (iter-39 audit dropped robocopy/rsync dependency). 8 Pester tests covering happy path + tmp-exclusion + sessions-json exclusion + archive toggle + DryRun + missing-source + auto-create-dest.' }
    @{ id = 'phase-1b-day3'; body = 'Day 3: plugins/mad-council/ fat-plugin. Dockerfile? No. plugin.json, README, bootstrap/sync-from-mad.ps1, Parse-SlashArgs.ps1 + 8 Pester tests, 6 slash commands. sync-from-mad copied skills/council-* + scripts/* + schemas/ + rules/ into the plugin tree. Plugin-local Pester: 170/170 green.' }
    @{ id = 'phase-1b-day4'; body = 'Day 4: this channel + operations/dogfood-manual-grading.md + 5 seed verdicts. Closes Phase-1b acceptance criteria. Verdicts validated via scripts/validate-schemas.ps1 against schemas/verdict.schema.json.' }
    @{ id = 'phase-1c-ui';   body = 'Follow-on milestone (plan only, not executed): local HTTP server + 5 HTML views (channels / detail / thread / metrics / help). Depends on plugin packaging shipped in Day 3. Plan at plans/phase-1c-local-ui.md. 30-hour estimate.' }
)
$postedIds = @{}
foreach ($t in $threads) {
    Write-Host "`n=== Posting thread: $($t.id) ==="
    $p = & (Join-Path $MAD 'skills/council-post/council-post.ps1') `
        -Channel $channelName -Alias $alias -SessionId $sess `
        -Type 'triage-context' -Body $t.body -NewThread $t.id
    if ($p.status -ne 'OK') { throw "post $($t.id) failed: $($p.error_code) — $($p.message)" }
    Write-Host "[post] thread_id=$($p.thread_id) seq=$($p.seq) run_id=$($p.run_id)"
    $postedIds[$t.id] = @{ thread_id = $p.thread_id; run_id = $p.run_id }
}

# 3. Author 5 hand-authored verdicts per operations/dogfood-manual-grading.md
Write-Host "`n=== Authoring verdicts ==="
$verdicts = @(
    @{
        thread = 'phase-1b-day1'; verdict = 'ACCEPT'
        rationale = 'Day 1 shipped cleanly: 4 sandbox warns reduced to 1; Pester total 140 -> 154; scripts check-mad-links + validate-schemas both green with 6 + 8 tests. One LOW finding logged and resolved in-iter (StrictMode vs <name>-in-test-description). No blocking issues.'
        findings = @(
            @{ role = 'skeptic';   severity = 'OBSERVATION'; summary = 'Pester 5 + StrictMode treats <name> in test description as $name variable lookup — flaky unless renamed.';  evidence = 'MAD/scripts/check-mad-links.Tests.ps1:58' }
            @{ role = 'architect'; severity = 'LOW';         summary = 'check-mad-links regex includes ui/ from day 1 for Phase-1c forward-compat; avoids a later bump.';           evidence = 'MAD/scripts/check-mad-links.ps1:62' }
        )
        roleConfidences = @{ advocate = 0.9; skeptic = 0.8; architect = 0.85 }
    }
    @{
        thread = 'phase-1b-day2'; verdict = 'ACCEPT'
        rationale = 'Day 2 backup-channels.ps1 real + 8/8 Pester. iter-39 audit correction applied: pwsh-native Copy-Item -Exclude dropped robocopy/rsync branching. Cross-platform; no external tooling dependency. Exclusion logic verified for tmp files and .sessions.json.'
        findings = @(
            @{ role = 'architect'; severity = 'OBSERVATION'; summary = 'Copy-Item path is O(N) per file; fine for a personal laptop but not a shared-volume scale.'; evidence = 'MAD/scripts/backup-channels.ps1:128' }
        )
        roleConfidences = @{ advocate = 0.9; skeptic = 0.85; architect = 0.9 }
    }
    @{
        thread = 'phase-1b-day3'; verdict = 'ACCEPT'
        rationale = 'Day 3 plugin packaging shipped as fat-plugin (per iter-38 CHK-065 correction — canonical is CLAUDE_PLUGIN_ROOT, not thin facade). 6 slash-command .md files + arg parser + sync script. Plugin-local Pester runs clean: 170/170. MAD/skills/workflow/ correctly excluded from plugin scope per CHK-063.'
        findings = @(
            @{ role = 'skeptic';   severity = 'MEDIUM';      summary = 'Slash-command .md files have not been end-to-end tested via an actual /council-open invocation in a fresh Claude Code session. Syntactic validity of Bash heredoc + $ARGUMENTS interpolation is assumed, not proven.'; evidence = 'plugins/mad-council/commands/council-open.md:22' }
            @{ role = 'architect'; severity = 'LOW';         summary = 'sync-from-mad copies run-sandbox-tests.ps1 into the plugin tree; it is not a skill script and could be filtered out to keep the plugin tighter.';                                          evidence = 'plugins/mad-council/bootstrap/sync-from-mad.ps1:75' }
        )
        roleConfidences = @{ advocate = 0.85; skeptic = 0.7; architect = 0.8 }
    }
    @{
        thread = 'phase-1b-day4'; verdict = 'ACCEPT'
        rationale = 'Day 4 shipped the manual-grading doc + this channel + these verdicts. Acceptance criterion (>=5 verdicts) met. Closes Phase-1b. User question "is this actually helpful?" raised; answer honest: proves correctness, not utility — real-world pilot needed before Phase 2.'
        findings = @(
            @{ role = 'skeptic';   severity = 'MEDIUM';      summary = 'Verdicts authored solo on own work — bias risk. Should seek external review on 1-2 before extending pattern.';                                                                                evidence = 'MAD/operations/dogfood-manual-grading.md:40' }
            @{ role = 'architect'; severity = 'OBSERVATION'; summary = 'Dogfood-on-self is circular validation. Value of the tool needs a non-MAD task to measure against.';                                                                                           evidence = 'MAD/operations/dogfood-manual-grading.md:5' }
        )
        roleConfidences = @{ advocate = 0.75; skeptic = 0.8; architect = 0.7 }
    }
    @{
        thread = 'phase-1c-ui'; verdict = 'INVESTIGATE'
        rationale = 'Phase-1c UI plan written (plans/phase-1c-local-ui.md, 30h estimate) but deliberately not executed. Ship gating: deferred until the dogfood answers "is MAD actually useful?" — building a UI for an unvalidated tool compounds sunk cost.'
        findings = @(
            @{ role = 'architect'; severity = 'HIGH'; summary = 'Phase 1c effort (~30h) committed before external-validation signal. Risk: UI built for a tool that never sees routine use.'; evidence = 'MAD/plans/phase-1c-local-ui.md:1' }
        )
        roleConfidences = @{ advocate = 0.5; skeptic = 0.6; architect = 0.55 }
    }
)

foreach ($v in $verdicts) {
    $threadInfo = $postedIds[$v.thread]
    $threadDir  = Join-Path $channelDir 'threads' $threadInfo.thread_id
    $verdictPath = Join-Path $threadDir 'verdict.json'

    $rolesRun = @()
    foreach ($role in 'advocate','skeptic','architect') {
        $rolesRun += [ordered]@{
            role       = $role
            confidence = [double]$v.roleConfidences[$role]
            model      = 'self-review'
            timed_out  = $false
        }
    }

    $findings = @()
    foreach ($f in $v.findings) {
        $findings += [ordered]@{
            role       = $f.role
            severity   = $f.severity
            summary    = $f.summary
            evidence   = $f.evidence
            confidence = [double]0.8
        }
    }

    $verdictObj = [ordered]@{
        thread_id      = $threadInfo.thread_id
        verdict        = $v.verdict
        issued_utc     = (Get-Date).ToUniversalTime().ToString('o')
        issuer         = [ordered]@{
            alias      = $alias
            session_id = $sess
            mode       = 'manual'
        }
        rationale      = $v.rationale
        roles_run      = $rolesRun
        findings       = $findings
        run_id         = $threadInfo.run_id
        override_count = 0
    }

    # Use the kit's own atomic-write helper so verdicts write through the same pattern as skills
    . (Join-Path $MAD 'scripts' 'atomic-write.ps1')
    Write-AtomicJson -Path $verdictPath -Content $verdictObj
    Write-Host "[verdict] $($v.thread) -> $($v.verdict)"
}

# 4. Validate every verdict against the schema
Write-Host "`n=== Validating verdicts against schemas/verdict.schema.json ==="
$vr = & (Join-Path $MAD 'scripts/validate-schemas.ps1') -Path $channelDir -MadRoot $MAD
Write-Host "validate-schemas: scanned=$($vr.files_scanned), valid=$($vr.valid), invalid=$($vr.invalid), skipped=$($vr.skipped)"
$verdictResults = @($vr.results | Where-Object { $_.schema -eq 'verdict.schema.json' })
foreach ($r in $verdictResults) {
    Write-Host "  $($r.status): $($r.file)"
    if ($r.status -eq 'invalid') { Write-Host "    reason: $($r.reason)" -ForegroundColor Red }
}

$invalidCount = @($verdictResults | Where-Object status -eq 'invalid').Count
if ($invalidCount -gt 0) {
    throw "Some verdict.json files FAILED schema validation — $invalidCount invalid."
}
Write-Host "`n=== SEED COMPLETE ==="
Write-Host "Channel: $channelDir"
Write-Host "Threads: $((Get-ChildItem (Join-Path $channelDir 'threads') -Directory).Count)"
Write-Host "Verdicts: $((Get-ChildItem $channelDir -Filter 'verdict.json' -Recurse).Count)"
