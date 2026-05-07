# Context Guardian

Layered defense against surprise compaction. Thresholds are heuristic (~15% error margin).

## Context Rescaling (Hidden Buffer)

Claude Code reserves ~16.5% of the 200K context window for internal overhead, so effective capacity is ~167K tokens. Thresholds apply to effective capacity, not raw capacity. Example: 142K tokens = 71% raw but 85% effective (HALT level). Configuration: `CONTEXT_GUARDIAN_HIDDEN_BUFFER` (default `0.165`).

## Thresholds

### ADVISORY (~50%)
- Be conservative with agent spawning
- Keep agent prompts concise
- No workflow changes needed

### PREPARE (~70%)
1. Complete current task
2. Run gates + commit completed work
3. THEN check context budget
4. No new agents or research pipelines
5. Consider generating handoff

### HALT (~85%)
1. Shutdown active teammates via `shutdown_request`
2. Exit plan mode if active
3. Generate handoff to `.claude/work-items/{WI-ID}/` with: resume point, key decisions, what failed, blockers, progress, reference files, files modified
4. Write PENDING_HANDOFF pointer
5. Tell user to run `/resume-handoff` in new session
6. **STOP**

## Checkpoint Ordering

At PREPARE during phase transitions: complete task -> gates -> commit -> THEN assess budget.

## Post-Compaction Verification

After any compaction event, verify before continuing:
1. Check that pending tool results resolved (no "orphan" tool_use blocks)
2. Re-read last committed plan checkpoint (tool_result blocks may have been stripped)
3. If thinking/extended reasoning was active: restart — thinking blocks are rejected post-compaction (#10199)
4. Re-confirm active teammates are still reachable (send a test message)
5. If state appears corrupt: `/rewind` to pre-compaction state

## Auto-Memory (MEMORY.md)

- Only the first 200 lines of MEMORY.md are auto-loaded at session start
- Topic files (e.g., debugging.md) are NOT auto-loaded; use Read tool when needed
- Keep MEMORY.md under 180 lines of actual content (leave buffer for additions)
- Use topic files for detailed notes; reference them from MEMORY.md by filename
- Update MEMORY.md at session end when stable patterns emerge

## Configuration

Set in `.claude/settings.local.json` under `env`:
- `CONTEXT_GUARDIAN_ADVISORY_THRESHOLD` (default `0.50`)
- `CONTEXT_GUARDIAN_PREPARE_THRESHOLD` (default `0.70`)
- `CONTEXT_GUARDIAN_HALT_THRESHOLD` (default `0.85`)
- `CONTEXT_GUARDIAN_HIDDEN_BUFFER` (default `0.165` - accounts for Claude Code's internal buffer)
- `STOP_GUARD_ENABLED` (default `true` - warns on session exit with unchecked plan items)

Set any threshold to `1.0` to disable it.
