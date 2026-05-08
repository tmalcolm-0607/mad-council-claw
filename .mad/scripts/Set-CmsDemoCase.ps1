<#
.SYNOPSIS
    Demo-prep PATCH for a CMS NPE case + nested DFT/DataCategoryRecord.

.DESCRIPTION
    Recurring demo-prep task: cross-team demos (TDFS / LEAPI / LRMS) require an
    existing CMS case in NPE seeded with specific tenant + identifier + demand
    window + channel + datacenter + job-id values so downstream consumers can
    exercise their flows.

    Flow:
      1. Acquire token (az -- corp tenant for ADO ops, Torus tenant for NPE -- see
         memory `reference_two_tenants_in_use.md`; this script targets NPE so the
         active az login should be the Torus tenant).
      2. GET case -> capture ETag + parse JSON.
      3. Locate the matching DFT (by Identifier + IdentifierType, case-insensitive).
      4. Print "Current values" block (every targeted field with current value or <unset>).
      5. Build a JSON Patch (RFC 6902 replace ops only) with one op per *differing* field.
      6. If diff is empty -> "No changes needed" + exit 0.
      7. -DryRun -> print the patch + exit 0 (no live PATCH).
      8. Else PATCH with If-Match. 428 -> bail; 412 -> re-GET + retry once.
      9. Re-GET + print "Final values" block.

    IdentifierHash: computed locally per the canonical CMS algorithm
    (`docs/design/cosmos-lookup-indexes.md:236-240` -- `Trim().ToLowerInvariant()`
    UTF-8 SHA-256 -> 64-char lowercase hex). NOT prefixed with "sha256:". The
    LENS-Common test fixtures use mock strings like "sha256-abc123" -- those are
    placeholders, not the real format. -IdentifierHashOverride is the escape hatch
    if the live case carries a non-canonical hash.

.PARAMETER Environment
    NPE ring slug. Default 'npe'. Resolves to https://app-cms-{env}-westus3.azurewebsites.net.

.PARAMETER Tenant
    AAD tenant ID for the token request. Default is the Torus tenant
    (b1a4f7cb-a159-44a6-ac48-6674e85c4ddc) where NPE CMS lives per memory
    reference_two_tenants_in_use.md. Passed via `az account get-access-token --tenant`
    -- this is a token request, NOT a login, so it does not disturb the default
    az session (which is typically the corp tenant for ADO ops).

.PARAMETER TenantId
    Required. Case top-level tenantId (the LENS customer tenant on the Case
    document, NOT the AAD tenant where the API lives).

.PARAMETER CaseId
    Required. Case ID to update (PATCH-only in v1; POST/create deferred).

.PARAMETER Identifier
    Required. Target identifier value (e.g. modAdmin@lensteams.onmicrosoft.com).
    Used both to locate the matching DFT and to compute IdentifierHash.

.PARAMETER IdentifierType
    Default 'UPN'. One of UPN | EmailAddress | ObjectId.

.PARAMETER DemandStartDate
    Required. DataCategoryRecord.StartDateTime.

.PARAMETER DemandEndDate
    Required. DataCategoryRecord.EndDateTime.

.PARAMETER PublishChannel
    Request DTO uses 'LEAPI' / 'LEPortal'. Server stores in DeliveryChannel:
    LEAPI -> Delivery, LEPortal -> LEPortal. We translate at script boundary.
    Default 'LEAPI'.

.PARAMETER RegionDataCenter
    DataCategoryRecord.RegionDataCenter (LENS-Common StorageRegion enum).
    Default 'US'.

.PARAMETER DeliveryJobId
    Optional Guid. If provided, sets DataCategoryRecord.deliveryJobId. LRMS doesn't
    pass deliveryId to publish today -- the demo seeds it directly.

.PARAMETER PublishJobId
    Optional Guid. Same shape, different field.

.PARAMETER IdentifierHashOverride
    Optional escape hatch -- forces a literal hash value instead of computing.

.PARAMETER DryRun
    Run GET + diff + print patch doc; do NOT send the live PATCH.

.EXAMPLE
    pwsh -NoProfile -File .mad/scripts/Set-CmsDemoCase.ps1 -DryRun `
        -Environment npe `
        -CaseId LNS-1778014194-AR3RSD2 `
        -TenantId c279a93d-695a-4c0d-aee4-de138bd4c0e1 `
        -Identifier modAdmin@lensteams.onmicrosoft.com `
        -IdentifierType UPN `
        -DemandStartDate 2024-06-01T00:00:00Z `
        -DemandEndDate   2026-05-24T00:00:00Z `
        -PublishChannel  LEAPI `
        -RegionDataCenter US

.NOTES
    Exit codes:
      0 success (or -DryRun completed, or no changes needed)
      1 args/setup error (token, base URL, params)
      2 GET failed (4xx/5xx, or network)
      3 ambiguous DFT match (>1 DFT matches Identifier + IdentifierType)
      4 PATCH failed (4xx/5xx not handled by the etag-retry path)
      5 hash compute failed (should not happen unless override produces invalid input)
#>
[CmdletBinding()]
param(
    [ValidateSet('npe','npe2','npe3','npe4','npe5','npe6')]
    [string]$Environment = 'npe',

    # Torus tenant -- NPE CMS API resource lives here per memory
    # reference_two_tenants_in_use.md. Token request only; no login side-effect.
    [string]$Tenant = 'b1a4f7cb-a159-44a6-ac48-6674e85c4ddc',

    [Parameter(Mandatory)]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [string]$CaseId,

    [Parameter(Mandatory)]
    [string]$Identifier,

    [ValidateSet('UPN','EmailAddress','ObjectId')]
    [string]$IdentifierType = 'UPN',

    [Parameter(Mandatory)]
    [datetime]$DemandStartDate,

    [Parameter(Mandatory)]
    [datetime]$DemandEndDate,

    [ValidateSet('LEAPI','LEPortal')]
    [string]$PublishChannel = 'LEAPI',

    [string]$RegionDataCenter = 'US',

    [string]$DeliveryJobId,

    [string]$PublishJobId,

    [string]$IdentifierHashOverride,

    [switch]$DryRun
)

$env:MSYS_NO_PATHCONV = '1'

$BaseUrl  = "https://app-cms-$Environment-westus3.azurewebsites.net"
$Resource = 'api://6c5a00ce-8062-49d8-b568-b9bd0363340b'

# DeliveryChannel server-side enum (LEAPI -> Delivery is the canonical translation;
# DftMapper.cs:142-147 inverts it for response-time PublishChannel display)
$DeliveryChannelServer = if ($PublishChannel -eq 'LEAPI') { 'Delivery' } else { 'LEPortal' }

# ISO-8601 with trailing Z so the wire matches DateTimeOffset round-trip
$DemandStartIso = $DemandStartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$DemandEndIso   = $DemandEndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "--- $Title ---" -ForegroundColor Cyan
}

function Get-IdentifierHash {
    param([string]$Value)
    try {
        $normalized = $Value.Trim().ToLowerInvariant()
        $bytes      = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        $hashBytes  = [System.Security.Cryptography.SHA256]::HashData($bytes)
        ([System.Convert]::ToHexString($hashBytes)).ToLowerInvariant()
    } catch {
        Write-Host "ERROR: hash compute failed for '$Value': $_" -ForegroundColor Red
        exit 5
    }
}

function Format-Value {
    param($v)
    if ($null -eq $v -or ($v -is [string] -and [string]::IsNullOrWhiteSpace($v))) {
        return '<unset>'
    }
    if ($v -is [datetime] -or $v -is [datetimeoffset]) {
        return $v.ToString('o')
    }
    return [string]$v
}

function Get-AccessToken {
    Write-Section "Acquiring token from $Resource (tenant: $Tenant)"
    # Use 2>&1 + WARNING filter per .claude/rules/patterns/powershell-conventions.md.
    # --tenant pins the token request to Torus; this is a token request, NOT a login,
    # so the default az session (typically corp) is unaffected.
    $tokenJson = az account get-access-token --resource $Resource --tenant $Tenant 2>&1 |
        Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: az account get-access-token failed (exit $LASTEXITCODE):" -ForegroundColor Red
        Write-Host ($tokenJson -join "`n")
        Write-Host '' -ForegroundColor Red
        Write-Host "Hint: confirm Torus credentials are cached for tenant $Tenant" -ForegroundColor Yellow
        Write-Host '      (run `az account list` -- if Torus subscription is missing,' -ForegroundColor Yellow
        Write-Host '      use `az login --tenant ' "$Tenant" '` once to seed the cache).' -ForegroundColor Yellow
        exit 1
    }
    $token = ($tokenJson | ConvertFrom-Json).accessToken
    if (-not $token) {
        Write-Host 'ERROR: token JSON missing accessToken' -ForegroundColor Red
        exit 1
    }
    return $token
}

function Get-CaseAndEtag {
    param([string]$Token)
    $url = "$BaseUrl/api/v1/cases/$CaseId"
    Write-Section "GET $url"

    $resp = $null
    $statusCode = 0
    try {
        # Use Invoke-WebRequest so we can pull headers (ETag) — Invoke-RestMethod
        # surfaces only the body
        $resp = Invoke-WebRequest -Method Get -Uri $url `
            -Headers @{ Authorization = "Bearer $Token" } `
            -UseBasicParsing -ErrorAction Stop
        $statusCode = [int]$resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $body = ''
            try { $body = $_.Exception.Response.Content.ReadAsStringAsync().Result } catch { }
            Write-Host "ERROR: GET returned HTTP $statusCode" -ForegroundColor Red
            if ($body) { Write-Host "  Body: $body" -ForegroundColor Red }
        } else {
            Write-Host "ERROR: GET failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        exit 2
    }

    $etag = $resp.Headers['ETag']
    if ($etag -is [array]) { $etag = $etag[0] }
    $caseJson = $resp.Content | ConvertFrom-Json
    Write-Host "  HTTP $statusCode  ETag: $etag" -ForegroundColor Green
    return [pscustomobject]@{ Case = $caseJson; ETag = $etag }
}

function Find-MatchingDft {
    param($Case)
    if (-not $Case.dataFulfillmentTasks -or $Case.dataFulfillmentTasks.Count -eq 0) {
        Write-Host "ERROR: case has no dataFulfillmentTasks" -ForegroundColor Red
        exit 3
    }

    $matches = @()
    for ($i = 0; $i -lt $Case.dataFulfillmentTasks.Count; $i++) {
        $dft = $Case.dataFulfillmentTasks[$i]
        $ti  = $dft.targetIdentifier
        if ($null -eq $ti) { continue }

        $valMatch  = ($ti.targetIdentifierValue -and `
                       ($ti.targetIdentifierValue.ToLowerInvariant() -eq $Identifier.ToLowerInvariant()))
        # IdentifierType serializes as string via JsonStringEnumConverter
        $typeMatch = ($ti.identifierType -and `
                       ($ti.identifierType.ToString().ToLowerInvariant() -eq $IdentifierType.ToLowerInvariant()))

        if ($valMatch -and $typeMatch) {
            $matches += [pscustomobject]@{ Index = $i; Dft = $dft }
        }
    }

    if ($matches.Count -eq 0) {
        Write-Host "ERROR: no DFT matches Identifier='$Identifier' + IdentifierType='$IdentifierType'" -ForegroundColor Red
        Write-Host "  Available DFTs:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Case.dataFulfillmentTasks.Count; $i++) {
            $ti = $Case.dataFulfillmentTasks[$i].targetIdentifier
            $val = if ($ti) { $ti.targetIdentifierValue } else { '<no targetIdentifier>' }
            $typ = if ($ti) { $ti.identifierType } else { '<no targetIdentifier>' }
            Write-Host "    [$i] lensTaskId=$($Case.dataFulfillmentTasks[$i].lensTaskId) value='$val' type='$typ'"
        }
        exit 3
    }
    if ($matches.Count -gt 1) {
        Write-Host "ERROR: ambiguous DFT match -- $($matches.Count) DFTs match Identifier='$Identifier' + IdentifierType='$IdentifierType':" -ForegroundColor Red
        foreach ($m in $matches) {
            Write-Host "    [$($m.Index)] lensTaskId=$($m.Dft.lensTaskId)"
        }
        exit 3
    }
    return $matches[0]
}

function Get-FirstCategoryKey {
    param($Dft)
    if (-not $Dft.dataCategories) {
        Write-Host "ERROR: DFT has no dataCategories dictionary" -ForegroundColor Red
        exit 3
    }
    # dataCategories is a Dictionary<string, DataCategoryRecord> — JSON object.
    # Get the first (and in v1, only-supported) key.
    $names = @($Dft.dataCategories.PSObject.Properties.Name)
    if ($names.Count -eq 0) {
        Write-Host "ERROR: DFT.dataCategories is empty" -ForegroundColor Red
        exit 3
    }
    if ($names.Count -gt 1) {
        Write-Host "WARN: DFT has $($names.Count) data categories; v1 targets the first ($($names[0]))" -ForegroundColor Yellow
        Write-Host "      Other category IDs: $($names[1..($names.Count-1)] -join ', ')" -ForegroundColor Yellow
    }
    return $names[0]
}

function New-PatchOp {
    param([string]$Path, $Value)
    [pscustomobject]@{ op = 'replace'; path = $Path; value = $Value }
}

function Test-EqualValue {
    param($Current, $Target)
    if ($null -eq $Current -and $null -eq $Target)         { return $true }
    if ($null -eq $Current -or  $null -eq $Target)         { return $false }
    # Normalize datetime/string comparisons: parse both as DateTimeOffset when one is datetime-shaped
    if ($Target -is [string] -and $Target -match '^\d{4}-\d{2}-\d{2}T') {
        try {
            $cParsed = [datetimeoffset]::Parse($Current)
            $tParsed = [datetimeoffset]::Parse($Target)
            return ($cParsed -eq $tParsed)
        } catch { }
    }
    return ([string]$Current -eq [string]$Target)
}

function Send-PatchAndReget {
    param([string]$Token, [object[]]$PatchOps, [string]$ETag)
    $url = "$BaseUrl/api/v1/cases/$CaseId"
    $body = ConvertTo-Json -InputObject $PatchOps -Depth 6 -Compress

    Write-Section "PATCH $url  (If-Match: $ETag)"

    try {
        $resp = Invoke-WebRequest -Method Patch -Uri $url `
            -Headers @{
                Authorization = "Bearer $Token"
                'If-Match'    = $ETag
                'Content-Type'= 'application/json'
            } `
            -Body $body -UseBasicParsing -ErrorAction Stop
        Write-Host "  HTTP $([int]$resp.StatusCode)  new ETag: $($resp.Headers['ETag'])" -ForegroundColor Green
        return [pscustomobject]@{
            StatusCode = [int]$resp.StatusCode
            Case       = $resp.Content | ConvertFrom-Json
            ETag       = $resp.Headers['ETag']
        }
    } catch {
        $statusCode = 0
        $body = ''
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try { $body = $_.Exception.Response.Content.ReadAsStringAsync().Result } catch { }
        }
        return [pscustomobject]@{
            StatusCode = $statusCode
            ErrorBody  = $body
            Exception  = $_.Exception.Message
        }
    }
}

# =============================================================================
# Main
# =============================================================================

Write-Host ''
Write-Host '=== Set-CmsDemoCase (PATCH-only) ===' -ForegroundColor Cyan
Write-Host "Environment:  $Environment   ($BaseUrl)"
Write-Host "CaseId:       $CaseId"
Write-Host "TenantId:     $TenantId"
Write-Host "Identifier:   $Identifier  ($IdentifierType)"
Write-Host "Demand:       $DemandStartIso  ->  $DemandEndIso"
Write-Host "Channel:      $PublishChannel  -> server DeliveryChannel='$DeliveryChannelServer'"
Write-Host "Region:       $RegionDataCenter"
if ($DeliveryJobId) { Write-Host "DeliveryJobId: $DeliveryJobId" }
if ($PublishJobId)  { Write-Host "PublishJobId:  $PublishJobId"  }
if ($DryRun)        { Write-Host 'Mode:         -DryRun (no live PATCH)' -ForegroundColor Yellow }

# Compute target IdentifierHash (override wins)
$TargetIdentifierHash =
    if ($IdentifierHashOverride) { $IdentifierHashOverride }
    else                          { Get-IdentifierHash -Value $Identifier }
Write-Host "Target hash:  $TargetIdentifierHash"

# Auth + GET
$token  = Get-AccessToken
$caseAndEtag = Get-CaseAndEtag -Token $token
$caseJson = $caseAndEtag.Case
$etag     = $caseAndEtag.ETag

# Locate DFT + first DataCategoryRecord
$match = Find-MatchingDft -Case $caseJson
$dftIndex = $match.Index
$dft      = $match.Dft
$catKey   = Get-FirstCategoryKey -Dft $dft
$dc       = $dft.dataCategories.$catKey

# Snapshot current values
$current = [ordered]@{
    'TenantId'                       = $caseJson.tenantId
    "DFT[$dftIndex].targetIdentifier.identifierHash" = $dft.targetIdentifier.identifierHash
    "DC[$catKey].startDateTime"      = $dc.startDateTime
    "DC[$catKey].endDateTime"        = $dc.endDateTime
    "DC[$catKey].deliveryChannel"    = $dc.deliveryChannel
    "DC[$catKey].regionDataCenter"   = $dc.regionDataCenter
    "DC[$catKey].deliveryJobId"      = $dc.deliveryJobId
    "DC[$catKey].publishJobId"       = $dc.publishJobId
}

Write-Section "Current values (CaseId: $CaseId, ETag: $etag)"
foreach ($k in $current.Keys) {
    Write-Host ("  {0,-55} {1}" -f $k, (Format-Value $current[$k]))
}

# Build target map keyed by JSON-Patch path
$dcPath = "/dataFulfillmentTasks/$dftIndex/dataCategories/$catKey"
$tiPath = "/dataFulfillmentTasks/$dftIndex/targetIdentifier"
$targets = [ordered]@{
    '/tenantId'                       = @{ Current = $caseJson.tenantId;                                  Target = $TenantId;               Apply = $true }
    "$tiPath/identifierHash"          = @{ Current = $dft.targetIdentifier.identifierHash;                Target = $TargetIdentifierHash;   Apply = $true }
    "$dcPath/startDateTime"           = @{ Current = $dc.startDateTime;                                   Target = $DemandStartIso;         Apply = $true }
    "$dcPath/endDateTime"             = @{ Current = $dc.endDateTime;                                     Target = $DemandEndIso;           Apply = $true }
    "$dcPath/deliveryChannel"         = @{ Current = $dc.deliveryChannel;                                 Target = $DeliveryChannelServer;  Apply = $true }
    "$dcPath/regionDataCenter"        = @{ Current = $dc.regionDataCenter;                                Target = $RegionDataCenter;       Apply = $true }
    "$dcPath/deliveryJobId"           = @{ Current = $dc.deliveryJobId;                                   Target = $DeliveryJobId;          Apply = [bool]$DeliveryJobId }
    "$dcPath/publishJobId"            = @{ Current = $dc.publishJobId;                                    Target = $PublishJobId;           Apply = [bool]$PublishJobId  }
}

$patchOps = @()
$alreadyCurrent = @()
foreach ($path in $targets.Keys) {
    $t = $targets[$path]
    if (-not $t.Apply) { continue }
    if (Test-EqualValue -Current $t.Current -Target $t.Target) {
        $alreadyCurrent += $path
    } else {
        $patchOps += (New-PatchOp -Path $path -Value $t.Target)
    }
}

Write-Section "Patch ($($patchOps.Count) op(s); $($alreadyCurrent.Count) already current)"
if ($patchOps.Count -eq 0) {
    Write-Host '  No changes needed -- all targeted fields already match requested values.' -ForegroundColor Green
    Write-Host ''
    Write-Host "Verify: curl -H `"Authorization: Bearer `$TOKEN`" $BaseUrl/api/v1/cases/$CaseId" -ForegroundColor DarkGray
    exit 0
}
foreach ($op in $patchOps) {
    Write-Host ("  replace {0,-65} -> {1}" -f $op.path, (Format-Value $op.value))
}
foreach ($p in $alreadyCurrent) {
    Write-Host ("  (skip)  {0,-65}     already current" -f $p) -ForegroundColor DarkGray
}

if ($DryRun) {
    Write-Section 'Patch document (would be sent)'
    Write-Host (ConvertTo-Json -InputObject $patchOps -Depth 6)
    Write-Host ''
    Write-Host '-DryRun complete -- no live PATCH sent.' -ForegroundColor Yellow
    exit 0
}

# Live PATCH (with one 412 retry)
$result = Send-PatchAndReget -Token $token -PatchOps $patchOps -ETag $etag

if ($result.StatusCode -eq 428) {
    Write-Host "ERROR: HTTP 428 -- If-Match header missing or invalid. Body: $($result.ErrorBody)" -ForegroundColor Red
    exit 4
}
if ($result.StatusCode -eq 412) {
    Write-Host 'WARN: HTTP 412 (ETag mismatch) -- another writer updated the case. Re-GETing and retrying once.' -ForegroundColor Yellow
    $caseAndEtag = Get-CaseAndEtag -Token $token
    $result = Send-PatchAndReget -Token $token -PatchOps $patchOps -ETag $caseAndEtag.ETag
}
if ($result.StatusCode -lt 200 -or $result.StatusCode -ge 300) {
    Write-Host "ERROR: PATCH failed -- HTTP $($result.StatusCode). Body: $($result.ErrorBody)" -ForegroundColor Red
    if ($result.Exception) { Write-Host "  Exception: $($result.Exception)" -ForegroundColor Red }
    exit 4
}

# Re-snapshot from PATCH response (already JSON of the updated case)
$caseJson = $result.Case
$dft      = $caseJson.dataFulfillmentTasks[$dftIndex]
$dc       = $dft.dataCategories.$catKey

$final = [ordered]@{
    'TenantId'                       = $caseJson.tenantId
    "DFT[$dftIndex].targetIdentifier.identifierHash" = $dft.targetIdentifier.identifierHash
    "DC[$catKey].startDateTime"      = $dc.startDateTime
    "DC[$catKey].endDateTime"        = $dc.endDateTime
    "DC[$catKey].deliveryChannel"    = $dc.deliveryChannel
    "DC[$catKey].regionDataCenter"   = $dc.regionDataCenter
    "DC[$catKey].deliveryJobId"      = $dc.deliveryJobId
    "DC[$catKey].publishJobId"       = $dc.publishJobId
}

Write-Section "Final values (CaseId: $CaseId, new ETag: $($result.ETag))"
foreach ($k in $final.Keys) {
    Write-Host ("  {0,-55} {1}" -f $k, (Format-Value $final[$k]))
}

Write-Host ''
Write-Host "OK Updated $($patchOps.Count) field(s); $($alreadyCurrent.Count) already current." -ForegroundColor Green
Write-Host "  Verify: curl -H `"Authorization: Bearer `$TOKEN`" $BaseUrl/api/v1/cases/$CaseId" -ForegroundColor DarkGray
exit 0
