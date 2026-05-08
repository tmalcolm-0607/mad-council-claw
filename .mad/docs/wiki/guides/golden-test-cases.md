# Golden Test Cases - Case Management Example

Reference document for fully-populated test cases. Use these as templates when seeding data or validating the data model.

---

## Data Model Overview

```
Case (Cosmos: Cases container, PK: /caseId)
  |-- NDOs[]              (embedded in Case)
  |     |-- Extensions[]  (embedded in NDO)
  |-- EscalationWorkItems[] (embedded)
  |-- FulfillmentSummary    (embedded rollup)
  |
  +-- DFTs[]             (Cosmos: Dfts container, PK: /caseId)
  |     |-- TargetIdentifier  (embedded 1:1)
  |     |-- DataCategories{}  (embedded dict, 1:N)
  |
  +-- Notes[]            (Cosmos: Notes container, PK: /caseId, immutable)
  +-- Communications[]   (Cosmos: Communications container, PK: /caseId)
  +-- Events[]           (Cosmos: Events container, PK: /caseId)
  +-- Attachments[]      (Cosmos: Attachments container, PK: /caseId)
```

---

## Cosmos Containers

| Container | PK | Entity Types |
|-----------|-----|-------------|
| Cases | `/caseId` | Case (type: "case") |
| Dfts | `/caseId` | DataFulfillmentTask (type: "dft") |
| Notes | `/caseId` | Note (type: "note") |
| Communications | `/caseId` | Communication |
| Events | `/caseId` | CaseEvent |
| Attachments | `/caseId` | Attachment |
| Aggregates | `/aggregateType` | AggregateSnapshot |
| Agencies | `/agencyId` | Agency |
| CaseLookups | hierarchical | CaseLookupEntry |
| DftLookups | hierarchical | DFT lookup data |
| NdoLookups | hierarchical | NDO lookup data |
| ReferenceLookups | `/pk` | RelatedIdentifier |
| IdempotencyKeys | `/requestId` | IdempotencyRecord |
| DeadLetters | `/pk` | DeadLetterDocument |
| leases | `/id` | Change Feed checkpoints |

---

## Golden Case 1: Multi-Service Court Order (Most Complete)

This case has everything populated across all entity types.

### Case

```json
{
  "requestType": "CourtOrder",
  "requestSubType": "ProductionOrder",
  "title": "[GOLDEN] Multi-Service Court Order - Full Population",
  "description": "Court order from King County Superior Court requiring production of email content, Teams messages, OneDrive files, and subscriber information. CSAM investigation.",
  "priority": "Urgent",
  "jurisdiction": "US-WA",
  "country": "US",
  "leReferenceNumber": "KCSC-2026-CO-78901",
  "requestOrigin": "LEPortal",
  "agentFirstName": "Jennifer",
  "agentLastName": "Martinez",
  "agentEmail": "j.martinez@kingcounty.gov",
  "agentPhone": "+1-206-555-0142",
  "cpConcern": "Child exploitation material reported in Exchange mailbox",
  "isPreservationRequest": false,
  "isWAShieldLaw": true,
  "natureOfCrimes": ["ChildExploitation", "PossessionCSAM", "Distribution"],
  "originalReceivedDate": "2026-03-15T08:30:00Z",
  "additionalCaseInformation": "Related to ongoing investigation KCSO-2026-INV-445. Judge issued order on 2026-03-14. Production deadline: 30 days from service.",
  "caseDueDate": "2026-04-14T23:59:59Z",
  "services": ["Exchange", "Teams", "OneDrive", "AzureAD"]
}
```

**Post-creation PATCH** (JSON Patch RFC 6902, requires `If-Match` ETag):

```json
[
  {"op": "replace", "path": "/assigneeName", "value": "Sarah Chen"},
  {"op": "replace", "path": "/workflowStage", "value": "InReview"},
  {"op": "replace", "path": "/workflowState", "value": "Active"},
  {"op": "replace", "path": "/countryContactStatus", "value": "Contacted"},
  {"op": "replace", "path": "/leContactStatus", "value": "Responded"},
  {"op": "replace", "path": "/attorneyStatus", "value": "Reviewed"},
  {"op": "replace", "path": "/operationalStatus", "value": "InProgress"}
]
```

### DFT 1: Exchange (3 DataCategories)

```json
{
  "caseId": "<caseId>",
  "targetIdentifierValue": "john.doe@contoso.com",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {
      "categoryType": "Content",
      "service": "Exchange",
      "startDateTime": "2025-06-01T00:00:00Z",
      "endDateTime": "2026-03-14T23:59:59Z"
    },
    {
      "categoryType": "Metadata",
      "service": "Exchange",
      "startDateTime": "2025-06-01T00:00:00Z",
      "endDateTime": "2026-03-14T23:59:59Z"
    },
    {
      "categoryType": "basicSubscriberInfo",
      "service": "Exchange"
    }
  ]
}
```

**TargetIdentifier PATCH** (full CLASS lookup result):

```json
{
  "accountExists": true,
  "accountType": "Both",
  "accountStatus": "Active",
  "accountCreationDate": "2019-03-15T10:22:00Z",
  "consumerProvisioned": true,
  "consumerStorageLocation": "NA",
  "resolvedConsumerIdentifier": "0003BFFD12345678",
  "consumerAccounts": ["john.doe@outlook.com", "johndoe@hotmail.com"],
  "enterpriseProvisioned": true,
  "enterpriseStorageLocation": "NAM",
  "resolvedEnterpriseIdentifier": "john.doe@contoso.com",
  "enterpriseAccounts": ["john.doe@contoso.com", "jdoe@contoso.onmicrosoft.com"],
  "geoLocationMismatch": false,
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "externalDirectoryObjectId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "firstName": "John",
  "lastName": "Doe",
  "userGeoLocation": "US-WA",
  "classLookupTimestamp": "2026-03-16T09:15:00Z"
}
```

**DataCategory PATCHes** (one per DC, each requires fresh DFT ETag):

Content DC:
```json
{
  "dcsJobId": "dcs-job-exch-content-001",
  "dpsJobId": "dps-job-exch-content-001",
  "collectedSize": 524288000,
  "estimatedTotalSize": 1073741824,
  "estimatedCompletionTime": "2026-04-05T18:00:00Z",
  "regionDataCenter": "US-West-2",
  "regionCountryName": "United States",
  "region": "NAM",
  "resolvedIdentifier": "0003BFFD12345678",
  "publishChannel": "LEPortal",
  "publishType": "Pull",
  "dataExists": true
}
```

Metadata DC:
```json
{
  "dcsJobId": "dcs-job-exch-meta-001",
  "dpsJobId": "dps-job-exch-meta-001",
  "collectedSize": 10485760,
  "estimatedTotalSize": 15728640,
  "regionDataCenter": "US-West-2",
  "regionCountryName": "United States",
  "region": "NAM",
  "publishChannel": "LEPortal",
  "publishType": "Pull",
  "dataExists": true
}
```

BSI DC:
```json
{
  "dcsJobId": "dcs-job-exch-bsi-001",
  "collectedSize": 2048,
  "estimatedTotalSize": 2048,
  "regionDataCenter": "US-West-2",
  "regionCountryName": "United States",
  "region": "NAM",
  "publishChannel": "LEPortal",
  "publishType": "Pull",
  "dataExists": true
}
```

### DFT 2: Teams Content

```json
{
  "caseId": "<caseId>",
  "targetIdentifierValue": "john.doe@contoso.com",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {
      "categoryType": "Content",
      "service": "Teams",
      "startDateTime": "2025-06-01T00:00:00Z",
      "endDateTime": "2026-03-14T23:59:59Z"
    }
  ]
}
```

### DFT 3: OneDrive Content

```json
{
  "caseId": "<caseId>",
  "targetIdentifierValue": "john.doe@contoso.com",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {
      "categoryType": "Content",
      "service": "OneDrive",
      "startDateTime": "2025-06-01T00:00:00Z",
      "endDateTime": "2026-03-14T23:59:59Z"
    }
  ]
}
```

### NDO (with Extension)

Create NDO:
```json
{
  "userNotificationAllowed": false,
  "ndoAttached": true,
  "temporaryNdo": false,
  "exclusionReason": "CourtOrder",
  "ndoStartDate": "2026-03-15T00:00:00Z",
  "ndoExpirationDate": "2026-09-15T23:59:59Z"
}
```

NDO Extension:
```json
{
  "newExpirationDate": "2027-03-15T23:59:59Z",
  "submittedBy": "Sarah Chen",
  "primaryContact": "j.martinez@kingcounty.gov",
  "extensionDuration": "6 months",
  "justification": "Investigation ongoing - additional evidence discovered requiring extended non-disclosure period"
}
```

NDO PATCH (LE notification workflow):
```json
{
  "leNotificationDate": "2026-03-20T10:00:00Z",
  "leResponseDueDate": "2026-04-03T23:59:59Z",
  "leResponseReceived": true,
  "leResponseDate": "2026-03-25T14:30:00Z"
}
```

### Notes (6 types)

```json
[
  {"noteType": "General", "content": "Case received via LEPortal. Court order KCSC-2026-CO-78901 served electronically.", "isInternal": false},
  {"noteType": "Triage", "content": "Multi-service scope (Exchange, Teams, OneDrive). Target has both consumer and enterprise accounts.", "isInternal": true},
  {"noteType": "Attorney", "content": "Legal review complete. WA Shield Law applies. Court order scope valid for all requested data categories.", "isInternal": true},
  {"noteType": "Fulfillment", "content": "Exchange content collection initiated. Estimated 1GB total, 500MB collected so far.", "isInternal": true},
  {"noteType": "Escalation", "content": "Escalated to Senior Analyst due to CSAM flag and multi-service complexity.", "isInternal": true},
  {"noteType": "General", "content": "LE agent confirmed data format is acceptable. Full production to follow.", "isInternal": false}
]
```

### Communications (4)

```json
[
  {"direction": "Outbound", "channel": "Portal", "communicationType": "LECorrespondence", "subject": "Acknowledgment of Receipt", "body": "..."},
  {"direction": "Inbound", "channel": "Portal", "communicationType": "LECorrespondence", "subject": "Clarification on Date Range", "body": "..."},
  {"direction": "Outbound", "channel": "Portal", "communicationType": "LECorrespondence", "subject": "Date Range Confirmed", "body": "..."},
  {"direction": "Outbound", "channel": "Portal", "communicationType": "UserNotification", "subject": "Data Production Status Update", "body": "..."}
]
```

### Events (5)

```json
[
  {"eventType": "NoteAdded", "details": {"context": "Initial triage assessment completed"}},
  {"eventType": "NoteAdded", "details": {"context": "Legal review completed"}},
  {"eventType": "NoteAdded", "details": {"context": "Escalation: CSAM flag triggered senior analyst assignment"}},
  {"eventType": "NoteAdded", "details": {"context": "Exchange collection initiated"}},
  {"eventType": "NoteAdded", "details": {"context": "BSI data collection completed"}}
]
```

**Note**: Only `NoteAdded` is in the ExplicitlyCreatableTypes whitelist. Other event types (StageChange, Assignment, etc.) are system-generated and return 400.

---

## Golden Case 2: International Emergency (Minimal DFTs, Focus on Case Fields)

```json
{
  "requestType": "EmergencyLetter",
  "title": "[GOLDEN] International Emergency - Imminent Threat",
  "description": "Emergency disclosure request from German BKA involving imminent threat to life. Requires immediate preservation and expedited production.",
  "priority": "Emergency",
  "jurisdiction": "DE",
  "country": "DE",
  "leReferenceNumber": "BKA-2026-EM-0087",
  "requestOrigin": "LEPortal",
  "agentFirstName": "Hans",
  "agentLastName": "Mueller",
  "agentEmail": "h.mueller@bka.bund.de",
  "agentPhone": "+49-30-555-0199",
  "cpConcern": null,
  "isPreservationRequest": true,
  "isWAShieldLaw": false,
  "natureOfCrimes": ["Terrorism", "ImminentThreatToLife"],
  "originalReceivedDate": "2026-04-01T06:00:00Z",
  "additionalCaseInformation": "Time-critical emergency. Subject is believed to be planning an attack within 48 hours. All available data for target email needed immediately.",
  "caseDueDate": "2026-04-03T06:00:00Z",
  "services": ["Exchange", "Teams"],
  "internationalJurisdiction": "DE-BE",
  "urgencyLevel": "Critical"
}
```

Single DFT:
```json
{
  "targetIdentifierValue": "suspect@example.de",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {"categoryType": "Content", "service": "Exchange", "startDateTime": "2026-01-01T00:00:00Z", "endDateTime": "2026-04-01T06:00:00Z"},
    {"categoryType": "Content", "service": "Teams", "startDateTime": "2026-01-01T00:00:00Z", "endDateTime": "2026-04-01T06:00:00Z"}
  ]
}
```

---

## Golden Case 3: NSL with Preservation (Restricted Scope)

```json
{
  "requestType": "NSL",
  "title": "[GOLDEN] National Security Letter - Counterintelligence",
  "description": "National Security Letter requiring subscriber and transactional data. Gag order attached.",
  "priority": "Urgent",
  "jurisdiction": "US-FED",
  "country": "US",
  "leReferenceNumber": "FBI-2026-NSL-0178",
  "requestOrigin": "LEPortal",
  "agentFirstName": "Robert",
  "agentLastName": "Chen",
  "agentEmail": "r.chen@fbi.gov",
  "isPreservationRequest": true,
  "natureOfCrimes": ["NationalSecurity", "Espionage"],
  "originalReceivedDate": "2026-03-20T14:00:00Z",
  "caseDueDate": "2026-06-20T23:59:59Z"
}
```

DFT (BSI + service telemetry only, no content for NSL):
```json
{
  "targetIdentifierValue": "target@organization.com",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {"categoryType": "basicSubscriberInfo", "service": "Exchange"},
    {"categoryType": "serviceTelemetry", "service": "Exchange", "startDateTime": "2025-09-01T00:00:00Z", "endDateTime": "2026-03-20T23:59:59Z"},
    {"categoryType": "trafficData", "service": "Exchange", "startDateTime": "2025-09-01T00:00:00Z", "endDateTime": "2026-03-20T23:59:59Z"}
  ]
}
```

NDO (permanent gag order):
```json
{
  "userNotificationAllowed": false,
  "ndoAttached": true,
  "temporaryNdo": false,
  "exclusionReason": "NationalSecurityLetter",
  "ndoStartDate": "2026-03-20T00:00:00Z",
  "ndoExpirationDate": "2099-12-31T23:59:59Z"
}
```

---

## Golden Case 4: SMS Routing Validation (All 6 Fields)

Designed for SMS `/api/v1/cases/validate` endpoint testing. All routing fields populated.

```json
{
  "requestType": "SubpoenaSummons",
  "title": "[GOLDEN] SMS Routing - Full Validation",
  "description": "Case with all 6 SMS routing fields populated for validate endpoint testing.",
  "priority": "Standard",
  "jurisdiction": "US-WA",
  "country": "US"
}
```

DFT:
```json
{
  "targetIdentifierValue": "routing-test@contoso.com",
  "identifierType": "Email",
  "scenario": "LegalDemand",
  "dataCategories": [
    {"categoryType": "Content", "service": "Exchange", "startDateTime": "2026-01-01T00:00:00Z", "endDateTime": "2026-12-31T00:00:00Z"}
  ]
}
```

TargetIdentifier PATCH: `{"consumerStorageLocation": "NA"}`
DataCategory PATCH: `{"publishChannel": "LEPortal"}`

Expected validation response:
```json
{
  "isValid": true,
  "identifier": "routing-test@contoso.com",
  "lawfulRequestType": "SubpoenaSummons",
  "dataCategory": "Content",
  "storageRegion": "NA",
  "workload": "Exchange",
  "deliveryChannel": "LEPortal"
}
```

---

## Enum Values Reference

### requestType (PascalCase)
`SubpoenaSummons`, `CourtOrder`, `SearchWarrant`, `Preservation`, `EmergencyLetter`, `NSL`, `ConsentRelease`, `IREQ`, `InternationalOrder`

### scenario
`LegalDemand`, `LegalIntercept`, `LegalPreservation`

### service
`Exchange`, `Teams`, `OneDrive`, `SharePoint`, `AzureAD`, `Skype`

### categoryType
`Content`, `Metadata`, `basicSubscriberInfo`, `trafficData`, `AuthenticationLogs`, `serviceTelemetry`

### publishChannel
`LEPortal`, `LEAPI`

### noteType
`General`, `Triage`, `Fulfillment`, `Attorney`, `Escalation`

### communicationType
`LECorrespondence`, `RedirectNotice`, `UserNotification`, `RejectionNotice`

### direction
`Inbound`, `Outbound`

### channel
`Portal`, `Email`, `Phone`

### eventType (creatable via API)
`NoteAdded` (only type in ExplicitlyCreatableTypes whitelist)

### exclusionReason (NDO)
`CourtOrder`, `NationalSecurityLetter`, `Other`

### CaseStatus
Created, InReview, Triaged, Active, Resolved, Cancelled

### DftLifecycleStatus
Created, Submitted, InProgress, Completed, Cancelled

### ProcessingStatus (DataCategory states)
collectionState, publishState, deliveryState - state machine values

---

## API Authentication

### Resource URI
`api://6c5a00ce-8062-49d8-b568-b9bd0363340b`

### Token Acquisition (local testing - user tokens, rejected by MISE v2 in production config)
```bash
az account get-access-token --resource "api://6c5a00ce-8062-49d8-b568-b9bd0363340b" --query accessToken -o tsv
```

### Token Acquisition (ACI with Managed Identity - recommended)
```bash
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=api://6c5a00ce-8062-49d8-b568-b9bd0363340b&client_id=<MI_CLIENT_ID>"
```

### Required Headers
| Header | Required | Value |
|--------|----------|-------|
| Authorization | All endpoints except /health | `Bearer <token>` |
| Content-Type | POST/PATCH | `application/json` |
| X-Idempotency-Key | POST/PUT | UUID |
| If-Match | PATCH | ETag from GET response |

### App Roles
| Role | Access |
|------|--------|
| CMS.CaseReader | GET endpoints |
| CMS.CaseWriter | POST/PATCH/DELETE endpoints |
| CMS.SystemIntegration | All (superuser) - includes /validate |

---

## Seeding Workflow

### Step-by-step (11 API calls for Golden Case 1)

1. `POST /api/v1/cases` - Create case (returns caseId + ETag)
2. `PATCH /api/v1/cases/{caseId}` - Add assignee, workflow, review statuses
3. `POST /api/v1/cases/{caseId}/dfts` - Create DFT #1 (Exchange, 3 DCs)
4. `PATCH .../dfts/{lensTaskId}/targetidentifier` - Full CLASS lookup
5. `PATCH .../dfts/{lensTaskId}/datacategories/{dcId}` - Content DC
6. `PATCH .../dfts/{lensTaskId}/datacategories/{dcId}` - Metadata DC
7. `PATCH .../dfts/{lensTaskId}/datacategories/{dcId}` - BSI DC
8. `POST /api/v1/cases/{caseId}/dfts` - Create DFT #2 (Teams)
9. `POST /api/v1/cases/{caseId}/dfts` - Create DFT #3 (OneDrive)
10. `POST /api/v1/cases/{caseId}/ndos` - Create NDO
11. `POST .../ndos/{ndoId}/extensions` - Create extension
12. `POST /api/v1/cases/{caseId}/notes` x6 - Create notes
13. `POST /api/v1/cases/{caseId}/communications` x4 - Create comms
14. `POST /api/v1/cases/{caseId}/events` x5 - Create events
15. `POST /api/v1/cases/validate` - Validate (SMS routing check)

### ETag Discipline
- Every PATCH requires `If-Match: <etag>` header
- GET the resource to get a fresh ETag before each PATCH
- DFT-level ETag is used for DataCategory and TargetIdentifier PATCHes
- Returns 428 if `If-Match` header missing, 412 if ETag mismatch

---

## Seed Script

Automated seeder: `.claude/scripts/Seed-FullCase.ps1`

```powershell
# Run via ACI (recommended - handles MISE app-only token requirement)
powershell.exe -NoProfile -File .claude/scripts/Seed-FullCase.ps1 -Environment <test-env>
powershell.exe -NoProfile -File .claude/scripts/Seed-FullCase.ps1 -Environment <dev-env> -SkipCleanup
```

---

## Known Issues (example)

| Environment | Issue | Impact |
|-------------|-------|--------|
| shared test env | All MISE ClaimsOnlyAuthZ policies are `LogOnly` with `AuditMode=false` | All API calls return 401 (default deny) |
| personal dev env | MISE startup crash: `'Application' is not a known IdentityRelationship` | App returns HTTP 500 on all endpoints |

**Fix for shared test env**: Change `Mise__ClaimsOnlyAuthZ__AuditMode` to `true` on the App Service, OR change the relevant "AllowlistedCallers" policy enforcement to `Enforce`.

**Fix for personal dev env**: Update MISE config to remove/rename `Application` IdentityRelationship value. Likely needs MISE version update or config migration.
