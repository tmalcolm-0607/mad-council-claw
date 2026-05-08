---
globs: "**/*{frontdoor,waf,FrontDoor,Waf,WAF}*.bicep"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Bicep WAF Conventions

When working with Azure Front Door WAF policies in Bicep templates (`Microsoft.Network/FrontDoorWebApplicationFirewallPolicies`):

- Rules **200002** (Failed to parse request body) and **200003** (Multipart request body failed strict validation) in the **General** rule group of `Microsoft_DefaultRuleSet` will block file uploads exceeding the **128KB body inspection limit** (fixed on AFD WAF — not configurable). Each rule is Critical severity (score=5); a single trigger blocks the request.
- Services that accept file uploads >128KB **must** disable these rules via `ruleGroupOverrides` in the managed rule set configuration.
- Services that do NOT accept file uploads should keep these rules enabled — they provide legitimate body inspection protection.
- When disabling rules, omit the `action` field — it is ignored for disabled rules and avoids API version compatibility issues.
- Manual Azure Portal overrides are NOT reflected in Bicep templates and will regress on the next deployment.

Run `/lens-waf-audit:waf-audit --path <scan-root>` to check compliance across LENS repos.


<!-- TODO: source — LENS-Common plugins/LENS/Security/lens-waf-audit/rules/bicep-waf-conventions.md (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->
