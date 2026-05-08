# Fixture: basic input for /council-verdict (synthetic)

Synthetic input for the council-verdict skill. The skill issues a verdict on a thread per the severity-to-verdict rubric in `council-review/templates/verdict.md`.

## Synthetic input artifact

Thread: `pivot-rationale`
Findings (collected by /council-review):
- 2 SHOULD-FIX
- 3 PRAISE
Role confidences: advocate=0.86, skeptic=0.82, architect=0.84
0 CRITICAL, 0 HIGH, 0 MEDIUM (per severity-to-verdict rubric)

## Skill invocation

```
/council-verdict pivot-rationale
```

## Notes

This fixture exercises the smart-default flow (load findings → apply rubric → emit verdict.json). For mode-specific fixtures (--ensemble, --type ownership_transfer, --type triage_accept), add additional fixtures.
