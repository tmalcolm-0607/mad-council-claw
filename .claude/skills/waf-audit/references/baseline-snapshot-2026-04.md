# WAF Template Baseline Snapshot

**Snapshot Date**: 2026-04-06
**Scanned By**: Claude Code audit of LENS-Projects workspace
**Purpose**: Baseline for delta reporting. The live Glob/Grep scan is authoritative — this snapshot enables detection of new or removed templates between audits.

## AFD WAF Templates

| Repo | File Path | API Version | WAF Mode (Default) | Body Check | Override Status | Deployed |
|------|-----------|-------------|-------------------|------------|-----------------|----------|
| LENS-LEPortal | `sources/dev/Ev2/Bicep/modules/frontdoor.bicep` | `@2024-02-01` | Prevention (param `wafMode`) | Enabled | **Compliant** (rules 200002/200003 disabled at line 178) | Yes |
| LENS-LRMS | `sources/dev/Ev2/ServiceGroupRoot/Templates/frontdoor.bicep` | `@2024-02-01` | Detection (param `wafMode`) | Enabled | Non-compliant (`ruleGroupOverrides: []` at line 195) | Yes |
| LENS-LEAPI | `sources/dev/LEAPI/src/Ev2/Bicep/frontDoorWAF.bicep` | `@2025-03-01` | Detection (literal) | Enabled (default) | Non-compliant (`ruleGroupOverrides: []` at line 62) | No — `shouldDeployFrontDoor = false` in `main.bicep:116` |
| M365CLASS | `sources/dev/ClassAPI.Deployment/GriffinEv2/Templates/Bicep/Modules/General/FrontDoorWafPolicy.bicep` | `@2024-02-01` | Prevention (literal) | Enabled | Non-compliant (`ruleGroupOverrides: []` at line 55) | Yes |

## App Gateway WAF Templates (Advisory — OWASP CRS, different concern)

| Repo | File Path | Rule Set | Notes |
|------|-----------|----------|-------|
| LENS-LEAPI | `sources/dev/LEAPI/src/Ev2/Bicep/appGatewayFirewall.bicep` | OWASP 3.2 | `requestBodyCheck: true`, `ruleGroupOverrides: []` |
| LENS-Delivery | `sources/dev/Delivery/src/Ev2/ServiceGroupRoot/Templates/appGatewayFirewall.bicep` | OWASP 3.2 | `requestBodyCheck: true`, `ruleGroupOverrides: []` |

## AFD Profiles Without WAF

| Repo | File Path | Tier | Notes |
|------|-----------|------|-------|
| LENS-Publish | `sources/dev/Publish/Ev2/ServiceGroupRoot/modules/global/frontdoor.bicep` | Standard | No WAF — uses defense-in-depth at App Service layer (FDID header validation, IP restrictions, S2S OAuth) |

## Upload Endpoint Inventory (per-repo)

Discovered via codebase analysis (April 2026). Use this to cross-reference upload exposure against WAF policy state.

### LENS-LEPortal (5 upload routes, multipart/form-data)

| Route | Method | Max Size | Controller | Notes |
|-------|--------|----------|------------|-------|
| `/api/v1/files/upload` | POST | 50MB | FilesController | Single IFormFile |
| `/api/v1/domesticSubmission/uploadFile` | POST | 25MB | DomesticSubmissionController | IFormFileCollection |
| `/api/v1/internationalSubmission/uploadFile` | POST | 25MB | InternationalSubmissionController | IFormFileCollection |
| `/api/v1/internationalReview/approve/{id}` | POST | 25MB | InternationalReviewController | Optional IFormFileCollection |
| `/api/v1/internationalReview/update/{id}` | POST | 25MB | InternationalReviewController | Optional IFormFileCollection |

### LENS-LRMS (1 upload route, multipart/form-data)

| Route | Method | Max Size | Controller |
|-------|--------|----------|------------|
| `/api/v1/files/upload` | POST | 50MB | FilesController |

### LENS-LEAPI (0 multipart — XML only, Front Door disabled)

| Route | Method | Max Size | Content Type | Notes |
|-------|--------|----------|-------------|-------|
| `/api/v1` | POST | 30MB (Kestrel default) | application/xml | HI1 messages — rule 200003 won't fire (not multipart), only 200002 for XML >128KB |
| `/eevidence/*` (10 routes) | POST | 30MB | application/xml | HI1 with DocumentObject — same as above |

### M365CLASS — Upload routes unknown, needs analysis

## How to Use This Snapshot

The `waf-audit` skill compares live discovery against this snapshot:

1. **Template in live scan but NOT in snapshot** → "Newly discovered" — indicates a new repo or template was added since this snapshot. Update the snapshot after confirming.
2. **Template in snapshot but NOT in live scan** → "Not found" — the repo may not be cloned locally, or the template was renamed/removed. Verify before removing from snapshot.

### Updating This Snapshot

After running a full audit and confirming results, update this file with the current state. Always update the **Snapshot Date** at the top. This file is a point-in-time reference, not a living registry.
