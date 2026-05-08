# App Gateway OWASP CRS Upload Rules — Advisory

## Scope

This document covers **Azure Application Gateway WAF** policies using **OWASP Core Rule Set (CRS)** — a separate concern from the AFD WAF rules 200002/200003 that are the primary focus of this skill. App Gateway WAF uses different rule IDs and a different enforcement model.

## OWASP CRS Rules That May Block File Uploads

The following CRS rules are known to interfere with multipart file upload requests:

### 920420 — Request content type is not allowed by policy

**Risk**: HIGH for upload services

The WAF maintains an allowed content type list. If `multipart/form-data` is not explicitly allowed (or if the Content-Type header has non-standard parameters), this rule blocks the request.

**Symptoms**: HTTP 403 on POST/PUT with file attachments. No error in Application Insights if the App Gateway blocks before forwarding.

**Fix**: Add `multipart/form-data` to the allowed content types in the WAF policy, or disable rule 920420 for upload endpoints.

### 920340 — Request has content but Content-Type header is missing / body not allowed

**Risk**: MEDIUM

Triggers when the request has a body but the Content-Type is missing or doesn't match expected patterns. Can fire on chunked upload requests where Content-Type may be set differently.

### 942430 — Restricted SQL character anomaly detection

**Risk**: LOW-MEDIUM for uploads

This SQL injection detection rule can flag multipart boundaries and file content that contains SQL-like patterns. Binary file uploads (PDFs, images) frequently contain byte sequences that match SQL injection signatures.

**Symptoms**: Intermittent 403s depending on file content. Difficult to reproduce because it depends on the specific bytes in the uploaded file.

## Current LENS State

| Repo | File | OWASP Version | Upload Override Status |
|------|------|---------------|----------------------|
| LENS-LEAPI | `appGatewayFirewall.bicep` | OWASP 3.2 | `ruleGroupOverrides: []` — no overrides |
| LENS-Delivery | `appGatewayFirewall.bicep` | OWASP 3.2 | `ruleGroupOverrides: []` — no overrides |

Both templates have `requestBodyCheck: true` and empty `ruleGroupOverrides`. If these services accept file uploads through the App Gateway path, the OWASP rules above may need tuning.

## Key Differences from AFD WAF

| Dimension | AFD WAF (Microsoft_DefaultRuleSet) | App Gateway WAF (OWASP CRS) |
|-----------|-----------------------------------|------------------------------|
| Rule IDs for upload issues | 200002, 200003 | 920420, 920340, 942430 |
| Body inspection limit | **128KB fixed** (not configurable) | 128KB default, configurable up to 2MB via `requestBodyInspectLimitInKB` |
| Scoring model | Anomaly scoring → threshold block | Per-rule or anomaly scoring (version-dependent) |
| Override mechanism | `ruleGroupOverrides` in managed rule set | `ruleGroupOverrides` in managed rule set |
| Bicep resource type | `FrontDoorWebApplicationFirewallPolicies` | `ApplicationGatewayWebApplicationFirewallPolicies` |

## Recommendation

This skill focuses on AFD WAF rules 200002/200003. App Gateway OWASP CRS rules are flagged as **ADVISORY** in the audit report. For services that route file uploads through App Gateway:

1. Review CRS rules 920420, 920340, and 942430 manually
2. Test file upload scenarios with the WAF in Detection mode before switching to Prevention
3. Consider creating a separate skill for App Gateway WAF audit if multiple services are affected
