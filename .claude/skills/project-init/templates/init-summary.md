# Template — project-init summary

Canonical shape for `/project-init` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Project Init — <ISO date>

**Source kit**: <path-to-MAD-Clean-or-tag>
**Target**: <path-to-consumer-project>

## Files copied

| Area | Source | Target | Skip-reason (if any) |
|------|--------|--------|----------------------|
| .claude/ | MAD-Clean/.claude/ | <target>/.claude/ | (LOCAL settings excluded) |
| .mad/ | MAD-Clean/.mad/ | <target>/.mad/ | (scratch/work-items excluded) |

## Files NOT overwritten (consent gate)

| File | Existed already? | Action |
|------|------------------|--------|
| <target>/CLAUDE.md | yes | left alone — user will customize |
| <target>/.gitignore | yes | left alone — user will merge |

## Post-install actions for the user

1. Customize `CLAUDE.md` with project-specific rules
2. Run `cd .mad && ./scripts/Verify-Health.ps1` to confirm kit health
3. Review `.claude/settings.json` and add any project-specific hooks/permissions

## Anti-hallucination

- Each row cites: actual file copy result (success or skip with reason)
- Never claim init succeeded without verifying file presence post-copy
- Dangerous-operations consent gate before overwriting any pre-existing file

## Verdict

ACCEPT — kit installed; user customizes CLAUDE.md.
```
