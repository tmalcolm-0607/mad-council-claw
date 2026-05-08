# Fixture: basic input for /mad-adr (synthetic)

Synthetic input for the mad-adr skill. The skill creates (or amends) an Architecture Decision Record per the standard ADR template.

## Synthetic input artifact

Decision: "Adopt EventBridge over Service Bus for inter-service messaging."
Status: Proposed
Context: see `specs/3-feature-foo/research.md`
Consequences: docs to update, migration cost, ops burden

## Skill invocation

```
/mad-adr "Adopt EventBridge for inter-service messaging"
```

## Notes

This fixture exercises the smart-default flow (parse decision → emit ADR). For mode-specific fixtures (--supersede <id>, --status <state>), add additional fixtures.
