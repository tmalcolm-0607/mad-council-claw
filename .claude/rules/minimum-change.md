# Minimum Change

**Applies to:** every skill that modifies code, specs, or configuration. Especially: `/council-post --type task`, and any implementation skill downstream of a task.

**Source:** lifted from `plugins/server-migration/skills/develop/SKILL.md` §Coder Rules + `plugins/zen-agents/agents/programmer.md` Capabilities. Reinforced by `CLAUDE.md` project-level "Don't add features, refactor, or introduce abstractions beyond what the task requires."

## Core principle

**The smallest change that fulfills the task. Nothing more.**

Three similar lines is better than a premature abstraction. A bug fix doesn't need surrounding cleanup. A one-shot operation doesn't need a helper. Don't design for hypothetical future requirements.

## The rule

Match your change to the scope of the task. If the task is "fix the bug on line 42," the change is "fix line 42," not "refactor the surrounding function because I noticed it could be cleaner."

Concretely:

- Don't add error handling for scenarios that can't happen. Trust internal code and framework guarantees.
- Don't add validation at internal boundaries. Validate at system boundaries (user input, external APIs).
- Don't add abstractions before you have three callers.
- Don't rename variables "while you're in there."
- Don't reorganize imports "to clean up."
- Don't add comments explaining what the code does (identifiers already do that). Only add a comment when WHY is non-obvious.
- Don't add feature flags or backwards-compat shims when you can just change the code.
- Don't add tests for scenarios the task doesn't require.

## Why it matters

Every additional line is additional risk:
- Additional surface area for bugs.
- Additional surface area for prompt-injection (if the change touches LLM-consumed content).
- Additional review load on the Council.
- Additional cognitive load on future readers.
- Additional chance of accidental breakage to unrelated functionality.

Scope creep is the most common way "small" changes become large review cycles.

## Concrete anti-patterns (from marketplace)

| Anti-pattern | Why it's wrong | Correct behavior |
|---|---|---|
| Edit files outside the task scope | Ask before modifying unrelated files | Ask the user; or create a follow-up thread |
| Over-engineered fix (new files for a 3-line fix) | Inflates diff without changing outcome | Modify in place; defer new files to an explicit refactor |
| Renaming _vars when removing code | Inflates diff; changes public surface if var was public | Leave variables as-is when removing their callers |
| Re-exporting types "for backwards compat" | Creates phantom API surface | Let consumers break and update them |
| Adding `// removed for X` comments | Commit message already captures that | Delete cleanly |

## Exceptions (when larger change is correct)

There are legitimate cases where a small task justifies a larger change. The exceptions are explicit, not inferred:

1. **Security fix.** If fixing the bug exposes adjacent code that has the same bug class, fix them together (document in the Council review). This is not scope creep; it's containment.
2. **Invariant violation.** If changing line 42 requires a helper function that doesn't exist, write the minimal helper. But write the helper with the smallest signature that solves this case; don't anticipate future use.
3. **Atomic rollback.** If the change must be deployable or revertable as a unit (e.g., schema + code + migration), include all three. Don't fragment.
4. **Explicit request.** If the user asks for a refactor, the task IS the refactor — the rule doesn't apply.

## How to apply this in practice

When you're about to modify a file:

1. Read ±50 lines of context (per `verification-protocol.md` Rule 2).
2. Write the smallest diff that fulfills the task.
3. Before saving, ask: "Could I have done this in fewer lines / fewer files?" If yes, do that.
4. Before committing, ask: "Does this change touch anything not named in the task?" If yes, either remove the touch or document why it was necessary.

When you're about to write new code:

1. Does it solve a problem stated in the task? If no, don't write it.
2. Will it be called by at least one caller in the same task? If no, defer.
3. Is it the simplest shape that works? Prefer flat over nested, obvious over clever.

## Interaction with other rules

- **`verification-protocol.md` Rule 3 (MATCH EXISTING STYLE)** — minimum change + matching style means: you don't get to introduce new patterns for minor changes. Match what's there.
- **`dangerous-operations-policy.md`** — larger scope changes trigger more consent gates. Staying minimum-scope reduces user-interaction friction.
- **Council review** — a Skeptic finding that flags "this change does more than it needs to" is a valid minimum-change violation. Remediate by scoping down, not by defending.

## Testing this rule

Before posting a task-completion status, ask yourself:

- If I remove any line from this diff, does the task still pass its acceptance criteria? If yes, remove that line.
- Is there anything in this diff that would be flagged by `--dry-run` as out-of-scope? If yes, move it to a follow-up task.

If either answer reveals drift, shrink the diff before posting.

## References

- `plugins/server-migration/skills/develop/SKILL.md` §Coder Rules — "MINIMUM CHANGE" verbatim.
- `plugins/zen-agents/agents/programmer.md` — programmer agent's scope-discipline.
- `CLAUDE.md` project-level instructions — "Don't add features, refactor, or introduce abstractions beyond what the task requires."
- `CHECKLIST.md` marketplace review pattern #100 — "MINIMUM CHANGE coder rule."
- `wiki/patterns/scope-discipline.md` (future) — related pattern on scoping changes.
