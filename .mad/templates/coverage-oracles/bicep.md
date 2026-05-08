# Coverage Oracle — bicep / bicepparam

What a *complete* `*.bicep` or `*.bicepparam` infra change must cover. Loaded for `infra-change`.

## Required elements

| # | Element | What it covers |
|---|---------|----------------|
| 1 | **Lint clean** | `bicep lint <file>` returns 0 errors, 0 warnings |
| 2 | **Naming convention** | Resource names match project pattern (e.g. `app-<service>-<env>-<region>`); environment + region tokens parameterized |
| 3 | **Parameter declarations** | Required parameters have `@description` decorators; allowed values via `@allowed()` where bounded |
| 4 | **RBAC explicit** | Role assignments declared in bicep, never side-channelled through portal/CLI |
| 5 | **Network isolation** | Resources default to private; public network access requires `@description` justification |
| 6 | **Resource tagging** | `env`, `service`, `owner` tags applied; cost tracking |
| 7 | **Idempotency** | Re-running deploy with same parameters is a no-op |
| 8 | **Output declarations** | Outputs that downstream consumers (Ev2, deployment scripts) need are declared |

## Severity per missing element

| Element | Missing severity |
|---------|------------------|
| 1 **Lint clean** | **BLOCKING** (per `rules/non-negotiable-rules.md` — bicep lint required) |
| 2 Naming convention | MUST-FIX |
| 3 Parameter declarations | MUST-FIX |
| 4 **RBAC explicit** | **BLOCKING** (per `rules/non-negotiable-rules.md` — no manual RBAC) |
| 5 Network isolation | **BLOCKING** for prod-tier; MUST-FIX otherwise |
| 6 Resource tagging | SHOULD-FIX |
| 7 Idempotency | MUST-FIX (caught at deploy if not at lint) |
| 8 Output declarations | MUST-FIX |

## Special checks

- **Public network access**: any `publicNetworkAccess: 'Enabled'` must be paired with a `@description` annotation explaining why; otherwise BLOCKING
- **Hard-coded secrets**: any literal credential / connection string → BLOCKING + treat as security incident
- **Hard-coded subscription / RG**: parameterize per `rules/deployment-scripts.md`

## Cross-file consistency (when ≥2 bicep in PR)

- Module imports consistency: file A imports `modules/cosmos.bicep`; file B should import from the same path
- Parameter passing: parent → child module parameter names match
- Output → input: parent's output references child's expected input

## Anti-hallucination

- "Lint clean" claim must include the actual lint command output (or `[UNVERIFIED — bicep CLI unavailable]` per `rules/verification-protocol.md` Rule 4)
- RBAC claim cites the actual `Microsoft.Authorization/roleAssignments` block, not just the file name

## Cross-references

- `rules/deployment-scripts.md` — wrapper-script discipline
- `rules/non-negotiable-rules.md` — bicep lint + no manual RBAC
- `rules/deployment-failure-diagnosis.md` — when deploys disagree with declared bicep
