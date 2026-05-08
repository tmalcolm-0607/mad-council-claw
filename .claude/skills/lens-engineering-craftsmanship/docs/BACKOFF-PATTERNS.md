# Backoff and Throttle Patterns

Pattern reference for any LENS skill that calls a rate-limited or flaky external service (WorkIQ, ADO REST, Geneva, Graph). Captured from real failure modes observed across multiple loops of WorkIQ-driven work.

## Core principles

1. **Persist before each call.** Write the input under processing to disk so a kill mid-loop leaves usable state.
2. **Persist after each successful call.** Write the response artifact and update a manifest so the next run can resume.
3. **Detect throttle signals across all the shapes a service emits.** A single service may surface throttle as: HTTP 429, "transport dropped mid-call", "session expired", "is not connected", "An unexpected error occurred", a timeout exception, or simply silence.
4. **Adapt the delay, do not retry-immediately.** A failed throttled request should add a wait, not just be re-fired.
5. **Cap the backoff.** Never wait longer than the natural reset window of the service (typically 60 minutes for hourly limits).
6. **Decay on success.** A successful call should reduce the next-call delay toward the initial value.

## Default schedule

| State | Delay before next call |
|---|---|
| Initial | 0 seconds |
| After first throttle signal | 600 seconds (10 minutes) |
| After second consecutive throttle | 1800 seconds (30 minutes) |
| After third or more consecutive throttle | 3600 seconds (60 minutes), capped |
| After successful call | Halve current delay toward initial |

The schedule is conservative. Services with finer-grained throttle headers (e.g. 429 with `Retry-After`) should override these defaults using the header value.

## Throttle signals to detect (WorkIQ-specific)

Observed throttle/error responses from `mcp__workiq__ask_work_iq`:

- `MCP server "workiq" transport dropped mid-call; response for tool "ask_work_iq" was lost`
- `MCP server "workiq" session expired`
- `MCP server "workiq" is not connected`
- Response payload `{ "response": null, "error": "An unexpected error occurred while processing your request.", "conversationId": "<id>" }`
- Long-running call that returns `"I've invoked the Deep Work agent for you"` (deferred async; not a true response)

All of these should be treated as `THROTTLED` by the operation wrapper.

## Throttle signals to detect (ADO REST)

- HTTP 429 with `Retry-After` header (use header value)
- HTTP 503 Service Unavailable
- `TF400898: An Internal Error Occurred` on otherwise valid requests
- Timeout exceeding 30 seconds on a normally-fast endpoint

## Manifest format

`manifest.json` per output directory:

```json
{
  "created": "2026-04-30T18:00:00Z",
  "entries": {
    "input-key-1": {
      "status": "completed",
      "last_seen": "2026-04-30T18:01:30Z",
      "last_result": "OK",
      "artifact_path": "responses/input-key-1.json"
    },
    "input-key-2": {
      "status": "throttled",
      "last_seen": "2026-04-30T18:02:00Z",
      "last_result": "THROTTLED",
      "consecutive_throttles": 2
    }
  }
}
```

Status values:
- `completed` - artifact exists and is valid
- `throttled` - skipped this run; will retry on resume
- `error` - operation returned an explicit error (non-throttle)
- `unknown` - operation returned an unexpected shape; needs investigation

## Resume semantics

Re-running a loop on the same `manifest.json` should:

1. Skip every input whose status is `completed`.
2. Re-attempt every input whose status is `throttled` or `error` (with the throttle delay schedule reset to initial).
3. Treat `unknown` as `error` for retry purposes but flag it in the summary report.

## Background-process orchestration

For long batches the orchestrator (Claude Code) should:

1. Kick off the loop script with `Bash` `run_in_background: true`.
2. Stream results to `.mad/scratch/loop-output-<timestamp>.log`.
3. Continue with foreground work while the loop runs.
4. Periodically check the manifest (or read the latest log) to see progress.
5. Never block the foreground session waiting for batch completion.

The Claude Code constraint "do NOT use `run_in_background: true` for Task tool agent spawns" applies to **agents**, not to Bash CLI processes. Bash background mode is the right pattern for long-running scripts.

## Worked example: WorkIQ batch with 12 queries and adaptive backoff

```powershell
# 1. Inputs file: 12 query IDs, one per line
"q01..q12" | ForEach-Object { ... } | Out-File queries.txt

# 2. Define the operation
$workiqOp = {
    param($queryId, $outDir)
    # Read the query text from a queries.json built upstream
    $queryText = ... lookup ...
    # Call MCP via the orchestrator's tooling
    $resp = Invoke-WorkIQ -Query $queryText
    if ($resp.error -or $resp.response -eq $null) {
        return "THROTTLED"
    }
    $resp | ConvertTo-Json | Set-Content (Join-Path $outDir "$queryId.json")
    return "OK"
}

# 3. Run with backoff
.\scripts\loop-with-backoff.ps1 `
    -InputFile queries.txt `
    -OutputDir .mad/voice-profiles/<user>/responses `
    -Operation $workiqOp `
    -InitialDelaySeconds 0 `
    -ThrottleDelaySeconds 600 `
    -MaxDelaySeconds 3600
```

Expected runtime depending on throttle frequency:
- Best case (no throttling): 12 queries x ~5 seconds = ~1 minute total
- Mid case (some throttling): 12 queries with 2 throttle events = ~25 minutes total
- Worst case (heavy throttling): 12 queries with consecutive throttles = up to 90 minutes
- All cases: progress survives session restart via `manifest.json`

## When the wrapper itself can't call MCP

PowerShell scripts can't invoke Claude Code MCP tools directly. The pattern:

1. Script writes a `queries.json` describing what to fetch.
2. Orchestrator (Claude Code) reads the queries, calls MCP per query (one at a time), saves each response to disk in the agreed location.
3. Orchestrator uses this script (`loop-with-backoff.ps1`) only for the **wait scheduling** between calls when throttle is detected.
4. After all responses are captured, script switches to ANALYZE mode and processes the artifacts.

This split keeps the script side language-agnostic and the MCP side under the orchestrator's control.

## Anti-patterns

- **Tight retry loops without delay.** Hammering a throttled service makes the throttle window longer.
- **In-memory state without persistence.** If the loop crashes, all progress is lost.
- **Unbounded retries.** The cap is the natural reset window of the service, not infinity.
- **Single-state retry counter.** Track per-input state, not just a global "this batch is throttled" flag - some inputs may complete, others not.
- **Treating "transport dropped" as a network error.** It is the most common shape of WorkIQ throttle. Treat as `THROTTLED`, not as a hard failure.
- **Single-window queries for multi-month coverage.** A single "last 30 days" query collapses to a Deep Work agent and drops. Decompose to one-week windows and iterate.

## Week-by-week harvest pattern (WorkIQ-specific)

For multi-month per-person research (peer feedback prep, voice profiling, longitudinal pattern observation):

1. **Decompose to one-week windows.** Cover the full period of interest week by week, oldest to newest. Single multi-month queries trigger Deep Work and unreliably drop.
2. **One peer + one week + one narrow topic per query.** Plain wording: "Did X and Y meet or message during week of <date> - <date>? Quote one moment." beats long topic lists.
3. **Persist immediately.** Save each successful response to `<peer>-<YYYY-MM-DD>-to-<YYYY-MM-DD>.md` with the verbatim quote, attendees, meeting names. Partial runs must survive session restart.
4. **Synthesize after harvest, not during.** Do not write the peer's feedback until the full window of weeks is collected. Synthesizing too early means the early weeks dominate the narrative.
5. **Coverage target.** ~17 weeks for a Jan-Apr cycle. ~22-26 weeks for a full half-year.

## Test-probe revive pattern

When WorkIQ returns `transport dropped mid-call` or `session expired`, send a one-word `test` query before retrying the real one:

- The test probe restarts the underlying session/transport.
- If the test returns a successful response, the next real query is much likelier to land.
- If the test fails too, wait the throttle delay and try again.

This is cheap and saves throttle budget compared to retrying the real (longer) query.

## Related

- `scripts/loop-with-backoff.ps1` - the canonical implementation of this pattern in this plugin.
- `scripts/learn-voice-from-workiq.ps1` - uses the loop for the LEARN phase.
- `.claude/rules/degradation-fallback-policy.md` - the broader degradation-vs-halt policy this pattern operationalizes.
