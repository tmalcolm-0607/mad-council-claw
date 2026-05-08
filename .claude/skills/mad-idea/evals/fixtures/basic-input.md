# Fixture: basic input for /mad-idea (synthetic)

Synthetic input for the mad-idea skill. The skill takes a brief description and produces a vision document at `specs/ideas/<slug>.md` per MAD idea.md template.

## Synthetic input artifact

User input: "Add an event-replay tool so we can re-emit historical events into a sandbox tenant for debugging."

Expected output sections (per MAD idea.md template):
- Problem statement
- User stories (≥3)
- Functional Requirements (FRs) with Logical Proof placeholders
- Non-functional considerations
- Open questions

## Skill invocation

```
/mad-idea "event-replay tool for sandbox debugging"
```

## Notes

This fixture exercises the smart-default flow (parse → expand → write). For mode-specific fixtures (--brief, --council), add additional fixtures.
