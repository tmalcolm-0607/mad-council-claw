# Template — repo-sync plan

Canonical shape for `/repo-sync` output before the user-confirm gate.

> **EXAMPLE — replace this when authoring**

```markdown
# Repo Sync Plan — <ISO date>

**Source**: <path-or-url>
**Target**: <path-or-url>
**Direction**: <one-way | bi-directional (rare)>

## Diff

| File | Status | Source size | Target size | Action |
|------|--------|-------------|-------------|--------|
| .claude/rules/foo.md | NEW (in source) | 4.2 KB | — | copy → target |
| .claude/rules/bar.md | MODIFIED | 5.1 KB | 4.8 KB | overwrite (consent gate) |
| .claude/rules/baz.md | CONFLICT | hash A | hash B + local edits | manual merge required |

## Conflicts

For each: show both sides + recommend resolution path. NEVER auto-resolve.

## Anti-hallucination

- File hashes computed; never inferred from filename
- "Modified" status verified against git history, not just timestamp

## Verdict

ACCEPT_WITH_CAVEATS — plan ready; user must approve before write.
REJECT — conflicts present; resolve manually before re-running.

## Verification Spec

(Required by plan-gate hook; sync plans are operational not feature plans, but conform for gate compliance.)

### Feature Intent

Bring the target tree's tracked files into a known state relative to the source tree, with explicit user consent on overwrites.

### Change Type

infra (file-system synchronization).

### Expected Impact

Target tree files match source on all NEW + MODIFIED rows; CONFLICT rows surfaced for manual resolution. No silent overwrites.

### Structural Signals

The Diff matrix above IS the structural signal. Each row's Action column shows the planned mutation; the user-confirm gate verifies intent before any write.

### Not a Failure

- Files in target but not in source → not synced (one-way is from source); not a failure
- Conflicts left unresolved → REJECT, not silent skip; user remediates manually
- Permission errors on individual files → reported per-file; rest of sync proceeds
```

## Reference

- `rules/dangerous-operations-policy.md` — overwrite is a Category action requiring consent
