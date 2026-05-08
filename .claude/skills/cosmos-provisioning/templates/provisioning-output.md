# Template — Cosmos provisioning output

Canonical shape for `/cosmos-provisioning` output. Bicep + parameter file emission, lint result, deployment instruction (no auto-deploy).

> **EXAMPLE — replace this when authoring**

```markdown
# Cosmos Provisioning — <env>

**Source spec**: <inline yaml or path>
**Target**: `infra/cosmos/<env>.bicep`
**Date**: <ISO date>

## Container plan

| Container | Partition key | TTL | Indexing | Throughput |
|-----------|---------------|-----|----------|------------|
| events | /tenantId | 30d | exclude /largePayload/* | autoscale 4000 RU |
| snapshots | /aggregateId | none | default | autoscale 1000 RU |

## Bicep emission

Wrote: `infra/cosmos/<env>.bicep` (256 lines)

Lint:
```
"C:/Users/tonym/.azure/bin/bicep.exe" lint infra/cosmos/<env>.bicep
→ 0 errors, 0 warnings
```

## Deployment instruction

```bash
powershell.exe -NoProfile -File .mad/scripts/Provision-OtherInfra.ps1 -Environment <env>
```

(Skill does NOT run this automatically — emit + lint only, per ACTUAL BEFORE PRESENT.)

## Anti-hallucination

- Bicep verified by external linter, not just structural checks
- Throughput / partition-key choices cite source spec; no defaults silently substituted

## Verdict

ACCEPT — bicep emitted, lint clean. Operator runs deploy.
```

## Reference

- `rules/deployment-scripts.md` — wrapper-script discipline
