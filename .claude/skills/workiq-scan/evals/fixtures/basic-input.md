# Fixture: basic input for /workiq-scan (synthetic)

Synthetic input for the workiq-scan skill. The skill queries WorkIQ MCP for context around a topic, person, or work item, with throttle-aware backoff.

## Synthetic input artifact

Query: PR #5157555 in LENS-CMS
Context needed: discussion threads, related work items, author tag

## Skill invocation

```
/workiq-scan "PR 5157555 LENS-CMS context"
```

## Notes

This fixture exercises the smart-default flow (query → backoff on 429 → cache → render).
