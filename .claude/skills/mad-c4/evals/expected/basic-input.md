# Expected output: basic input for /mad-c4

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (spec.md + plan.md exist + parse) passes |
| Step 1 | extract actors, containers, components from spec |
| Step 2 | emit C1 (Context) Mermaid block |
| Step 3 | emit C2 (Container) Mermaid block |
| Step 4 | emit C3 (Component) Mermaid block for primary container |
| Step 5 | write output to `specs/3-feature-foo/c4-diagrams.md` |

## Output Contract

- Each diagram cites: source artifact + extraction method
- Mermaid syntax validated (no unclosed blocks, valid C4 keywords)
- Anti-hallucination: never invent containers/components not named in spec
- Empty extraction stated explicitly

## Verdict

ACCEPT — 3 diagrams emitted; ready for review.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE)
- Standards inheritance ✓
