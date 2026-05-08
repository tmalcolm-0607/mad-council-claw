# Fixture: basic input for /refresh-references (synthetic)

Synthetic input for the refresh-references skill. The skill scans `references/` for cloned reference repos and refreshes them to head with summary diffs.

## Synthetic input artifact

```
references/
  some-reference-repo/    # last fetch: 2026-04-15
  another-ref/            # last fetch: 2026-04-20
```

## Skill invocation

```
/refresh-references
```

## Notes

This fixture exercises the smart-default flow (auto-discover, parallel fetch, summarize diff). For mode-specific fixtures (--dry-run, --since <date>, --council), add additional fixtures alongside this one.
