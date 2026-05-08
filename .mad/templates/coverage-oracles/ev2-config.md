# Coverage Oracle — ev2-config

What a *complete* Ev2 config change (`ScopeBindings.json`, `ServiceSpecification.json`, `RolloutSpec.json`, `ServiceModel.json`, `StageMap*.json`, `Configuration/*.{npe,ppe,prod,test,tonym}.json`, `Parameters/*.parameters.json`) must cover. Loaded for `ev2-config-change`.

This oracle is the structural answer to the failure mode that `prescriptive-content-review.md` Gap 3 was created for: Ev2 deploys silently break when env-config keys diverge from scope-binding placeholders. Until 2026-05, that gap was caught only by cross-model fortune (PR 5160086 review, GPT-5.5 caught a missing NPE config key); this oracle makes the check mechanical.

## Required elements

| # | Element | What it verifies |
|---|---------|------------------|
| 1 | **Scope-binding chain integrity** | Every `__PLACEHOLDER__` token in `Parameters/*.parameters.json` has a matching `find` entry in `ScopeBindings.json` and a corresponding `replaceWith: $config(<key>)` mapping |
| 2 | **Env coverage parity** | Every `$config(<key>)` referenced by a global `ScopeBindings` entry resolves in EVERY environment config (`*.npe.json`, `*.ppe.json`, `*.prod.json`, etc.). Missing key in any env config when the binding is global = BLOCKING |
| 3 | **`$schema` declaration** | `ServiceSpecification.json` and `RolloutSpec.json` declare `$schema` against the canonical Ev2 schema URL (`https://ev2schema.azure.net/schemas/...`) |
| 4 | **ServiceTree integration** | `ServiceSpecification.json` has `providerType: "ServiceTree"` and `identifier` is a valid ServiceTree GUID. `ownerGroupObjectId` SHOULD be omitted (resolved at deploy time from ServiceTree); when present, it must match the registered Ev2 service spec verbatim |
| 5 | **No hardcoded secrets** | No connection strings, account keys, SAS tokens, or PATs in any Ev2 config JSON. Use `@Microsoft.KeyVault(VaultName=...;SecretName=...)` references or post-provisioning role assignments |
| 6 | **Per-ring capacity discipline** | App Service plan / DTS capacity per environment matches the documented LENS pattern (PPE: capacity 1, ZR false; Prod: capacity 2+, ZR true). Deviations require justification in PR description |
| 7 | **No collisions across resource definitions** | Resource names produced by scope-binding substitution are unique per `(environment, region)` tuple. Two definitions producing the same RG name silently overwrite each other |
| 8 | **Rollout step ordering** | `RolloutSpec.json` step `dependsOn` chains are acyclic; resources that consume config (App Service) depend on resources that publish config (Key Vault, Identity) |

## Severity per missing element

| Element | Missing severity |
|---------|------------------|
| 1 Scope-binding chain integrity | **BLOCKING** (deploy fails preflight on unresolved placeholder) |
| 2 **Env coverage parity** | **BLOCKING** for any env in this PR's deploy ring; MUST-FIX otherwise (silent fallback to empty/false at coercion time) |
| 3 `$schema` declaration | SHOULD-FIX |
| 4 ServiceTree integration | **BLOCKING** if `providerType: ServiceTree` is missing or `identifier` is not a valid GUID; MUST-FIX if `ownerGroupObjectId` diverges from registered spec |
| 5 **No hardcoded secrets** | **BLOCKING** + treat as security incident (per `rules/non-negotiable-rules.md`) |
| 6 Per-ring capacity discipline | SHOULD-FIX (capacity drift) |
| 7 No collisions | **BLOCKING** (prod overwrite risk) |
| 8 Rollout step ordering | MUST-FIX |

## Scope-binding chain integrity

The chain has three links and an oracle pass MUST verify all three:

```
Parameters/<resource>.parameters.json
  └── "value": "__GLOBAL_API_ZONE_REDUNDANT__"     ← link 1: placeholder
                          │
                          ▼
ScopeBindings.json
  └── { "find": "__GLOBAL_API_ZONE_REDUNDANT__",   ← link 2: scope binding
        "replaceWith": "$config(globalApi.zoneRedundant)" }
                          │
                          ▼
Configuration/Microsoft.M365.LENS.<Service>.<env>.json
  └── "globalApi": {                                ← link 3: env config
        "zoneRedundant": "false"
      }
```

Mechanical check:

1. Extract all `__PLACEHOLDER__` tokens from `Parameters/*.parameters.json` and `Parameters/*.bicepparam` (where `any('__...__')` is used).
2. For each placeholder, find the matching `find` entry in `ScopeBindings.json`. Missing match = link 1 broken = BLOCKING.
3. For each `$config(<key>)` substitution, verify the key resolves in every relevant env config in the PR's deploy scope. Missing in any in-scope env = link 3 broken = BLOCKING for that env, MUST-FIX otherwise.

## Env coverage parity

When `ScopeBindings.json` adds a NEW `$config(<key>)` reference, every env config that participates in the deploy plan must declare that key. The PR's diff alone is not sufficient — the oracle must read the FULL set of env configs in `Configuration/Microsoft.M365.LENS.<Service>.*.json` (including ones not in the PR diff) and verify coverage.

Anti-pattern caught by this oracle (PR 5160086):

> PR adds `__GLOBAL_API_ZONE_REDUNDANT__` → `$config(globalApi.zoneRedundant)` to `ScopeBindings.json` and updates `*.ppe.json` + `*.prod.json` with the new key. But `*.npe.json` is unchanged and lacks `globalApi.zoneRedundant`. NPE rollout will either fail at preflight (Ev2 cannot resolve the `$config()` placeholder) or substitute empty string → bicep `bool(toLower(""))` = false silently.

Check: every NEW `$config(<key>)` in the PR's `ScopeBindings.json` diff must also have a NEW key entry in EVERY in-scope env config in the same PR (or the env configs must already have the key — verifiable by reading the full file at HEAD).

## Specific patterns to scan

| Pattern | Severity | Reason |
|---------|----------|--------|
| `__PLACEHOLDER__` in `Parameters/*.parameters.json` without matching `ScopeBindings.json` entry | BLOCKING | Deploy fails preflight |
| `$config(<key>)` in `ScopeBindings.json` without coverage in every in-scope env config | BLOCKING (in-scope env), MUST-FIX (out-of-scope env) | Silent fallback or preflight failure |
| Connection string with password in `Configuration/*.json` | BLOCKING | Use Key Vault reference or managed identity |
| `ownerGroupObjectId` literal GUID without justification | MUST-FIX | Should resolve from ServiceTree (verify against current registered spec via SAW) |
| `providerType` other than `"ServiceTree"` | MUST-FIX | LENS standard is ServiceTree integration |
| `forceRegistration: true` without comment explaining why | SHOULD-FIX | Force-registration tightens registration drift; document the reason |
| Capacity / ZR drift from per-ring documented pattern | SHOULD-FIX | PPE: 1/false, Prod: 2+/true (or per-service equivalent) |
| Two `serviceResourceDefinitions` entries producing the same RG name | BLOCKING | Silent overwrite |
| `RolloutSpec.json` `dependsOn` cycle | BLOCKING | Deploy will hang |

## Cross-file consistency (when ≥2 ev2-config files in PR)

When the PR touches multiple env configs (e.g. `*.ppe.json` + `*.prod.json`):

| Check | What it verifies |
|-------|------------------|
| Same `globalApi` (or equivalent) keys present in all changed env configs | Stylistic + reduces drift surface |
| JSON value types match across env configs for same key | E.g. `skuCapacity` is number in all envs OR string in all envs — not mixed |
| Per-key value differences are intentional (PR description explains) | Capacity differences PPE 1 vs Prod 2 should be called out |

When the PR touches `ScopeBindings.json` AND env configs:

| Check | What it verifies |
|-------|------------------|
| Every NEW `find` token added to `ScopeBindings.json` has a matching new placeholder in `Parameters/*.parameters.json` | Forward chain |
| Every NEW `$config(<key>)` added has a matching new key in every in-scope env config | Backward chain |

## Anti-hallucination

- Scope-binding chain claims cite the literal `find`/`replaceWith` pair from `ScopeBindings.json` and the matching `__PLACEHOLDER__` in `Parameters/*.parameters.json`
- Env coverage claims cite the actual file path of the missing env config (e.g. `Configuration/Microsoft.M365.LENS.Publish.npe.json` line N has `globalApi` block but lacks `zoneRedundant`)
- ServiceTree integration claims cite the SAW `Get-AzureServiceRolloutServiceRegistration` output that authoritatively says what the registered spec contains (or note `[UNVERIFIED — SAW not run]`)
- Capacity discipline claims cite the documented per-ring pattern source (e.g. `references/LENS-Delivery/.../Configuration/*.{ppe,prod}.json`)

## Cross-references

- `rules/prescriptive-content-review.md` Gap 3 (completeness oracle pass) — this oracle's parent rule
- `rules/patterns/cicd-deployment.md` § ScopeBindings vs Config Files — env-specific values belong in env configs, not in ScopeBindings
- `rules/patterns/_dotnet/iac-security-checklist.md` § Scope Binding Fragility — string-find/replace patterns silently fail on reformat
- `rules/patterns/deployment-troubleshooting.md` § Scope binding chain incomplete — the matching runbook for chain breaks
- `rules/non-negotiable-rules.md` — bicep lint mandatory; no manual RBAC; no hardcoded secrets
- `references/LENS-Delivery/sources/dev/Delivery/src/Ev2/ServiceGroupRoot/` — canonical reference for the per-ring capacity pattern
