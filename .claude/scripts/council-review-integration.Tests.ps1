#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Integration tests for /council-review orchestration (Steps 6-10) composing
  the three Phase-2 helper scripts.

.DESCRIPTION
  Bypasses skills/council-review/SKILL.md's Steps 1-5 (which require the
  Claude Code Agent tool for sub-agent dispatch — not callable from Pester).

  Takes mock role outputs as input, then exercises:
    Step 6 — YAGNI filter (Skeptic findings only)
    Step 6 — Pattern-verify (all findings, with evidence verification skipped
             since fixtures don't need real files)
    Step 7 — Aggregate: dedupe by file:line+severity, sort by severity
    Step 8 — Compute verdict via verdict-compute.ps1
    Step 9 — Write verdict.json matching schemas/verdict.schema.json
    Step 10 — (no actual /council-post — verify the would-post message shape)

  Each test represents a canonical fixture from
  skills/council-review/tests.md Layer 2 (T2-01, T2-02, etc.) adapted for
  helper composition (not full E2E Claude Code session).
#>

BeforeAll {
    $scriptDir = $PSScriptRoot
    . (Join-Path $scriptDir 'verdict-compute.ps1')
    . (Join-Path $scriptDir 'yagni-filter.ps1')
    . (Join-Path $scriptDir 'pattern-verify.ps1')

    $script:SchemaPath = (Resolve-Path (Join-Path $scriptDir '..' 'schemas' 'verdict.schema.json')).ProviderPath
    $script:SchemaJson = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8

    function script:New-VerdictArtifact {
        param(
            [Parameter(Mandatory)] [pscustomobject] $VerdictRecord,
            [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Findings,
            [Parameter(Mandatory)] [object[]] $Roles,
            [string] $ThreadId = 'test-thread',
            [string] $IssuerAlias = 'tonym',
            [string] $IssuerSession = 'sess-integration-test'
        )
        # Shape the integration-pipeline output into a schema-valid verdict.json
        $schemaFindings = foreach ($f in $Findings) {
            $role = [string]$f.role
            $summary = if ($f.PSObject.Properties['summary'] -and $f.summary) { [string]$f.summary } else { 'finding' }
            $obj = @{
                role     = $role.ToLowerInvariant()
                severity = [string]$f.severity
                summary  = $summary
            }
            if ($f.PSObject.Properties['evidence'] -and $f.evidence) {
                $obj['evidence'] = [string]$f.evidence
            }
            if ($f.PSObject.Properties['confidence']) {
                $obj['confidence'] = [double]$f.confidence
            }
            $obj
        }
        $schemaRoles = foreach ($r in $Roles) {
            @{
                role       = ([string]$r.role).ToLowerInvariant()
                confidence = [double]$r.confidence
                timed_out  = [bool]$r.timed_out
            }
        }

        $artifact = [ordered]@{
            thread_id  = $ThreadId
            verdict    = [string]$VerdictRecord.verdict
            issued_utc = (Get-Date).ToUniversalTime().ToString('o')
            issuer     = @{
                alias      = $IssuerAlias
                session_id = $IssuerSession
                mode       = 'auto'
            }
            rationale  = [string]$VerdictRecord.rationale_seed
            findings   = @($schemaFindings)
            roles_run  = @($schemaRoles)
            run_id     = [guid]::NewGuid().ToString()
        }
        if ($VerdictRecord.escalate_trigger) {
            $artifact['escalate_trigger'] = [string]$VerdictRecord.escalate_trigger
        }
        return $artifact
    }

    function script:Assert-SchemaValid {
        param($Artifact)
        $json = $Artifact | ConvertTo-Json -Depth 10
        try {
            $null = Test-Json -Json $json -Schema $script:SchemaJson -ErrorAction Stop
            return $true
        } catch {
            Write-Host "Schema validation failed:" -ForegroundColor Yellow
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Host "Artifact:" -ForegroundColor DarkYellow
            Write-Host $json -ForegroundColor DarkYellow
            return $false
        }
    }

    function script:Make-Finding {
        param(
            [string] $Role,
            [string] $Severity,
            [string] $Cite = 'file.cs:1',
            [string] $Summary = '',
            [double] $Confidence = 0.9,
            [bool] $IsImprovement = $false,
            [bool] $EvidenceIncomplete = $false,
            [string] $SuggestedSymbol = $null
        )
        $obj = [pscustomobject]@{
            role                = $Role
            severity            = $Severity
            cite                = $Cite
            evidence            = $Cite  # pattern-verify uses this
            summary             = $Summary
            confidence          = $Confidence
            is_improvement      = $IsImprovement
            evidence_incomplete = $EvidenceIncomplete
        }
        if ($SuggestedSymbol) {
            $obj | Add-Member -MemberType NoteProperty -Name 'suggested_symbol' -Value $SuggestedSymbol
        }
        return $obj
    }

    function script:Make-Role {
        param(
            [string] $Name,
            [double] $Confidence = 0.9,
            [bool] $TimedOut = $false
        )
        return [pscustomobject]@{
            role       = $Name
            confidence = $Confidence
            timed_out  = $TimedOut
        }
    }

    # Composed orchestration simulating council-review Steps 6-10.
    # Input: role outputs (findings[], role records). Output: verdict record.
    function script:Invoke-CouncilReviewPipeline {
        param(
            [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $AllFindings,
            [Parameter(Mandatory)] [object[]] $Roles,
            [scriptblock] $YagniScanner = { param($s, $r) 0 },  # default: 0 callers (demote everything)
            [switch] $HasSeverityDisagreement,
            [switch] $EnsembleAllDisagree
        )

        # Step 6a: YAGNI filter (Skeptic findings only)
        $afterYagni = Invoke-YagniFilter -Findings $AllFindings -RepoRoot 'C:/mock' -CallerScanner $YagniScanner

        # Step 6b: Pattern-verify (all findings, skip evidence verification in fixtures)
        $afterPatternVerify = Invoke-PatternVerify -Findings $afterYagni -SkipEvidenceVerification

        # Step 7: Dedupe by (cite + severity), keep highest confidence, merge originating_roles
        $deduped = @{}
        foreach ($f in $afterPatternVerify) {
            $key = "{0}|{1}" -f [string]$f.cite, [string]$f.severity
            if ($deduped.ContainsKey($key)) {
                $existing = $deduped[$key]
                if ([double]$f.confidence -gt [double]$existing.confidence) {
                    $deduped[$key] = $f
                }
                # Roles merge: not tracked in fixtures; would be done here in full impl
            } else {
                $deduped[$key] = $f
            }
        }
        $finalFindings = @($deduped.Values)

        # Sort by severity (CRITICAL > HIGH > MEDIUM > LOW > OBSERVATION), then confidence DESC
        $sevOrder = @{
            CRITICAL    = 0
            HIGH        = 1
            MEDIUM      = 2
            LOW         = 3
            OBSERVATION = 4
        }
        $sorted = $finalFindings | Sort-Object -Property @(
            @{ Expression = { $sevOrder[[string]$_.severity] }; Ascending = $true },
            @{ Expression = { -1 * [double]$_.confidence };    Ascending = $true }
        )

        # Step 8: Compute verdict
        $params = @{
            Findings = @($sorted)
            Roles    = $Roles
        }
        if ($HasSeverityDisagreement) { $params['HasSeverityDisagreement'] = $true }
        if ($EnsembleAllDisagree)     { $params['EnsembleAllDisagree']     = $true }
        $verdict = Invoke-VerdictCompute @params

        # Step 9: Build verdict.json candidate (not actually written in tests)
        return [pscustomobject]@{
            verdict_record = $verdict
            findings       = @($sorted)
            # Would-be resolve message body:
            resolve_body   = "Council verdict: $($verdict.verdict). Summary: $($verdict.rationale_seed)"
        }
    }
}

Describe 'council-review integration :: happy paths' {
    It 'T2-01 clean: no findings, all roles high-confidence → ACCEPT' {
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.95),
            (Make-Role -Name 'skeptic'   -Confidence 0.95),
            (Make-Role -Name 'architect' -Confidence 0.95)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings @() -Roles $roles
        $result.verdict_record.verdict | Should -Be 'ACCEPT'
        $result.findings.Count | Should -Be 0
        $result.resolve_body | Should -Match 'ACCEPT'
    }

    It 'T2-01 variant: 1 CRITICAL + clean roles → FIX' {
        $findings = @(
            (Make-Finding -Role 'architect' -Severity 'CRITICAL' -Cite 'x.cs:10' -Summary 'Race condition')
        )
        $roles = @(
            (Make-Role -Name 'advocate'),
            (Make-Role -Name 'skeptic'),
            (Make-Role -Name 'architect')
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'FIX'
        $result.findings[0].severity | Should -Be 'CRITICAL'
    }

    It '3 HIGH findings across roles → FIX' {
        $findings = @(
            (Make-Finding -Role 'advocate'  -Severity 'HIGH' -Cite 'a.cs:1'),
            (Make-Finding -Role 'skeptic'   -Severity 'HIGH' -Cite 'b.cs:1'),
            (Make-Finding -Role 'architect' -Severity 'HIGH' -Cite 'c.cs:1')
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'FIX'
    }
}

Describe 'council-review integration :: YAGNI filter effect' {
    It 'Skeptic "add unusedSymbol" with 0 callers demoted — aggregation sees LOW, not original HIGH → ACCEPT' {
        $findings = @(
            (Make-Finding -Role 'skeptic' -Severity 'HIGH' -Cite 'api.cs:5' -SuggestedSymbol 'unusedSymbol' -Summary 'add unusedSymbol()')
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $scanner = { param($s, $r) 0 }  # unusedSymbol has 0 callers
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles -YagniScanner $scanner
        # Finding was HIGH; YAGNI demotes to LOW; 0 CRITICAL/HIGH → ACCEPT (high conf)
        $result.verdict_record.verdict | Should -Be 'ACCEPT'
        $result.findings[0].severity | Should -Be 'LOW'
        $result.findings[0].demotion.filter | Should -Be 'YAGNI'
    }

    It 'Skeptic "add realSymbol" with 2 callers → retained HIGH, contributes to 3-HIGH FIX' {
        $findings = @(
            (Make-Finding -Role 'skeptic' -Severity 'HIGH' -Cite 'a:1' -SuggestedSymbol 'realSymbol'),
            (Make-Finding -Role 'architect' -Severity 'HIGH' -Cite 'b:1'),
            (Make-Finding -Role 'advocate'  -Severity 'HIGH' -Cite 'c:1')
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $scanner = { param($s, $r) if ($s -eq 'realSymbol') { 2 } else { 0 } }
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles -YagniScanner $scanner
        $result.verdict_record.verdict | Should -Be 'FIX'  # 3 HIGH retained
    }
}

Describe 'council-review integration :: pattern-verify effect' {
    It 'finding flagged is_improvement → demoted to OBSERVATION, does not trigger FIX' {
        $findings = @(
            (Make-Finding -Role 'architect' -Severity 'HIGH' -Cite 'x:1' -IsImprovement $true),
            (Make-Finding -Role 'architect' -Severity 'HIGH' -Cite 'y:1' -IsImprovement $true),
            (Make-Finding -Role 'architect' -Severity 'HIGH' -Cite 'z:1' -IsImprovement $true)
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        # All 3 demoted to OBSERVATION; no HIGH count; no CRITICAL; ACCEPT
        $result.verdict_record.verdict | Should -Be 'ACCEPT'
        $result.findings | ForEach-Object { $_.severity | Should -Be 'OBSERVATION' }
        $result.findings | ForEach-Object { $_.pattern_improvement_note | Should -Not -BeNullOrEmpty }
    }
}

Describe 'council-review integration :: ESCALATE paths' {
    It 'all roles <0.5 confidence with no findings → ESCALATE (all_low_confidence)' {
        $findings = @()
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.3),
            (Make-Role -Name 'skeptic'   -Confidence 0.4),
            (Make-Role -Name 'architect' -Confidence 0.2)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'ESCALATE'
        $result.verdict_record.escalate_trigger | Should -Be 'all_low_confidence'
    }

    It 'severity disagreement signal + MEDIUM finding → ESCALATE' {
        $findings = @((Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Cite 'x:1'))
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles -HasSeverityDisagreement
        $result.verdict_record.verdict | Should -Be 'ESCALATE'
        $result.verdict_record.escalate_trigger | Should -Be 'severity_disagreement'
    }

    It 'role timeout + remaining borderline → ESCALATE (timeout_with_borderline)' {
        $findings = @((Make-Finding -Role 'advocate' -Severity 'MEDIUM' -Cite 'x:1'))
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.7),
            (Make-Role -Name 'skeptic'   -TimedOut $true -Confidence 0),
            (Make-Role -Name 'architect' -Confidence 0.95)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'ESCALATE'
        $result.verdict_record.escalate_trigger | Should -Be 'timeout_with_borderline'
    }
}

Describe 'council-review integration :: priority precedence (T1-15)' {
    It 'CRITICAL + severity disagreement + all-low-confidence → FIX wins' {
        $findings = @((Make-Finding -Role 'architect' -Severity 'CRITICAL' -Cite 'x:1'))
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.3),
            (Make-Role -Name 'skeptic'   -Confidence 0.3),
            (Make-Role -Name 'architect' -Confidence 0.3)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles -HasSeverityDisagreement
        $result.verdict_record.verdict | Should -Be 'FIX'  # FIX takes precedence over ESCALATE
    }
}

Describe 'council-review integration :: INVESTIGATE path' {
    It 'MEDIUM finding with evidence_incomplete → INVESTIGATE' {
        $findings = @((Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Cite 'x:1' -EvidenceIncomplete $true))
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'INVESTIGATE'
    }
}

Describe 'council-review integration :: dedupe + sort' {
    It 'two findings same file:line + same severity → deduplicated to one' {
        $findings = @(
            (Make-Finding -Role 'advocate'  -Severity 'HIGH' -Cite 'same.cs:42' -Confidence 0.8),
            (Make-Finding -Role 'skeptic'   -Severity 'HIGH' -Cite 'same.cs:42' -Confidence 0.9)
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        # Deduplicated to 1 HIGH finding. 1 HIGH < 3 HIGH threshold → ACCEPT.
        $result.findings.Count | Should -Be 1
        # Highest confidence wins:
        $result.findings[0].confidence | Should -Be 0.9
        $result.verdict_record.verdict | Should -Be 'ACCEPT'
    }

    It 'findings sorted by severity DESC' {
        $findings = @(
            (Make-Finding -Role 'advocate'  -Severity 'LOW'    -Cite 'a:1'),
            (Make-Finding -Role 'skeptic'   -Severity 'HIGH'   -Cite 'b:1'),
            (Make-Finding -Role 'architect' -Severity 'MEDIUM' -Cite 'c:1'),
            (Make-Finding -Role 'advocate'  -Severity 'CRITICAL' -Cite 'd:1')
        )
        $roles = @((Make-Role -Name 'advocate'), (Make-Role -Name 'skeptic'), (Make-Role -Name 'architect'))
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $severities = @($result.findings | ForEach-Object { [string]$_.severity })
        $severities[0] | Should -Be 'CRITICAL'
        $severities[1] | Should -Be 'HIGH'
        $severities[2] | Should -Be 'MEDIUM'
        $severities[3] | Should -Be 'LOW'
    }
}

Describe 'council-review integration :: schema validation (verdict.json)' {
    It 'FIX verdict artifact validates against schemas/verdict.schema.json' {
        $findings = @((Make-Finding -Role 'architect' -Severity 'CRITICAL' -Cite 'x.cs:10'))
        $roles = @(
            (Make-Role -Name 'advocate'),
            (Make-Role -Name 'skeptic'),
            (Make-Role -Name 'architect')
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $artifact = New-VerdictArtifact -VerdictRecord $result.verdict_record -Findings $result.findings -Roles $roles
        (Assert-SchemaValid -Artifact $artifact) | Should -Be $true
    }

    It 'ACCEPT verdict artifact validates' {
        $roles = @(
            (Make-Role -Name 'advocate'),
            (Make-Role -Name 'skeptic'),
            (Make-Role -Name 'architect')
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings @() -Roles $roles
        $artifact = New-VerdictArtifact -VerdictRecord $result.verdict_record -Findings $result.findings -Roles $roles
        (Assert-SchemaValid -Artifact $artifact) | Should -Be $true
    }

    It 'ESCALATE verdict artifact validates (with escalate_trigger when present on record)' {
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.3),
            (Make-Role -Name 'skeptic'   -Confidence 0.3),
            (Make-Role -Name 'architect' -Confidence 0.3)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings @() -Roles $roles
        $artifact = New-VerdictArtifact -VerdictRecord $result.verdict_record -Findings $result.findings -Roles $roles
        (Assert-SchemaValid -Artifact $artifact) | Should -Be $true
    }

    It 'INVESTIGATE verdict artifact validates' {
        $findings = @((Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Cite 'x:1' -EvidenceIncomplete $true))
        $roles = @(
            (Make-Role -Name 'advocate'),
            (Make-Role -Name 'skeptic'),
            (Make-Role -Name 'architect')
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $artifact = New-VerdictArtifact -VerdictRecord $result.verdict_record -Findings $result.findings -Roles $roles
        (Assert-SchemaValid -Artifact $artifact) | Should -Be $true
    }

    It 'Artifact with all severity levels in findings validates' {
        $findings = @(
            (Make-Finding -Role 'advocate'  -Severity 'CRITICAL'    -Cite 'a:1'),
            (Make-Finding -Role 'skeptic'   -Severity 'HIGH'        -Cite 'b:1'),
            (Make-Finding -Role 'architect' -Severity 'MEDIUM'      -Cite 'c:1'),
            (Make-Finding -Role 'advocate'  -Severity 'LOW'         -Cite 'd:1'),
            (Make-Finding -Role 'skeptic'   -Severity 'OBSERVATION' -Cite 'e:1')
        )
        $roles = @(
            (Make-Role -Name 'advocate'),
            (Make-Role -Name 'skeptic'),
            (Make-Role -Name 'architect')
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $artifact = New-VerdictArtifact -VerdictRecord $result.verdict_record -Findings $result.findings -Roles $roles
        (Assert-SchemaValid -Artifact $artifact) | Should -Be $true
    }
}

Describe 'council-review integration :: ACCEPT with caveats' {
    It '2 HIGH findings + one role borderline → ACCEPT with caveats' {
        $findings = @(
            (Make-Finding -Role 'advocate'  -Severity 'HIGH' -Cite 'a:1'),
            (Make-Finding -Role 'skeptic'   -Severity 'HIGH' -Cite 'b:1')
        )
        $roles = @(
            (Make-Role -Name 'advocate'  -Confidence 0.95),
            (Make-Role -Name 'skeptic'   -Confidence 0.65),  # borderline
            (Make-Role -Name 'architect' -Confidence 0.95)
        )
        $result = Invoke-CouncilReviewPipeline -AllFindings $findings -Roles $roles
        $result.verdict_record.verdict | Should -Be 'ACCEPT'
        $result.verdict_record.caveats | Should -Be $true
    }
}
