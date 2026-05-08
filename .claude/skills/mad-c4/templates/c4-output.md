# Template — C4 diagrams output

Canonical shape for `/mad-c4` output. C1 (Context), C2 (Container), C3 (Component) Mermaid blocks.

> **EXAMPLE — replace this when authoring**

```markdown
# C4 Diagrams — <feature-name>

**Source spec**: specs/<N>-<slug>/spec.md
**Date**: <ISO date>

## C1 — Context

```mermaid
C4Context
  title <System name>
  Person(user, "User", "Description")
  System(system, "<System>", "What it does")
  System_Ext(ext, "<External>", "Why we touch it")
  Rel(user, system, "Uses")
  Rel(system, ext, "Calls", "HTTP")
```

## C2 — Container

```mermaid
C4Container
  title <System name>
  Person(user, "User")
  System_Boundary(b, "<System>") {
    Container(api, "API", "ASP.NET Core 10", "Entry point")
    Container(svc, "Service", ".NET 10", "Business logic")
    ContainerDb(db, "Cosmos", "NoSQL", "Persistence")
  }
  Rel(user, api, "HTTPS")
  Rel(api, svc, "in-process")
  Rel(svc, db, "Cosmos SDK")
```

## C3 — Component (primary container)

```mermaid
C4Component
  title <Container> components
  Container_Boundary(c, "<container>") {
    Component(handler, "FooHandler", "MVC controller")
    Component(validator, "FooValidator", "FluentValidation")
    Component(repo, "FooRepository", "Cosmos client")
  }
  Rel(handler, validator, "Validates")
  Rel(handler, repo, "Persists")
```

## Anti-hallucination

- Containers/components named in diagrams must appear in spec or plan
- Mermaid syntax validated (closed blocks, valid C4 keywords)
```

## Reference

- `mad-spec/templates/spec.md` — input
- C4 model spec: https://c4model.com
