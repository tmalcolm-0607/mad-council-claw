---
name: waf-audit
description: >
  Scan Bicep and ARM deployment templates for Azure Front Door WAF misconfigurations
  where rules 200002 and 200003 block file uploads exceeding the 128KB body inspection
  limit. Classifies risk across 5 dimensions: deployment state, WAF mode, request body
  check, rule override status, and upload exposure. Generates API-version-aware fix
  snippets. Also flags App Gateway OWASP CRS rules that may block multipart uploads.
  Use when auditing AFD WAF policies, checking upload-blocking rules, scanning
  deployment templates for security misconfigurations, or preparing services for
  Prevention mode promotion.
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
user-invocable: true
version: 1.0.0
changelog:
  - "1.0.0: Initial release — AFD WAF rules 200002/200003 scanner with 5-dimension risk matrix, 23-row classification, alternative architecture documentation"
---

<!-- TODO: source — LENS-Common plugins/LENS/Security/lens-waf-audit (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->

# AFD WAF File Upload Risk Audit

Scan Azure Front Door WAF policies in Bicep/ARM templates for rules that silently block file uploads. Classifies risk, flags IaC drift from manual Azure Portal fixes, and generates remediation snippets.

## Usage

```
/lens-waf-audit:waf-audit --path /path/to/repos          # Scan all repos under path
/lens-waf-audit:waf-audit --path /path/to/repos --fix     # Also generate fix snippets
/lens-waf-audit:waf-audit --discover                       # Auto-discover repos from cwd parent
/lens-waf-audit:waf-audit --path /path/to/repos --repos LENS-LEPortal,LENS-LRMS  # Limit scope
```

## Overview

Azure Front Door WAF managed rules **200002** (Failed to parse request body) and **200003** (Multipart request body failed strict validation) are part of the **General** rule group in `Microsoft_DefaultRuleSet`. They trigger when the WAF cannot fully inspect a request body — which happens on every file upload exceeding the **128KB body inspection limit** (fixed on AFD WAF — not configurable, unlike Application Gateway WAF which supports up to 2MB).

Both rules are **Critical severity (anomaly score = 5)**. The blocking threshold in DRS 2.1 is also 5. This means a **single trigger of either rule alone is sufficient to block the request** — you don't need both to fire. When triggered in Prevention mode, rule 949110 ("Inbound Anomaly Score Exceeded") returns HTTP 403 to the client. The request never reaches the application backend, so Application Insights shows nothing.

This skill scans Bicep and ARM JSON templates to detect missing `ruleGroupOverrides` that should disable these rules for services accepting file uploads.

**Important**: Rules 200002/200003 provide legitimate protection for services that do NOT accept large file uploads. This skill only recommends disabling them for services with confirmed or suspected upload endpoints.

---

## Execution Flow

### Phase 0: Parse Arguments & Discover Scan Root

**Parse the command arguments:**

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--path <dir>` | Yes (unless `--discover`) | None | Root directory containing repo directories to scan |
| `--fix` | No | Off | Generate API-version-aware remediation Bicep snippets |
| `--repos repo1,repo2` | No | All | Comma-separated repo directory names to limit scope (requires `--path` or `--discover`) |
| `--discover` | No | Off | Auto-discover repos: scan parent of cwd for `LENS-*` / `M365*` directories (alternative to `--path`) |

**If `--discover` is used:**
1. Determine parent directory of the current working directory
2. List all subdirectories matching `LENS-*` or `M365*` patterns
3. Display the discovered directories and their paths
4. Use AskUserQuestion to confirm before proceeding: "Found N repos: {list}. Scan all?"

**Validate** the scan root exists and contains at least one directory with `.bicep` or `.json` files. If not, report an error and stop.

---

### Phase 1: Discover WAF Template Files

**Step 1a — Find AFD WAF Bicep templates:**
```
Glob: **/*.bicep under scan root
Grep for: Microsoft.Network/FrontDoorWebApplicationFirewallPolicies
```
Case-insensitive match — the resource type can appear in various casings across templates.

**Step 1b — Find AFD WAF ARM JSON templates:**
```
Glob: **/*.json under scan root (exclude node_modules/, bin/, obj/, .git/, target/)
Grep for: FrontDoorWebApplicationFirewallPolicies
```
This catches raw ARM templates not compiled from Bicep.

**Step 1c — Find App Gateway WAF templates (for advisory):**
```
Grep for: Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies
   OR: ruleSetType.*OWASP
```
Collect these separately — they use OWASP CRS rules, not Microsoft_DefaultRuleSet.

**Step 1d — Baseline comparison:**
Read the **"AFD WAF Templates"** section of `references/baseline-snapshot-2026-04.md` and compare against live discovery. Only compare WAF template entries — ignore the "App Gateway WAF Templates" and "AFD Profiles Without WAF" sections (those are informational context, not scan targets).
- Templates found in live scan but NOT in baseline → report as "Newly discovered (not in baseline)"
- Templates in baseline but NOT found in live scan → report as "Not found (repo not cloned or template removed)"
- **When `--repos` is active**: Only compare baseline entries for repos in the active set. Do NOT report "Not found" for repos excluded by the `--repos` filter.

**For each discovered file, record:**
- Full file path
- Parent repo directory name
- WAF type: AFD or App Gateway

---

### Phase 2: Analyze Each AFD WAF Template

For each AFD WAF template file discovered in Phase 1, read the full file and extract:

#### 2.1 API Version
Extract the API version from the resource type declaration. Look for the pattern:
```
'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@{VERSION}'
```
Examples: `@2024-02-01`, `@2025-03-01`. Record this — it determines fix snippet format.

#### 2.2 WAF Mode
Find the `mode:` field inside `policySettings`. It can be:

- **Literal string**: `mode: 'Prevention'` or `mode: 'Detection'` → use directly
- **Parameter reference**: `mode: wafMode` → trace to the `param` declaration:
  1. Search the same file for `param wafMode` to find its default value
  2. Search adjacent parameter files (`*.parameters.json`, `Environments/*/Parameters/*.json`) for override values
  3. If EV2 tokens are found (pattern: `__double_underscore__`), flag as: **"Mode determined at deploy time — verify in Azure Portal"**

Record: mode value, whether it's parameterized, any environment overrides found.

#### 2.3 Request Body Check
Find `requestBodyCheck:` in `policySettings`:
- `'Enabled'` or `true` → body inspection is active, rules 200002/200003 CAN fire
- `'Disabled'` or `false` → body inspection is OFF, rules NEVER fire (override is unnecessary)
- **Not present** → defaults to `Enabled` (Azure default behavior)

#### 2.4 Deployment State
Determine if the WAF template is actually deployed. Check **both** patterns:

**Pattern A — Module-level conditional** (cross-file, e.g., LENS-LEAPI):
1. Find the `main.bicep` in the same Ev2/Bicep directory (or parent)
2. Search for `module` declarations that reference this WAF template filename
3. Check if the module is gated behind an `if(...)` conditional
4. If the conditional references a variable, trace the variable to its value

**Pattern B — Resource-level conditional** (same-file, e.g., `resource wafPolicy ... = if (condition)`):
1. Check if the WAF `resource` declaration itself has an `if(...)` condition
2. Trace the condition variable to its value in the same file

**For either pattern**, resolve the conditional:
- `var shouldDeploy = false` → template is NOT deployed → **DEFERRED**
- `var shouldDeploy = true` or no conditional → template IS deployed
- Parameter-controlled conditional → check parameter default and parameter files. If unresolvable (EV2 token), assume deployed (worst case) and flag uncertainty (row 1a)

If no `main.bicep` is found, no module reference exists, and the resource has no `if()`, assume it IS deployed.

#### 2.5 Managed Rule Set Analysis
Find the `managedRules` section and iterate `managedRuleSets`. For each entry with `ruleSetType: 'Microsoft_DefaultRuleSet'`:

1. Read the `ruleSetVersion` (e.g., `'2.1'`)
2. Read the `ruleSetAction` (e.g., `'Block'`) — note: in Detection mode this is overridden to log-only
3. Check `ruleGroupOverrides` array:

   **If empty (`[]`):**
   → Classification: **NON-COMPLIANT** — neither rule is disabled

   **If contains entries, search for `ruleGroupName: 'General'`:**
   - Check for `ruleId: '200002'` with `enabledState: 'Disabled'`
   - Check for `ruleId: '200003'` with `enabledState: 'Disabled'`
   - Both disabled → **COMPLIANT**
   - Only one disabled → **PARTIAL**
   - General group not found or rules not listed → **NON-COMPLIANT**

If the `ruleGroupOverrides` property is absent entirely (legal Bicep — Azure defaults to no overrides), treat as equivalent to `ruleGroupOverrides: []` → **NON-COMPLIANT**.

Record: override status, line number of `ruleGroupOverrides` (or the `managedRuleSets` entry if absent), ruleSetVersion, ruleSetAction.

> **Important**: `ruleSetAction: 'Block'` is overridden to log-only when `mode: 'Detection'`. Do NOT classify a Detection-mode template as actively blocking based on `ruleSetAction` alone. Only Prevention mode enforces the `ruleSetAction`.

#### 2.6 Upload Exposure Heuristic
Determine if the service behind this WAF accepts file uploads >128KB:

**Confirmed upload services** (from RCA and known context):
- `LENS-LEPortal` — preservation request file uploads up to 25MB
- `LENS-LEAPI` — large legal document uploads (when Front Door is enabled)

**Heuristic checks:**
1. In the same Bicep file or nearby route definitions, look for `/api/*` patterns in route configurations
2. In the same repo, search for multipart form handling: `multipart/form-data`, `IFormFile`, `[FromForm]`, `upload`, `file`
3. Check repo README or CLAUDE.md for mentions of file upload functionality

**Classify:**
- **Confirmed** — repo is in the known upload services list OR heuristic finds strong evidence
- **Unknown** — heuristic inconclusive, needs manual review
- **None detected** — no upload evidence found (but note this is heuristic, not definitive)

---

### Phase 2b: App Gateway WAF Advisory

For each App Gateway WAF template found in Phase 1c:

1. Read the file and extract the OWASP `ruleSetVersion`
2. Note that the following OWASP CRS rules may block multipart file uploads:
   - **920420** — Request content type is not allowed by policy
   - **920340** — Request has content but Content-Type header is missing or body not allowed
   - **942430** — Restricted SQL character anomaly detection (can flag multipart boundaries)
3. Check if `ruleGroupOverrides` contains any overrides for these rules
4. Classify as **ADVISORY** — these require separate analysis outside the scope of this AFD-focused skill

Record: file path, OWASP version, whether any upload-related overrides exist.

---

### Phase 3: Classify & Report

#### Risk Classification Matrix

Apply the following matrix to each AFD WAF template. Evaluate conditions top-to-bottom; first match wins.

> **Pre-processing**: If deployment state is unknown (parameterized gate with EV2 token), treat as deployed (`Yes`) and flag the uncertainty in the report. Then continue evaluation normally.

| # | Deployed? | Body Check | Mode | Override Status | Upload Exposure | Risk Level |
|---|-----------|------------|------|-----------------|-----------------|------------|
| 1 | No (conditional=false) | Any | Any | Any | Any | **DEFERRED** |
| 2 | Yes | Disabled | Any | Any | Any | **OK** (body check off) |
| 3 | Yes | Enabled | Prevention | Non-compliant | Confirmed | **CRITICAL** |
| 4 | Yes | Enabled | Prevention | Non-compliant | Unknown | **HIGH** |
| 4a | Yes | Enabled | Prevention | Non-compliant | None detected | **INFO** |
| 5 | Yes | Enabled | Prevention | Partial | Confirmed | **CRITICAL** |
| 5a | Yes | Enabled | Prevention | Partial | Unknown | **HIGH** |
| 5b | Yes | Enabled | Prevention | Partial | None detected | **INFO** |
| 6 | Yes | Enabled | Prevention | Compliant | Any | **OK** |
| 7 | Yes | Enabled | Detection | Non-compliant | Confirmed | **MEDIUM** |
| 8 | Yes | Enabled | Detection | Non-compliant | Unknown | **LOW** |
| 8a | Yes | Enabled | Detection | Non-compliant | None detected | **INFO** |
| 9 | Yes | Enabled | Detection | Partial | Confirmed | **MEDIUM** |
| 9a | Yes | Enabled | Detection | Partial | Unknown | **LOW** |
| 9b | Yes | Enabled | Detection | Partial | None detected | **INFO** |
| 10 | Yes | Enabled | Detection | Compliant | Any | **OK** |
| 11 | Yes | Enabled | Parameterized/Unknown | Non-compliant | Confirmed | **CRITICAL** (assume Prevention) |
| 11a | Yes | Enabled | Parameterized/Unknown | Non-compliant | Unknown | **HIGH** |
| 11b | Yes | Enabled | Parameterized/Unknown | Non-compliant | None detected | **INFO** |
| 12 | Yes | Enabled | Parameterized/Unknown | Partial | Confirmed | **CRITICAL** (assume Prevention) |
| 12a | Yes | Enabled | Parameterized/Unknown | Partial | Unknown | **HIGH** |
| 12b | Yes | Enabled | Parameterized/Unknown | Partial | None detected | **INFO** |
| 13 | Yes | Enabled | Parameterized/Unknown | Compliant | Any | **OK** |

**Note on row 2**: While `requestBodyCheck: Disabled` means rules 200002/200003 won't fire, disabling body check entirely removes all body-level WAF protections. Flag this as a security trade-off in the report.

**Note on INFO rows (4a/5b/8a/9b/11b/12b)**: When upload exposure is "None detected", the rules are technically non-compliant but the service likely doesn't need the override. Report as **INFO** for awareness — do NOT recommend disabling rules. The heuristic may have missed upload endpoints, so flag for manual confirmation.

**Note on rows 11–12a**: When WAF mode cannot be determined (EV2 tokens, complex parameter logic), assume Prevention (worst case) for risk classification. Upload exposure still determines whether to recommend action (Confirmed/Unknown) or just flag (None detected).

#### Report Format

Output a Markdown report to stdout with the following sections:

```markdown
## AFD WAF File Upload Risk Audit

**Scan Date**: {YYYY-MM-DD}
**Scan Root**: {path}
**Templates Scanned**: {count AFD WAF} AFD WAF | {count App GW} App Gateway WAF

---

### Summary

| Repo | File | API Version | Mode | Body Check | Rules 200002/200003 | Upload Exposure | Deployed | Risk |
|------|------|-------------|------|------------|---------------------|-----------------|----------|------|
{one row per template}

---

### Critical & High Findings

{For each CRITICAL or HIGH template:}
#### {Repo} — {Risk Level}
- **File**: `{path}:{line}`
- **WAF Mode**: {mode} {(parameterized from: param name, default: value)}
- **Body Check**: {Enabled/Disabled}
- **Override Status**: {Non-compliant/Partial} — `ruleGroupOverrides` at line {N} is {empty/missing rule}
- **Upload Exposure**: {Confirmed/Unknown}
- **Action Required**: {specific recommendation}

---

### Deferred Findings

{For each DEFERRED template:}
- **{Repo}**: `{file}` — gated behind `{variable} = false` in `{main.bicep}:{line}`
- **When activated**: Will need rules 200002/200003 disabled before switching to Prevention mode
- **Recommendation**: Create a tracking ticket to fix WAF overrides before enabling Front Door

---

### App Gateway WAF Advisories

{For each App Gateway WAF template:}
- **{Repo}**: `{file}` — OWASP CRS {version}
- Rules 920420, 920340, 942430 may block multipart file uploads
- Override status: {overrides found / no overrides}
- **Action**: Manual review required if this service accepts file uploads

---

### Baseline Comparison

- **Newly discovered**: {list of templates not in baseline, or "None"}
- **Missing from scan**: {list of baseline templates not found, or "None — all baseline templates found"}

---

### Environment Uncertainty

{For templates where WAF mode uses EV2 tokens or complex parameters:}
- **{Repo}**: `{file}` — WAF mode is `{param name}`, resolved at deploy time via EV2 token `{token}`
- Verify actual deployed mode in Azure Portal > Front Door > WAF Policy > Policy Settings
```

---

### Phase 4: Generate Fix Snippets (if `--fix`)

For each non-compliant template, generate a fix ONLY if:
- Upload exposure is **Confirmed**, OR
- Risk is **HIGH** or **CRITICAL** (unknown upload exposure in Prevention mode)

**Do NOT generate fixes for:**
- **DEFERRED** templates (not deployed — fix when enabling Front Door)
- Templates where upload exposure is **None detected** (disabling rules weakens security for no benefit)
- **OK** templates (already compliant)

#### Fix Generation Steps

1. Read the API version from the resource declaration (extracted in Phase 2.1)
2. Find the exact line number of the `ruleGroupOverrides: []` (or the `ruleGroupOverrides` array if it has other entries)
3. Generate the replacement Bicep:

**Case A — Empty `ruleGroupOverrides: []`** (NON-COMPLIANT):

Replace with the full override block:
```bicep
ruleGroupOverrides: [
  {
    ruleGroupName: 'General'
    rules: [
      {
        ruleId: '200002'
        enabledState: 'Disabled'
      }
      {
        ruleId: '200003'
        enabledState: 'Disabled'
      }
    ]
  }
]
```

**Case B — `ruleGroupOverrides` has entries but NO General group** (NON-COMPLIANT with other overrides):

Append the General group object to the existing `ruleGroupOverrides` array. Do NOT replace existing override groups.

**Case C — `ruleGroupOverrides` has a General group but it's incomplete** (PARTIAL):

The General group already exists with one rule (e.g., only 200002). Add the missing rule to the existing General group's `rules` array. Do NOT create a duplicate General group. For example, if 200002 is already disabled but 200003 is missing, add only 200003:
```bicep
// Add to the existing General group's rules array:
{
  ruleId: '200003'
  enabledState: 'Disabled'
}
```

**Note on `action` field**: The `action` field is intentionally omitted in all cases. When `enabledState: 'Disabled'`, the action is ignored by Azure. Omitting it avoids schema validation differences across API versions (`@2024-02-01` vs `@2025-03-01`).

**Note on ARM JSON templates**: Fix snippets are generated in Bicep syntax. If the non-compliant template is an ARM JSON file (discovered via Phase 1b), output the equivalent JSON `ruleGroupOverrides` structure and note that migration to Bicep is recommended.

4. Output the fix with context:

```markdown
#### Fix: {Repo} — `{file}:{line}`

**API Version**: {version}
**Current** (line {N}):
\`\`\`bicep
ruleGroupOverrides: []
\`\`\`

**Replace with**:
\`\`\`bicep
{generated snippet}
\`\`\`
```

5. **For templates where upload exposure is Unknown** (HIGH risk in Prevention mode), prepend the fix with:

> **MANUAL REVIEW REQUIRED**: Confirm this service accepts file uploads >128KB before applying this fix. Disabling rules 200002/200003 for services that don't need file uploads weakens WAF body inspection protection without benefit.

---

### Phase 5: Summary & Next Steps

Output prioritized action items:

```markdown
### Recommended Actions (Priority Order)

1. **[CRITICAL]** {Repo}: Create PR to add ruleGroupOverrides in `{file}` — currently blocking uploads in production
   - Note: Manual fix in Azure Portal will regress on next Bicep deployment {if applicable}

2. **[HIGH]** {Repo}: Review upload exposure and add ruleGroupOverrides if confirmed

3. **[MEDIUM]** {Repo}: Add ruleGroupOverrides before promoting WAF from Detection to Prevention mode

4. **[DEFERRED]** {Repo}: Track — add ruleGroupOverrides when Front Door deployment is enabled

5. **[ADVISORY]** {Repo}: Review App Gateway OWASP CRS rules for upload compatibility

### IaC Drift Warning

{For any template where the Azure Portal has manual overrides not reflected in Bicep:}
- **{Repo}**: Rules 200002/200003 were disabled manually in Azure Portal but the Bicep template still has `ruleGroupOverrides: []`. The next Bicep deployment will **re-enable these rules**, causing upload failures to recur. Fix the template BEFORE the next deployment.

### Detection-to-Prevention Checklist

For services planning to switch WAF mode from Detection to Prevention:
1. Run this audit to confirm rules 200002/200003 status
2. Apply ruleGroupOverrides fix if the service accepts file uploads
3. Test file upload scenarios in PPE with Prevention mode enabled
4. Deploy to PROD only after PPE validation
```

---

## Output Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| Risk audit report | stdout (Markdown) | Full findings with risk classification per template |
| Fix snippets | stdout (Markdown, if `--fix`) | API-version-aware Bicep remediation code |
| Baseline deltas | Included in report | New or missing templates vs. dated snapshot |

---

## Integration Points

**Spawns**: None

**Reads**:
- `**/*.bicep` — Bicep deployment templates across scan root
- `**/*.json` — ARM JSON templates and parameter files
- `references/baseline-snapshot-2026-04.md` — known template baseline
- `references/afd-waf-rules-200002-200003.md` — technical background (for context)
- `references/owasp-upload-rules-advisory.md` — App Gateway OWASP rules reference

**Writes**: None (read-only skill)

**Updates**: None

---

## Success Criteria

- [ ] All AFD WAF templates in scan scope are discovered (Bicep and ARM JSON)
- [ ] Zero false negatives for empty `ruleGroupOverrides: []` on `Microsoft_DefaultRuleSet`
- [ ] Risk classification correctly accounts for all 5 dimensions (deployed, mode, body check, override, upload)
- [ ] DEFERRED classification applied to templates gated behind conditional deployment flags
- [ ] Fix snippets omit `action` field (API-version-safe) and only target confirmed/suspected upload services
- [ ] Templates with unknown upload exposure include "MANUAL REVIEW REQUIRED" warning
- [ ] App Gateway WAF templates reported as ADVISORY with OWASP rule references
- [ ] Baseline comparison identifies new and missing templates
- [ ] Parameter file scanning detects environment-specific WAF mode overrides
- [ ] EV2 token references flagged as "verify in Azure Portal"

---

## Safety Rules

- **READ-ONLY** — NEVER modify any Bicep, JSON, parameter, or other file. This skill only reads and reports.
- **Never run `az` CLI commands** or make Azure API calls. All analysis is file-system based.
- **`--fix` generates display-only snippets** — output to stdout for manual copy-paste into PRs. Never auto-apply.
- **NEVER recommend disabling rules 200002/200003 for services that don't accept file uploads >128KB.** These rules provide legitimate request body inspection protection. Only recommend disabling for confirmed or strongly suspected upload services.
- **Flag uncertainty explicitly.** When upload exposure, WAF mode, or deployment state can't be determined from the repo, say so. Never guess or assume compliance.
- **Do not generate fix snippets for DEFERRED templates.** They're not deployed — the fix should happen when Front Door is enabled, not preemptively.
- **Respect the `ruleSetAction` / `mode` interaction.** In Detection mode, `ruleSetAction: 'Block'` is overridden to log-only. Don't misreport Detection-mode templates as actively blocking.


<!-- TODO: source — LENS-Common plugins/LENS/Security/lens-waf-audit/skills/waf-audit (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. Tier 2 PR-time gate; read-only; NEVER auto-apply fix snippets. -->
