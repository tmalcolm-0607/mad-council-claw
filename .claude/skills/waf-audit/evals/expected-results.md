# Expected Eval Results

Verification table for the eval fixtures. Run the skill against `evals/fixtures/` and confirm each fixture produces the expected classification.

## Test Matrix

**Standalone Result** = deterministic classification when running against the fixture directory alone (no repo context → upload exposure is always "None detected").
**With Repo Context** = classification range when running against a real LENS repo (upload exposure varies by repo).

| Fixture File | Type | Mode | Body Check | Override Status | Deployed | Standalone Result | With Repo Context |
|-------------|------|------|------------|-----------------|----------|-------------------|-------------------|
| `compliant.bicep` | AFD WAF | Prevention | Enabled | Both disabled | Yes | **OK** | OK (always) |
| `non-compliant.bicep` | AFD WAF | Prevention | Enabled | Empty `[]` | Yes | **INFO** (none detected) | CRITICAL (confirmed) / HIGH (unknown) / INFO (none detected) |
| `non-compliant.json` | ARM JSON | Prevention | Enabled | Empty `[]` | Yes | **INFO** (none detected) | Same as Bicep counterpart — tests Phase 1b ARM discovery |
| `partial-override.bicep` | AFD WAF | Prevention | Enabled | Only 200002 | Yes | **INFO** (none detected) | CRITICAL (confirmed) / HIGH (unknown) / INFO (none detected) |
| `conditional-deploy.bicep` | AFD WAF | N/A (DEFERRED overrides) | Enabled | Empty `[]` | No | **DEFERRED** | DEFERRED (always — row 1 matches regardless of other dimensions) |
| `body-check-disabled.bicep` | AFD WAF | Prevention | **Disabled** | Empty `[]` | Yes | **OK** (body check off) | OK (always — row 2 matches) |
| `detection-mode.bicep` | AFD WAF | Detection (param) | Enabled | Empty `[]` | Yes | **INFO** (none detected) | MEDIUM (confirmed) / LOW (unknown) / INFO (none detected) |
| `detection-partial.bicep` | AFD WAF | Detection | Enabled | Only 200002 | Yes | **INFO** (none detected) | MEDIUM (confirmed) / LOW (unknown) / INFO (none detected) |
| `appgateway-owasp.bicep` | App GW | Prevention | Enabled | OWASP CRS | Yes | **ADVISORY** | ADVISORY (always — App Gateway is a separate concern) |
| `parameterized-mode.bicep` | AFD WAF | Parameterized (no default) | Enabled | Empty `[]` | Yes | **INFO** (none detected) | CRITICAL (confirmed) / HIGH (unknown) / INFO (none detected) |

## Additional Validation Points

### `compliant.bicep`
- `--fix` should NOT generate a fix snippet (already compliant)
- Report should show "OK" in risk column

### `non-compliant.bicep`
- `--fix` generates a snippet ONLY when upload exposure is Confirmed or Unknown+HIGH (not for standalone INFO)
- Snippet should replace `ruleGroupOverrides: []`, omit `action` field, include both rules 200002 and 200003

### `non-compliant.json`
- Tests Phase 1b ARM JSON discovery — skill must find this file via `**/*.json` glob + `FrontDoorWebApplicationFirewallPolicies` grep
- Classification logic is identical to Bicep — validates the parser handles JSON syntax (quoted keys, `"type": "..."`)
- `--fix` should output JSON-format fix snippet (not Bicep) per Phase 4 ARM JSON note

### `partial-override.bicep`
- `--fix` should generate a snippet that ADDS rule 200003 to the **existing** General group's `rules` array (Case C in Phase 4)
- Must NOT create a duplicate General group — the General group already exists with 200002
- Must NOT remove or replace the existing 200002 override
- Report should clearly state which rule is missing (200003)

### `conditional-deploy.bicep`
- `--fix` should NOT generate a snippet (DEFERRED — not deployed)
- Report should identify the conditional gate variable (`shouldDeployFrontDoor = false`) and its value
- Report should recommend tracking ticket for when Front Door is enabled
- Mode is irrelevant — DEFERRED overrides all other dimensions (row 1)

### `body-check-disabled.bicep`
- `--fix` should NOT generate a snippet (rules inactive — no override needed)
- Report should note security trade-off: "body check disabled removes all body-level WAF protections"

### `detection-mode.bicep`
- Skill should trace parameterized `mode: wafMode` to find `param wafMode` with default `'Detection'`
- `ruleSetAction: 'Block'` should NOT cause misclassification — Detection mode overrides to log-only
- Report should note: "will block when promoted to Prevention mode"

### `detection-partial.bicep`
- Tests rows 9/9a/9b of the risk matrix (Detection + Partial)
- Skill should detect that 200003 is missing from the General group override
- `--fix` generates Case C snippet ONLY if upload exposure is Confirmed (MEDIUM risk)
- For standalone runs: upload=None detected → INFO → no fix generated
- `ruleSetAction: 'Block'` should NOT elevate risk — Detection mode overrides to log-only

### `appgateway-owasp.bicep`
- Tests Phase 2b App Gateway WAF advisory detection
- Skill should identify `ApplicationGatewayWebApplicationFirewallPolicies` resource type and OWASP rule set
- Classification is always **ADVISORY** regardless of upload exposure or other dimensions
- Report should note OWASP CRS rules 920420, 920340, 942430 may block multipart uploads
- `--fix` should NOT generate a fix snippet (App Gateway is out of scope for AFD-focused fixes)

### `parameterized-mode.bicep`
- Tests rows 11/11a/11b (Parameterized/Unknown WAF mode)
- Skill should detect `mode: wafMode` references a param with NO default value → mode is unresolvable
- Pre-processing instruction: assume Prevention (worst case) for risk classification
- Standalone result: INFO (row 11b — Parameterized + Non-compliant + None detected)
- With confirmed upload context: CRITICAL (row 11)
- Report should flag: "WAF mode determined at deploy time — verify in Azure Portal"
