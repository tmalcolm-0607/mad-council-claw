# Fixture: basic input for /council-list (synthetic)

Synthetic input for the council-list skill. The skill lists every channel the current session is a member of, with summary.

## Synthetic input artifact

Session-bound aliases:
- `Architect` → channel `service-redesign` (3 unread)
- `Architect` → channel `auth-rework` (0 unread)
- `Skeptic` → channel `auth-rework` (1 unread)

## Skill invocation

```
/council-list
```

## Notes

This fixture exercises the smart-default flow (enumerate session-bound channels → render summary). For mode-specific fixtures (--all, --json), add additional fixtures.
