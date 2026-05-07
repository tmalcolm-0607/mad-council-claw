---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-d)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-004 / lane-d
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-069
short-slug: settings-per-automation-rules
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - cp:per-automation-rules (clawpilot per-automation rule overrides)
    - foundational-plan:M7 § Skills+Perms+Auto (F-061..F-066 automations base)
    - kit:rules/no-silent-deferrals.md (per-rule scope discipline)
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-069-settings-per-automation-rules-review.md exists with verdict: ACCEPT.
depends-on: [F-067, F-061, F-062, F-063]
out-of-scope-notes: |
  The automation primitives themselves (cron / condition / multistep) live in M7 (F-062, F-063, F-064) — F-069 is the per-automation override surface.
  Centralized rule conflict resolution UI (e.g. "two rules apply to the same trigger") is v1.5; v1 evaluates rules in declared order with last-match-wins.
  Cross-workspace rule inheritance is F-073/F-075 territory; F-069 is the global rule store.
  Sandbox / dry-run preview of a rule's effects is v1.5.
confidence: high
---

# F-069 — Per-automation rules

## Behavior contract

Each automation (per F-061..F-066) MAY carry a per-rule override block in `settings.json:automation_rules[<automation-id>]`. Override fields include: `enabled` (bool), `model_override` (string, e.g. "haiku" for cost-sensitive automations), `permission_tier_override` (one of read/write/admin per F-058), `mcp_servers_override` (allowlist subset of F-049 servers), `system_prompt_append` (additional system-message text appended to F-037 base), `cost_cap_per_run_usd` (numeric guardrail). Missing override fields fall back to global settings (F-067). Overrides apply ONLY to that specific automation — other automations consume global settings. Rules are validated against `schemas/automation-rule.schema.json` on load; invalid rules are loaded with a `[DISABLED]` flag + structured error in the audit log (per F-015 hash-audit). Per `kit:rules/no-silent-deferrals.md`, a rule that fails validation is NOT silently dropped — it persists in the file with the disabled flag so the user can see + repair.

## Acceptance scenarios

1. **Given** an automation `morning-briefing` with `model_override: "haiku"`, **When** the automation runs, **Then** the engine uses Haiku for that run + global model setting is unaffected for other automations.
2. **Given** a malformed rule in `settings.json:automation_rules` (e.g. `cost_cap_per_run_usd: "free"` — wrong type), **When** the engine loads, **Then** the rule is preserved on disk + flagged `[DISABLED]` in memory + a structured error appears in the audit log + other rules still load normally.
3. **Given** an automation with `cost_cap_per_run_usd: 0.10` + a run accumulating $0.11 of token spend, **When** the cap is exceeded, **Then** the automation halts with `COST_CAP_EXCEEDED` + the partial result is captured in audit + the next run is NOT auto-disabled (cap-per-run, not cap-cumulative).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/automation/per-rule-model-override.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/automation/per-rule-validation-error.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/automation/per-rule-cost-cap.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-067 (settings shape provides `automation_rules` slot), F-061 (automations base), F-062 (cron-driven), F-063 (condition-driven)
- **Soft:** F-019 (cost ledger sources cap enforcement), F-058 (permission tier overrides), F-049 (MCP server allowlist subset)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., per-automation rules, ..." |
| cp:per-automation-rules | Clawpilot per-automation override pattern |
| foundational-plan:M7 | Automation primitives (F-061..F-066) that consume these rules |
| kit:rules/no-silent-deferrals.md | Validation-failed rules disabled-not-dropped discipline |

## Implementation notes

(empty — populated when implementation begins)
