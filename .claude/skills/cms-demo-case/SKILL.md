---
name: cms-demo-case
description: Patch a CMS NPE case with cross-team demo-prep values (regionDataCenter, publishChannel, identifierHash) for TDFS / LEAPI / LRMS demos. Runs an ACI inside the NPE VNet under the API UAMI; uses the CMS API for DataCategory/TargetIdentifier PATCHes plus a Cosmos direct PATCH for the server-managed identifierHash field.
allowed-tools: Bash, Read, Edit, Grep, Glob, Task
tier-exempt: [templates, multi-pass]
---

# CMS Demo Case Skill

Patch a single LNS case in NPE CMS with the demo-prep field set the downstream consumers (TDFS, LEAPI, LRMS) need to exercise their flows. One ACI deployment per case, ~25-30s wall-clock. Idempotent — re-running with the same args is safe.

## Usage

```
/cms-demo-case LNS-1778014194-AR3RSD26                   # full live PATCH
/cms-demo-case LNS-1778022226-HQ19D0NS                   # next case
/cms-demo-case LNS-... --dry-run                         # GET + diff, no mutation
```

Input is a single CaseId (LNS-... format). The skill auto-discovers everything else via the API + Cosmos lookup chain.

## What it sets

For the matched DFT (single DFT per case in this demo) and ALL its dataCategories:

| Field | Value | Path |
|---|---|---|
| `dataCategories[*].regionDataCenter` | `us` | API: `PATCH /api/v1/cases/{cid}/dfts/{ltid}/datacategories/{dcid}` |
| `dataCategories[*].publishChannel` | `leapi` | API: same (server translates to `deliveryChannel=Delivery`) |
| `dataCategories[*].startDateTime` | `2024-06-01T00:00:00Z` | API: same (no-op if already correct) |
| `dataCategories[*].endDateTime` | `2026-05-24T00:00:00Z` | API: same (no-op if already correct) |
| `targetIdentifier.identifierHash` | SHA-256 hex of `Identifier.Trim().ToLowerInvariant()` UTF-8 | **Cosmos direct PATCH** (API does not expose this field) |

DataCategory `deliveryJobId` and `publishJobId` are NOT touched — they're already populated when the case lands in NPE. Override only if explicitly requested.

## Workflow

### 1. Resolve the case

If the caller has a Case ID → straight to step 2.

If the caller only has an ETSI Task ID, find the Case ID first:

```bash
# Read the DftLookups container in NPE Cosmos to map etsiTaskId -> caseId.
# The DftLookups doc id format is `etsitaskid:{etsiTaskId}:{lensTaskId}`.
# Use Cosmos data plane (UAMI auth from ACI), audience https://cosmos.azure.com.
```

Reference: the working pattern is at `.mad/scratch/aci-find-dftlookup-20260505-221521/`.

### 2. Run the parameterized script

```powershell
pwsh -NoProfile -File .mad/scratch/aci-set-cms-demo-LNS-1778014194-AR3RSD26/Run-Aci.ps1 `
    -CaseId <LNS-id> `
    [-DryRun] `
    > .mad/reports/run-aci-<id>.log 2>&1
```

The script does 7 stages inside one ACI:
1. **GET case** — auth check, capture case ETag
2. **List DFTs** via `GET /api/v1/cases/{cid}/dfts?pageSize=25` → match by identifier value
3. **Print "Current values"** — pasteable diff context
4. **PATCH each DataCategory** — loops `dc_keys`, uses **DFT ETag** for If-Match (NOT case ETag)
5. **PATCH targetIdentifier** — known no-op (API drops `identifierHash` silently → 400 "no fields"); WARN-and-continue
6. **Re-GET DFTs** for verification → print "Final values"
7. **Cosmos direct PATCH** — sets `identifierHash` via `cosmos.azure.com` audience + `If-Match` (cosmos `_etag`)

### 3. Verify

The script's Stage 6 prints final values. For independent verification, re-run with `-DryRun` — Stage 3's "Current values" should now show `identifierHash` set + `regionDataCenter=us` + `publishChannel=leapi` on every dataCategory.

## Pitfalls (all encountered, all encoded in the script)

| Trap | What goes wrong | Fix |
|---|---|---|
| **Case ID format** | Source-typed copies often drop the trailing char (e.g. `AR3RSD2` vs `AR3RSD26`). Validator regex `^LNS-\d{10}-[A-Z0-9]{8}$` rejects with HTTP 400. | If unsure of the suffix: query DftLookups by ETSI task ID first. Don't brute-force. |
| **Tenant** | NPE CMS lives in **Torus** tenant `b1a4f7cb-...` (sub `d27c8315-...`). Workstation default is corp. | All `az` calls in the script pass `--subscription`; the script does NOT pass `--tenant` to `az container` subcommands (unsupported flag). |
| **API audience** | NPE CMS rejects user-delegated tokens because `api://6c5a00ce-...` isn't the deployed audience. | Inside the ACI, request `api://7f9733d9-66e1-4fa9-a177-bdd4a5bce24f` from IMDS — that's the API's own SP. Workstation cannot acquire this audience; ACI under UAMI is the only path. |
| **Case has NO embedded DFTs** | Stage 1 GET on `/api/v1/cases/{cid}` returns the case doc which does NOT include `dataFulfillmentTasks` array. | Use `GET /api/v1/cases/{cid}/dfts?pageSize=25` to list DFTs from the separate `Dfts` Cosmos container. |
| **DFT ETag, not Case ETag** | Sending case ETag in `If-Match` to a DFT PATCH endpoint returns HTTP 412 "DataFulfillmentTask precondition failed." | Stage 3.5: `GET /api/v1/cases/{cid}/dfts/{ltid}` to capture the DFT's ETag header. |
| **identifierType mismatch across cases** | One case stores `identifierType=email`, another stores `upn`, both with same `targetIdentifierValue`. Hardcoded type in match query causes NO_MATCH. | Stage 2 matches on identifier VALUE only; type is informational, not a match key. |
| **`PatchTargetIdentifierRequest` does not expose `identifierHash`** | Server returns 400 "At least one field must be provided" because it silently drops unknown fields. | Stage 5 treats 400-with-this-message as WARN (no-op), continues. Stage 7 sets the hash via Cosmos direct PATCH using the same UAMI. |
| **Cosmos data plane audience** | Cosmos REST does NOT accept the API audience token. | Acquire a SECOND IMDS token for `https://cosmos.azure.com`. Use header `Authorization: type=aad&ver=1.0&sig=<URL-encoded-token>`. |
| **Cosmos doc id has `dft:` prefix** | Doc id is `dft:{lensTaskId}` not bare `lensTaskId`. Partition key is `caseId` (NOT the doc id). | Stage 7 URL-encodes the colon, sends `x-ms-documentdb-partitionkey: ["{caseId}"]`. |
| **`az container show --tenant` is unsupported** | Polling silently fails (exit 2) when `--tenant` is on the command line; `2>$null` swallows the error; loop spins until MaxPollSeconds. | Run-Aci.ps1 polling block omits `--tenant` from container subcommands. Subscription is enough. |
| **ARM body race on parallel runs** | Both pwsh invocations writing `arm-body.json` to the same scratch dir clobber each other → ACI runs the wrong CASE_ID. | Filename is `arm-body-{caseSuffix}.json`. Container name is `aci-set-cms-demo-{caseSuffix}-live`. Safe to run two cases in parallel. |
| **awk not in azure-cli image** | `awk` is not installed in `mcr.microsoft.com/azure-cli:latest`. | Use `cut`, `sed`, or python3 (which IS in the image). |
| **`set -uo pipefail` + missing env var** | Container exits with bash error before any useful diagnostic. | Every required env var is passed by the orchestrator (CLIENT_ID, RESOURCE, BASE_URL, CASE_ID, IDENTIFIER, IDENTIFIER_TYPE, START_DATE_ISO, END_DATE_ISO, PUBLISH_CHANNEL, REGION_DATA_CENTER, REGION_STRING, DELIVERY_JOB_ID, PUBLISH_JOB_ID, TARGET_HASH, COSMOS_ENDPOINT, COSMOS_DB, COSMOS_CONTAINER, DRY_RUN). |
| **PIM decay mid-session** | Workstation `Microsoft.ContainerInstance/containerGroups/write` permission expires. ACI deploys 403. | Baseline RBAC at session start. Asymmetric denials (create works, delete doesn't on same scope) signal PIM is decaying — surface to user, don't keep retrying. See `memory/feedback_pim_decay_baseline_first.md`. |

## Critical files

| Path | Role |
|---|---|
| `.mad/scratch/aci-set-cms-demo-LNS-1778014194-AR3RSD26/Run-Aci.ps1` | Orchestrator — deploys ACI, polls, captures logs, tears down |
| `.mad/scratch/aci-set-cms-demo-LNS-1778014194-AR3RSD26/aci-script.sh` | In-container payload — Stages 1-7 |
| `.mad/scratch/aci-set-cms-demo-LNS-1778014194-AR3RSD26/arm-body-{caseSuffix}.json` | Per-case ARM body (auto-generated) |
| `references/LENS-CMS/sources/dev/CMS/src/API/Controllers/DftsController.cs` | API contract source — list, GET-by-id, PATCH datacategories, PATCH targetidentifier |
| `references/LENS-CMS/sources/dev/CMS/src/Common/Models/TargetIdentifier.cs:51-56` | Confirms `identifierHash` is server-managed (motivation for Stage 7) |
| `references/LENS-CMS/docs/design/cosmos-lookup-indexes.md:230-241` | Canonical `HashIdentifier` algorithm (SHA-256 of `Trim().ToLowerInvariant()` UTF-8 → bare lowercase hex) |

## Known constants

```
NPE Cosmos:        cosmos-lenscms-npe-westus3 (rg-lenscms-npe-westus3, sub d27c8315-...)
NPE API base:      https://app-lenscmsapi-npe-westus3.azurewebsites.net
NPE API audience:  api://7f9733d9-66e1-4fa9-a177-bdd4a5bce24f
Cosmos audience:   https://cosmos.azure.com
UAMI (ACI auth):   id-lenscmsapi-npe-westus3 (clientId caa023e0-..., principal 25cb7562-...)
UAMI Cosmos role:  bf88b6c7-... "CMS App ReadWrite - cms-rbac" at /dbs/CMS scope (items/* incl. patch)
ACI VNet:          vnet-lenscms-npe-westus3 / snet-aci-npe-westus3
Image:             mcr.microsoft.com/azure-cli:latest (has python3, curl; no awk/jq)
Tenant (NPE):      Torus b1a4f7cb-a159-44a6-ac48-6674e85c4ddc
```

## Best Practices

- **READ BEFORE EDIT**: open `Run-Aci.ps1` AND `aci-script.sh` together before changing either; the env-var contract spans them.
- **DRY-RUN FIRST**: `-DryRun` runs Stages 1-3 only (read-only) and exits before any mutation. Always confirm Stage 2 finds the right DFT before running live.
- **SINGLE-RESPONSIBILITY STAGES**: Stage 4 = API DC patch. Stage 5 = API TI patch (no-op for hash). Stage 6 = read-back. Stage 7 = Cosmos direct hash. Don't merge them; the audience+etag boundaries differ.
- **NO `| tail -N` on launch**: redirects to a log file with `> file 2>&1` instead. `| tail` buffers until pwsh exits → looks frozen for minutes.
- **PIM check at session start**: `az role assignment list --assignee <self-id> --subscription d27c8315-...` before any ACI-create work. Asymmetric write/delete denial = PIM decay; halt and surface.
- **Re-run is idempotent**: PATCH bodies match canonical values; Stage 7 PATCH on an already-set hash is a no-op replace. Safe to re-run.

## Standards

This skill inherits these load-bearing rules:
- `.claude/rules/non-negotiable-rules.md` — verb-bound permission fences
- `.claude/rules/verification-protocol.md` — FETCH BEFORE CITE, ACTUAL BEFORE PRESENT
- `.claude/rules/orchestration.md` — main coordinates, agents work
- `.claude/rules/skill-standards.md` — this skill's compliance contract
- Memory `feedback_pim_decay_baseline_first.md` — PIM TTL discipline for ACI work
- Memory `reference_two_tenants_in_use.md` — corp/Torus tenant routing

## Out of scope

- **Multi-DFT cases**: assumes one DFT per case (matches the demo brief). If a case has multiple DFTs matching the same identifier, Stage 2 returns AMBIGUOUS and exits — caller must disambiguate.
- **Cross-region cases**: hardcoded to westus3 NPE.
- **Production rings**: PROD safety guards in seed scripts deliberately reject; this skill does NOT touch prod.
- **DeliveryJobId / PublishJobId override**: existing values are preserved. To force-override, edit Run-Aci.ps1 to compute new GUIDs and add them to the DC PATCH body.
