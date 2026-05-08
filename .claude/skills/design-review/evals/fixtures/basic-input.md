# Fixture: basic input for /design-review (synthetic)

Synthetic input for the design-review skill. The skill reviews a design document against the 6 implementability gates.

## Synthetic input artifact

`specs/ideas/feature-foo.md` (vision document):

```markdown
# Feature Foo

## User stories
- As a user I want to do X with Foo

## Functional Requirements
- FR-1: Foo handles requests
- FR-2: Foo is fast
- FR-3: Foo integrates with Bar

## Logical Proof
- TBD
```

## Skill invocation

```
/design-review specs/ideas/feature-foo.md
```

## Notes

This fixture exercises the smart-default flow (read → 6 gates → findings). For mode-specific fixtures (--council, --deep), add additional fixtures.
