# Fixture: basic input for /council-resolve (synthetic)

Synthetic input for the council-resolve skill. The skill applies a verdict's resolution to a thread (e.g., FIX → mark blocked-pending-remediation, ACCEPT → close thread, OWNERSHIP_TRANSFER → rewrite owner_alias).

## Synthetic input artifact

Thread: `pivot-rationale`
Verdict on file: ACCEPT (issued by `Architect` after 3-role review)
verdict.json:
- type: ACCEPT
- issuer_alias: Architect
- findings: 1 SHOULD-FIX, 2 PRAISE
- verdict_confidence: 0.84

## Skill invocation

```
/council-resolve service-redesign pivot-rationale
```

## Notes

This fixture exercises the smart-default flow (read verdict → apply state change → atomic write). For mode-specific fixtures (FIX, ESCALATE, OWNERSHIP_TRANSFER), add additional fixtures.
