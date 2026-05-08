# Template — devcontainer patch

Canonical shape for `/devcontainer` output. Proposed devcontainer.json patches with rationale.

> **EXAMPLE — replace this when authoring**

```markdown
# Devcontainer Patch — <ISO date>

**Target**: `.devcontainer/devcontainer.json`
**Project state**: <runtime versions, services required>

## Current vs proposed

| Field | Current | Proposed | Why |
|-------|---------|----------|-----|
| .NET version | 9.0 | 10.0 | Project upgraded 2026-04 |
| Cosmos emulator service | absent | added (linux/azure-cosmos-emulator:vnext-preview) | IntegrationTests require |
| Bicep CLI feature | absent | ms-azuretools/bicep-feature | Infra changes need lint |
| Forwarded ports | 5000 | 5000, 8081 (Cosmos) | new service exposed |

## Proposed devcontainer.json

```json
{
  "name": "...",
  "image": "...",
  "features": { ... },
  "forwardPorts": [...]
}
```

## Anti-hallucination

- Every proposed change cites: source-of-truth (`.csproj`, infra spec, README)
- Never claim a feature is "needed" without naming the consumer
```

## Reference

- `rules/quality-gates.md` — runtime + infra dependencies that constrain devcontainer scope
