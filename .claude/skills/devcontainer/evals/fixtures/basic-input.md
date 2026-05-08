# Fixture: basic input for /devcontainer (synthetic)

Synthetic input for the devcontainer skill. The skill scaffolds or audits a `.devcontainer/devcontainer.json` for parity with the project's runtime requirements (.NET version, Docker, Cosmos emulator, secrets).

## Synthetic input artifact

Project state:
- .NET 10
- Cosmos emulator required for IntegrationTests
- Bicep CLI required for infra changes
- Existing `.devcontainer/devcontainer.json` with .NET 9 + no Cosmos

## Skill invocation

```
/devcontainer
```

## Notes

This fixture exercises the smart-default flow (audit → diff → propose patches). For mode-specific fixtures (--scaffold, --refresh), add additional fixtures.
