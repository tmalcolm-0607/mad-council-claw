# Fixture: basic input for /cosmos-provisioning (synthetic)

Synthetic input for the cosmos-provisioning skill. The skill scaffolds Cosmos DB infrastructure (account, database, containers with partition keys, indexing policies) from a high-level spec.

## Synthetic input artifact

```yaml
account: cosmos-myapp-{env}-westus3
database: app
containers:
  - name: events
    partitionKey: /tenantId
    ttl: 2592000   # 30 days
  - name: snapshots
    partitionKey: /aggregateId
```

## Skill invocation

```
/cosmos-provisioning
```

## Notes

This fixture exercises the smart-default flow (parse spec → emit bicep → preflight schema). For mode-specific fixtures (--validate-only, --dry-run), add additional fixtures.
