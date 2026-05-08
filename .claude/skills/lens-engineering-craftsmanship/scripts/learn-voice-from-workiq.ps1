<#
.SYNOPSIS
    Generates a voice profile by analyzing a user's WorkIQ-sourced communication.

.DESCRIPTION
    Phase 1 of the lens-engineering-craftsmanship workflow. Drives a series of
    WorkIQ queries through Claude Code's MCP tooling, collects the responses as
    artifacts, then analyzes them to produce a per-user style-reference.md
    profile.

    The analysis runs in two parts:
      1. SAMPLE: emit a queries.json file enumerating WorkIQ queries to run.
         (Claude Code's session executes them via mcp__workiq__ask_work_iq,
         using scripts/loop-with-backoff.ps1 to handle throttling.)
      2. ANALYZE: read the captured responses, derive sentence-pattern,
         vocabulary, anti-pattern, and formatting-habit observations, and write
         the profile.

    The script does NOT call MCP tools directly (PowerShell cannot invoke MCP).
    It writes a queries.json that the orchestrator (Claude Code) processes.

.PARAMETER User
    User alias to learn. Required.

.PARAMETER Mode
    "sample" (default): emit queries.json describing WorkIQ probes to run.
    "analyze": consume captured responses and emit style-reference.md.

.PARAMETER Days
    Default 60. Days of recent communication to sample.

.PARAMETER OutputDir
    Default .mad/voice-profiles/<User>. Where artifacts and the profile land.

.PARAMETER ResponsesDir
    Used in analyze mode. Directory holding captured WorkIQ JSON responses
    (one per query, named after the query id from queries.json).

.EXAMPLE
    # Step 1: emit query plan
    .\learn-voice-from-workiq.ps1 -User tonym -Mode sample -Days 60

    # Step 2: orchestrator (Claude Code) executes queries via MCP, saving
    #   each response to .mad/voice-profiles/tonym/responses/<query-id>.json,
    #   using scripts/loop-with-backoff.ps1 for throttle handling.

    # Step 3: derive the profile
    .\learn-voice-from-workiq.ps1 -User tonym -Mode analyze
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$User,

    [ValidateSet("sample", "analyze")]
    [string]$Mode = "sample",

    [int]$Days = 60,

    [string]$OutputDir,

    [string]$ResponsesDir
)

$ErrorActionPreference = "Stop"

if (-not $OutputDir) { $OutputDir = ".mad/voice-profiles/$User" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
if (-not $ResponsesDir) { $ResponsesDir = Join-Path $OutputDir "responses" }
if (-not (Test-Path $ResponsesDir)) { New-Item -ItemType Directory -Path $ResponsesDir -Force | Out-Null }

# --- SAMPLE mode: emit queries.json ---
if ($Mode -eq "sample") {
    $queries = @(
        @{
            id    = "tone-overview"
            scope = "tone"
            text  = @"
Look at recent Teams messages, emails, and chat replies sent BY $User over the
last $Days days. Do not look at formal Connect or design docs. Just informal
communication: Teams chats, replies, status updates, email responses. Describe
the user's communication style: typical sentence length, common phrases,
vocabulary patterns, tone, how they greet/close, how terse vs verbose, how they
ask questions vs make statements, any quirks or signature words. Quote 5 to 8
short verbatim examples that capture the voice.
"@
        },
        @{
            id    = "vocabulary"
            scope = "vocabulary"
            text  = @"
Look at recent Teams messages, emails, and chat replies sent BY $User over the
last $Days days. List 15 to 25 vocabulary words or short phrases the user uses
characteristically (especially: technical terms specific to their domain,
preferred spellings/typos, recurring shorthand, signature openers/closers).
Skip generic vocabulary. Quote each in a verbatim sample sentence.
"@
        },
        @{
            id    = "sentence-patterns"
            scope = "sentence-patterns"
            text  = @"
Look at recent Teams replies and email responses by $User over the last $Days
days. Identify 8 to 12 recurring SENTENCE PATTERNS (templates, not individual
sentences) the user reuses. For each, give the pattern (with placeholders) and
2 verbatim examples.
"@
        },
        @{
            id    = "anti-patterns"
            scope = "anti-patterns"
            text  = @"
Look at recent Teams messages, emails, PR comments, and design-doc replies by
$User over the last $Days days. Identify words, phrases, or stylistic patterns
the user noticeably AVOIDS. Especially: corp-speak (leveraged, synergy,
stakeholder ecosystem), em-dashes, AI-generated tells (overly polished
phrasing, parallel-structured bullets, vague qualifiers like "the kind of work
that"). Quote 3 to 5 examples of how they would write the same idea WITHOUT
the avoided pattern.
"@
        },
        @{
            id    = "formatting-habits"
            scope = "formatting"
            text  = @"
Look at messages, emails, and PR comments by $User. Describe formatting habits:
do they use bullets often? how long are typical paragraphs? do they use bold
or italics? code blocks? section headers? How are lists structured? Quote 3
verbatim examples that show the habits.
"@
        },
        @{
            id    = "greeting-and-closing"
            scope = "greeting-closing"
            text  = @"
How does $User typically open and close emails or longer Teams threads? List
3 to 5 distinct opener patterns and 3 to 5 closer patterns, with a verbatim
example each.
"@
        }
    )

    $manifest = @{
        user        = $User
        days        = $Days
        generated   = (Get-Date -Format "o")
        mode        = "sample"
        queries     = $queries
        responses_dir = $ResponsesDir
        next_step   = "Orchestrator (Claude Code) should iterate the queries through scripts/loop-with-backoff.ps1, calling mcp__workiq__ask_work_iq per query. Each response saved as <query-id>.json in responses_dir. After all responses captured, re-run this script with -Mode analyze."
    }

    $queriesPath = Join-Path $OutputDir "queries.json"
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $queriesPath -Encoding UTF8
    Write-Host ""
    Write-Host "=== Voice-learning queries emitted ===" -ForegroundColor Cyan
    Write-Host ("User:           {0}" -f $User)
    Write-Host ("Days:           {0}" -f $Days)
    Write-Host ("Output dir:     {0}" -f $OutputDir)
    Write-Host ("Queries file:   {0}" -f $queriesPath)
    Write-Host ("Query count:    {0}" -f $queries.Count)
    Write-Host ""
    Write-Host "Next step (orchestrator action):" -ForegroundColor Yellow
    Write-Host "  1. Read $queriesPath"
    Write-Host "  2. For each query: call mcp__workiq__ask_work_iq with the query text"
    Write-Host "  3. Save each response to $ResponsesDir/<query-id>.json"
    Write-Host "  4. Use scripts/loop-with-backoff.ps1 to handle throttle (10/30/60 min schedule)"
    Write-Host "  5. Re-run this script: -Mode analyze"
    Write-Host ""
    exit 0
}

# --- ANALYZE mode: derive profile ---
if ($Mode -eq "analyze") {
    $responseFiles = Get-ChildItem -Path $ResponsesDir -Filter "*.json" -ErrorAction SilentlyContinue
    if (-not $responseFiles) {
        Write-Error "No response files found in $ResponsesDir. Did orchestrator run the queries?"
        exit 2
    }

    $observations = @{}
    foreach ($file in $responseFiles) {
        $id = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $observations[$id] = $content
        } catch {
            Write-Warning "Could not parse $($file.Name): $($_.Exception.Message)"
        }
    }

    # The actual rule extraction from observations is delegated to the
    # orchestrator (Claude Code's session can synthesize a structured profile
    # from prose responses better than a regex pass can). This script writes a
    # SCAFFOLD profile and includes the raw observations so the orchestrator
    # can fill it in.
    $scaffoldPath = Join-Path $OutputDir "style-reference.md"
    $rawPath = Join-Path $OutputDir "raw-observations.md"

    # Raw dump for orchestrator
    $rawSb = [System.Text.StringBuilder]::new()
    [void]$rawSb.AppendLine("# Raw WorkIQ observations for $User")
    [void]$rawSb.AppendLine("Generated: $(Get-Date -Format 'o')")
    [void]$rawSb.AppendLine("Days sampled: $Days")
    [void]$rawSb.AppendLine("")
    foreach ($id in $observations.Keys) {
        [void]$rawSb.AppendLine("## $id")
        [void]$rawSb.AppendLine("")
        [void]$rawSb.AppendLine($observations[$id])
        [void]$rawSb.AppendLine("")
        [void]$rawSb.AppendLine("---")
        [void]$rawSb.AppendLine("")
    }
    $rawSb.ToString() | Set-Content -Path $rawPath -Encoding UTF8

    # Scaffold profile (orchestrator fills in YAML rules from raw)
    $scaffoldSb = [System.Text.StringBuilder]::new()
    [void]$scaffoldSb.AppendLine("---")
    [void]$scaffoldSb.AppendLine("user: $User")
    [void]$scaffoldSb.AppendLine("generated_utc: $(Get-Date -Format 'o')")
    [void]$scaffoldSb.AppendLine("days_sampled: $Days")
    [void]$scaffoldSb.AppendLine("sources:")
    [void]$scaffoldSb.AppendLine("  - workiq:teams:${Days}d")
    [void]$scaffoldSb.AppendLine("  - workiq:email:${Days}d")
    [void]$scaffoldSb.AppendLine("sample_count: $($responseFiles.Count)")
    [void]$scaffoldSb.AppendLine("banned_phrases:")
    [void]$scaffoldSb.AppendLine("  # Orchestrator: extract from anti-patterns observation")
    [void]$scaffoldSb.AppendLine("banned_patterns:")
    [void]$scaffoldSb.AppendLine("  # Orchestrator: extract regex-shaped patterns from anti-patterns observation")
    [void]$scaffoldSb.AppendLine("required_patterns: []")
    [void]$scaffoldSb.AppendLine("character_limits:")
    [void]$scaffoldSb.AppendLine("  # Per-artifact-type limits if known. e.g.")
    [void]$scaffoldSb.AppendLine("  #   connect.results: 6000")
    [void]$scaffoldSb.AppendLine("  #   connect.setbacks: 1000")
    [void]$scaffoldSb.AppendLine("  #   connect.how: 1000")
    [void]$scaffoldSb.AppendLine("---")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("# Voice profile: $User")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("Generated $(Get-Date -Format 'yyyy-MM-dd') from $($responseFiles.Count) WorkIQ samples covering the last $Days days.")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("**This file is a scaffold.** The orchestrator should populate the YAML")
    [void]$scaffoldSb.AppendLine("frontmatter and the prose sections below from raw-observations.md, then mark")
    [void]$scaffoldSb.AppendLine("the profile as ready by removing this notice.")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Tone")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::tone-overview)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Sentence patterns")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::sentence-patterns)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Vocabulary")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::vocabulary)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Formatting habits")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::formatting-habits)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Banned phrases (anti-patterns)")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::anti-patterns)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Greeting and closing patterns")
    [void]$scaffoldSb.AppendLine("(populate from raw-observations.md::greeting-and-closing)")
    [void]$scaffoldSb.AppendLine("")
    [void]$scaffoldSb.AppendLine("## Source observations")
    [void]$scaffoldSb.AppendLine("Full WorkIQ responses captured in raw-observations.md")
    $scaffoldSb.ToString() | Set-Content -Path $scaffoldPath -Encoding UTF8

    Write-Host ""
    Write-Host "=== Voice profile scaffold generated ===" -ForegroundColor Cyan
    Write-Host ("User:                 {0}" -f $User)
    Write-Host ("Profile (scaffold):   {0}" -f $scaffoldPath)
    Write-Host ("Raw observations:     {0}" -f $rawPath)
    Write-Host ("Sample count:         {0}" -f $responseFiles.Count)
    Write-Host ""
    Write-Host "Next step (orchestrator action):" -ForegroundColor Yellow
    Write-Host "  Read $rawPath and populate the YAML frontmatter and prose sections in $scaffoldPath."
    Write-Host "  When complete, remove the 'This file is a scaffold' notice."
    Write-Host ""
    exit 0
}
