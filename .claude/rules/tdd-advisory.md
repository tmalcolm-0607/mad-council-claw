# TDD Advisory

Non-blocking reminder to follow Test-Driven Development workflow when modifying source files.

---

## Purpose

The TDD Advisory hook encourages developers to write or update tests before modifying source code. It is **always advisory, never blocking**. Every invocation exits 0 regardless of whether an advisory is emitted.

### When Advisories Are Shown

An advisory appears when ALL of these conditions are true:

1. A source file (`.cs` or `.ts`, but not `.tsx`) is being written or edited
2. No test file has been modified within the last 10 tool uses OR 5 minutes
3. The same source file has not already received an advisory this session
4. The `TDD_ADVISORY_ENABLED` flag is not set to `false` or `0`

---

## Exclusion Patterns

These file types and paths are excluded from advisories (exit 0 immediately):

| Pattern | Rationale |
|---------|-----------|
| `*.md`, `*.json`, `*.yml`, `*.yaml` | Documentation and configuration, not source code |
| `*.tsx` | Design/UI files; tests handled differently per project conventions |
| `*.css`, `*.scss`, `*.sass` | Styling files, not business logic |
| `**/tests/**`, `**/test/**` | Already test files |
| `**/*.test.*`, `**/*.spec.*` | Already test files |
| `**/docs/**` | Documentation directory |
| `**/.claude/**` | Internal tooling |
| `**/migrations/**` | Database migrations follow a different workflow |
| `**/node_modules/**` | Third-party dependencies |

---

## Recent Test Definition

A test modification is considered "recent" if EITHER condition is true:

- **Tool count**: The test was modified within the last 10 `Write|Edit` tool invocations
- **Time**: The test was modified within the last 5 minutes

The hook tracks both metrics in its session state file and checks whichever is more favorable.

---

## Feature Flag

| Variable | Default | Description |
|----------|---------|-------------|
| `TDD_ADVISORY_ENABLED` | `true` (enabled) | Set to `false` or `0` to disable |

### Configuration via settings.local.json

```json
{
  "env": {
    "TDD_ADVISORY_ENABLED": "false"
  }
}
```

---

## Cooldown Behavior

- **One advisory per source file per session**: Once a file has received an advisory, it will not trigger again during the same session
- **Session detection**: Uses `session_id` from stdin or `CLAUDE_SESSION_ID` environment variable
- **State persistence**: Tracked in `.mad/scratch/tdd-state.json`
- **Session reset**: A new session ID resets all cooldowns and state

---

## Integration with TDD Workflow

The advisory encourages the Red-Green-Refactor cycle:

1. **Red**: Write or update a test that describes the desired behavior. Run it to confirm it fails.
2. **Green**: Modify the source code to make the test pass.
3. **Refactor**: Clean up both test and source code while keeping tests green.

When this workflow is followed, the test file modification in step 1 satisfies the recency check, and no advisory appears when modifying source files in step 2.

---

## When to Ignore the Advisory

The advisory is intentionally non-blocking. Legitimate reasons to proceed without writing a test first:

| Scenario | Rationale |
|----------|-----------|
| Refactoring with existing coverage | Tests already cover the behavior being changed |
| Prototyping or exploration | TDD is premature during rapid iteration |
| Documentation-first development | Writing inline docs or comments |
| Pure data structures | Simple DTOs, constants, or enums with no behavior |
| Generated code | Auto-generated files that are not hand-tested |
| Bug fix with existing regression test | The failing test already exists |

---

## State File Schema

Located at `.mad/scratch/tdd-state.json`:

```json
{
  "sessionId": "string - unique session identifier",
  "lastTestModification": "ISO 8601 timestamp or null",
  "lastTestToolCount": "number - toolUseCount when last test was modified",
  "toolUseCount": "number - total Write|Edit calls this session",
  "testFilesModified": ["array of normalized test file paths"],
  "sourceFilesWarned": ["array of normalized source files that received advisory"]
}
```

The state file is created automatically in `.mad/scratch/` (ephemeral directory) and is cleaned up by the janitor agent.

---

## Advisory Message

When triggered, the advisory is written to stderr:

```
[TDD Advisory] Modifying source file without recent test changes: MyService.cs

Consider following TDD workflow:
  1. Write/update test first (Red)
  2. Modify source to pass test (Green)
  3. Refactor if needed

Recent test modifications: 0 files within last 10 tool uses

To disable this advisory: TDD_ADVISORY_ENABLED=false
```

---

## Performance

- Target: <50ms per invocation
- Exclusion checks use simple string operations (endsWith, includes)
- State file read/write uses synchronous fs operations
- No external dependencies or glob libraries
- Early exit on exclusions before any state file I/O

---

## Hook Chain Position

This hook is the **last** in the PreToolUse `Write|Edit` chain, after all validation and blocking hooks. This ensures it never interferes with security or scope checks.
