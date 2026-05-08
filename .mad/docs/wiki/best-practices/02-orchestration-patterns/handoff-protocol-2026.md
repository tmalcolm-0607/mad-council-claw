---
category: orchestration-patterns
subcategory: handoff-protocol
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Handoff Protocol (2026)

## Overview

Session handoff patterns for preserving workflow state across context boundaries. Covers handoff generation, resume protocol, and continuity best practices.

**Key capabilities**:
- Checkpoint-then-handoff ordering ensures completed work saved
- 7-section structure captures all critical state
- PENDING_HANDOFF pointer file enables automatic resume
- Teammate shutdown prevents orphaned processes

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Checkpoint First** | Run quality gates + commit before handoff |
| **Rich Context** | Include 7 sections: resume point, progress, blockers, files, decisions, failures, references |
| **PENDING_HANDOFF** | Pointer file signals next session to resume |
| **Never /compact** | Compaction loses state; handoff preserves it |
| **Teammate Shutdown** | Gracefully terminate teams before handoff |

## Patterns (Current)

### Handoff Generation

**When to generate handoff**:
- Context capacity critically low (~85%)
- Long session winding down (>4 hours)
- Major phase transition (spec → plan → implement)
- Before risky operations (large refactor, migration)

**Checkpoint-then-handoff ordering** (CRITICAL):
```
1. Complete current task
2. Run quality gates (build, test, lint)
3. Commit completed work (atomic commit)
4. THEN assess context budget
5. If >= 85%: generate handoff and halt
```

**Handoff generation steps**:
1. **If agent team running**: Send `shutdown_request` to ALL teammates via SendMessage (wait 30s)
2. **If in plan mode**: Exit plan mode first (so Write tool works)
3. **Generate rich handoff**: Use Read/Write tools to create comprehensive document
4. **Write PENDING_HANDOFF pointer**: Signals next session to resume
5. **Tell user**: "Handoff created at {path}. Start new session and run `/resume-handoff`."
6. **STOP**: Do not continue working

### Resume Protocol

**Session start detection**:
- Hook checks for PENDING_HANDOFF file in `.claude/work-items/{WI-ID}/`
- If found, notifies user: "Pending handoff detected. Run `/resume-handoff` to continue."

**Resume workflow**:
1. User runs `/resume-handoff` skill
2. Skill reads handoff document
3. Loads context: resume point, progress, blockers, decisions, failures
4. Primes context with reference files
5. Continues from exact checkpoint

**Limitations** (current):
- `/resume` and `/rewind` do NOT restore in-process teammates
- After resuming, lead may attempt to message non-existent teammates
- **Workaround**: Spawn new teammates after resume

### 7-Section Structure

**Section 1: Resume Point**:
- Current phase (spec, plan, implement, validate)
- Last commit SHA
- Next action (exact task or checkpoint)

**Section 2: Progress Snapshot**:
- Plan.md checkboxes (which are `[x]`, which are `[ ]`)
- Tasks.md summary (completed vs remaining)
- Phase gate status (which gates passed)

**Section 3: Active Blockers**:
- From `[!]` markers in plan.md
- Dependencies waiting on external input
- Infrastructure issues (database down, API unreachable)

**Section 4: Files Modified**:
- `git diff --stat` output
- New files created
- Files deleted

**Section 5: Key Decisions** (max 10):
- Architectural choices (with rationale)
- Trade-offs made (with alternatives considered)
- Patterns adopted (with reference files)

**Section 6: What Was Tried and Failed**:
- Approaches attempted but abandoned
- Why they failed
- Prevents repeating mistakes in next session

**Section 7: Reference Files to Read First**:
- Files to prime context in next session
- Key pattern files relevant to current work
- Spec/plan files for background

### Context Warning Integration

**Context Guardian thresholds** (from `.claude/rules/context-guardian.md`):

| Threshold | Action |
|-----------|--------|
| **ADVISORY (~50%)** | Be conservative with agent spawning, avoid large file reads |
| **PREPARE (~70%)** | Complete current task, run checkpoint, check budget, defer new agents |
| **HALT (~85%)** | Generate handoff immediately and stop working |

**Adjustable thresholds** (set in `.claude/settings.local.json` under `env`):
- `CONTEXT_GUARDIAN_HALT_THRESHOLD` (default: 0.85)
- `CONTEXT_GUARDIAN_PREPARE_THRESHOLD` (default: 0.70)
- `CONTEXT_GUARDIAN_ADVISORY_THRESHOLD` (default: 0.50)

Set to `1.0` to disable a threshold.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Context management | Manual compaction | Context Guardian with automated thresholds | Enable hooks, set thresholds in settings |
| Handoff format | Ad-hoc notes | 7-section structured document | Use handoff generator library |
| Resume detection | Manual check | Automatic (session-start hook) | No migration needed (automatic) |
| Teammate shutdown | Manual | Graceful shutdown_request protocol | Use SendMessage with type: "shutdown_request" |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Using /compact to continue | Loses workflow state, decisions, rationale | Generate handoff and start new session |
| Spawning agents above 80% | Accelerates toward compaction | Finish current work, no new agents |
| Ignoring warnings | Compaction happens without warning | Respect thresholds as directional signals |
| Continuing 5+ turns past 85% | Hook hard-blocks, risks data loss | Stop immediately, generate handoff |
| Handoff without commit first | Uncommitted work may be lost | Always commit before handoff |
| Skipping teammate shutdown | Orphaned teammates waste resources | Send shutdown_request before handoff |

## Examples

### Example 1: Handoff Document Structure

```markdown
# Session Handoff - WI-20260216-1000-oauth2-auth

## 1. Resume Point
- **Phase**: Implementation (Phase 3 of 5)
- **Last commit**: abc123def (feat: add OAuth2 Google provider)
- **Next action**: Run quality gates, then implement token refresh logic (Task T030)

## 2. Progress Snapshot
- Plan.md: 8/12 tasks completed
- Tasks.md: T010-T020 completed, T030-T050 remaining
- Gates: Build ✓, Tests ✓, Coverage ✓, Lint ✓

## 3. Active Blockers
- [!] Waiting on API key from team lead for Google OAuth2
- [!] PostgreSQL migrations pending (need DBA approval)

## 4. Files Modified
- src/auth/oauth2.ts (new, 150 lines)
- src/auth/google-provider.ts (new, 80 lines)
- tests/auth/oauth2.spec.ts (new, 120 lines)
- docs/auth/oauth2-flow.md (updated)

## 5. Key Decisions
1. **OAuth2 library**: Chose `@panva/oauth4webapi` (standard-compliant, lightweight)
2. **Token storage**: Redis (short TTL, automatic expiry)
3. **Error handling**: RFC 7807 Problem Details (consistency with existing APIs)

## 6. What Was Tried and Failed
1. Attempted `passport-google-oauth20` - too heavyweight, requires Express session middleware
2. Tried storing tokens in PostgreSQL - performance issues with frequent refreshes

## 7. Reference Files
- src/auth/oauth2.ts (current implementation)
- docs/05-USER-EXPERIENCE/workflows/authentication-flow.md (requirements)
- .claude/rules/patterns/dotnet-error-handling.md (error patterns)
```

### Example 2: Resume from Handoff

**User action**:
```bash
# New session started
> /resume-handoff
```

**Skill loads handoff and primes context**:
1. Reads handoff from `.claude/work-items/WI-20260216-1000-oauth2-auth/artifacts/session-handoff-*.md`
2. Loads reference files (oauth2.ts, authentication-flow.md)
3. Displays resume point and blockers
4. Continues from Task T030

**Lead continues work**:
- Checks for API key (blocker resolved?)
- If yes: implements token refresh logic
- If no: waits or implements other unblocked tasks

## Troubleshooting

| Issue | Solution |
|-------|----------|
| PENDING_HANDOFF not detected | Check file exists in `.claude/work-items/{WI-ID}/` directory |
| Handoff incomplete (missing sections) | Verify all 7 sections present, regenerate if needed |
| Resume loads wrong work item | Check ACTIVE pointer in `.claude/work-items/` |
| Teammates still running after handoff | Send shutdown_request to all teammates before handoff |
| Context still bloating after handoff | Verify new session (not `/resume` in same session) |

## See Also

- `context-management-2026.md` - Context thresholds
- `.claude/rules/context-guardian.md` - Handoff triggers
- `.mad/lib/handoff-generator.js` - Handoff generator
- `.claude/hooks/session-start.js` - Resume detection

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (official)
- Project internal: `.claude/rules/context-guardian.md`, `.mad/lib/handoff-generator.js`

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + internal implementation)
**Frequency validation**: 90%+ (patterns appear in official docs + internal codebase)
