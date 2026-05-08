# Fixture: basic input for /mad-c4 (synthetic)

Synthetic input for the mad-c4 skill. The skill emits C4-model architecture diagrams (Context / Container / Component) for a feature spec.

## Synthetic input artifact

Source: `specs/3-feature-foo/spec.md` + `plan.md`
Expected diagrams:
- Context (system + external actors)
- Container (services within the system)
- Component (decomposition of the primary container)

## Skill invocation

```
/mad-c4
```

## Notes

This fixture exercises the smart-default flow (parse spec → emit Mermaid C4 → validate). For mode-specific fixtures (--level <c1|c2|c3>, --copilot), add additional fixtures.
