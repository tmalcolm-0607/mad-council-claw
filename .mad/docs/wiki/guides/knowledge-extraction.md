# Knowledge Extraction

Automatic detection and capture of valuable findings from long investigation and research sessions.

---

## Extractable Knowledge Criteria

A subagent session qualifies for knowledge extraction when ALL of these conditions are met:

| Criterion | Requirement |
|-----------|-------------|
| **Duration** | >= 10 minutes (configurable via `KNOWLEDGE_EXTRACTION_MIN_DURATION_MS`) |
| **Agent type** | Includes "investigator" or "researcher" (case-insensitive) |
| **Outcome** | Successful completion (not failed or aborted) |
| **Value** | Findings that could be reused in future sessions |

### Agent Types That Qualify

- `code-investigator`
- `research-scout`
- `research-curator`
- `research-reviewer`
- `parallel-researcher`
- Any custom agent type containing "investigator" or "researcher"

### Agent Types That Do NOT Qualify

- `code-implementer` (implementation, not investigation)
- `code-reviewer` (review, not investigation)
- `janitor` (cleanup, not investigation)
- `work-planner` (planning, not investigation)

---

## Threshold Configuration Guide

### Environment Variable: `KNOWLEDGE_EXTRACTION_MIN_DURATION_MS`

| Setting | Value |
|---------|-------|
| Default | `600000` (10 minutes) |
| Minimum | `60000` (1 minute, clamped) |
| Maximum | `3600000` (60 minutes, clamped) |

### How to Configure

Add to `.claude/settings.local.json` under `env`:

```json
{
  "env": {
    "KNOWLEDGE_EXTRACTION_MIN_DURATION_MS": "900000"
  }
}
```

### Recommended Values

| Project Phase | Recommended Threshold | Rationale |
|---------------|----------------------|-----------|
| Early exploration | 300000 (5 min) | Capture more findings during initial discovery |
| Active development | 600000 (10 min) | Default -- balanced noise vs. coverage |
| Mature/stable | 900000 (15 min) | Reduce noise from routine investigations |
| Large monorepo | 1200000 (20 min) | Only deep investigations are knowledge-worthy |

### Tuning Tips

- If you see too many knowledge candidates in `patterns.json`: increase the threshold
- If valuable investigations are not captured: decrease the threshold
- Run `/apply-learnings --stats` to see how many candidates exist

---

## Integration with `/apply-learnings --knowledge`

### End-to-End Workflow

```
Detection (on-subagent-stop.js)
  |
  v
Prompt Creation (.mad/scratch/knowledge-prompts/{timestamp}.json)
  |
  v
Pattern Capture (patterns.json with knowledge_candidate type)
  |
  v
User Review (/apply-learnings --knowledge)
  |
  v
Skill Generation (.claude/skills/{topic}/SKILL.md)
  |
  v
Approval & Storage
```

### Files Involved

| File | Role |
|------|------|
| `.claude/hooks/on-subagent-stop.js` | Detection: creates knowledge prompt JSON |
| `.claude/hooks/capture-learning.js` | Pattern capture: adds knowledge_candidate to patterns.json |
| `.mad/scratch/knowledge-prompts/*.json` | Prompt artifacts: detailed extraction context |
| `.mad/learning/patterns.json` | Pattern storage: knowledge_candidate entries |
| `.claude/skills/apply-learnings/SKILL.md` | Skill definition: `--knowledge` mode documentation |
| `.claude/skills/{topic}/SKILL.md` | Output: generated skill files |

### Reviewing and Approving Knowledge

```bash
# See all pending knowledge candidates
/apply-learnings --knowledge

# See statistics including knowledge candidate count
/apply-learnings --stats
```

---

## Good vs Poor Extraction Examples

### Good Candidates (EXTRACT)

| Duration | Agent Type | Topic | Why Extract |
|----------|-----------|-------|-------------|
| 15 min | code-investigator | Authentication patterns across 3 repos | Reusable cross-repo pattern analysis |
| 20 min | parallel-researcher | Performance optimization techniques | General-purpose optimization knowledge |
| 12 min | research-scout | Testing strategies for event sourcing | Domain-specific testing approach |
| 18 min | code-investigator | Error handling middleware patterns | Reusable architectural pattern |

### Poor Candidates (REJECT)

| Duration | Agent Type | Topic | Why Reject |
|----------|-----------|-------|------------|
| 5 min | code-investigator | Quick file search | Too short, not knowledge-worthy |
| 10 min | code-investigator | Debugging a one-off null reference | Not reusable, specific to one bug |
| 30 min | research-scout | Investigation that found no conclusions | No actionable findings to extract |
| 12 min | code-investigator | Reading a single config file | Trivial investigation, no pattern value |

### Reviewer Guidance

When reviewing knowledge candidates with `/apply-learnings --knowledge`, ask:

1. **Would this help a future developer?** If yes, approve.
2. **Is this specific to one bug or one-time task?** If yes, reject.
3. **Does this document a reusable pattern or approach?** If yes, approve.
4. **Was the investigation inconclusive?** If yes, reject.

---

## Knowledge Candidate Lifecycle

```
PENDING_EXTRACTION
  |-- User runs /apply-learnings --knowledge
  |
  +-- [Approve] --> APPLIED
  |     |-- Skill file created at .claude/skills/{topic}/SKILL.md
  |     |-- Knowledge prompt JSON status updated to "extracted"
  |     |-- Pattern status updated to "applied" in patterns.json
  |
  +-- [Reject] --> REJECTED
  |     |-- Pattern status updated to "rejected" in patterns.json
  |     |-- Will not be proposed again
  |
  +-- [Skip] --> PENDING_EXTRACTION (unchanged)
        |-- Will be proposed again on next /apply-learnings --knowledge run
```

---

## Knowledge Prompt JSON Schema

Files created in `.mad/scratch/knowledge-prompts/`:

```json
{
  "timestamp": "2026-02-16T10:00:00Z",
  "agentType": "code-investigator",
  "durationMs": 720000,
  "durationMinutes": 12,
  "topic": "authentication patterns",
  "suggestedSkillName": "auth-patterns-analysis",
  "status": "pending_extraction",
  "extractionPrompt": "This investigation took 12 minutes and uncovered valuable patterns about authentication. Consider extracting as a reusable skill."
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `pending_extraction` | Awaiting user review via `/apply-learnings --knowledge` |
| `extracted` | Approved and converted to a skill file |
| `rejected` | User rejected; will not be proposed again |

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Setting threshold to 1 minute | Too much noise; every investigation captured | Use >= 5 minutes minimum |
| Approving all candidates without review | Low-quality skills dilute the skill library | Review each candidate for reusability |
| Ignoring knowledge candidates indefinitely | Stale candidates accumulate in patterns.json | Run `/apply-learnings --knowledge` periodically |
| Manual knowledge extraction without hooks | Inconsistent, easy to forget | Let hooks detect automatically |
| Duplicating investigation work across sessions | Wasted time and tokens | Extract as skill after first deep investigation |
