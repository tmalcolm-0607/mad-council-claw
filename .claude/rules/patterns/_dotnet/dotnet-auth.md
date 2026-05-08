---
paths:
  - "**/*.cs"
  - "**/Program.cs"
  - "**/appsettings*.json"
  - "**/spec.md"
---

# .NET Authentication & Authorization

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

MISE v2 (an internal identity-service extension), authorization policies, and auth context patterns for .NET services. The MISE SDK is a proprietary internal library; the patterns below still apply if you swap in any equivalent S2S auth stack (e.g., Microsoft.Identity.Web for public-cloud-only scenarios).

---

## MISE v2 Authentication

> **Cross-reference consensus**: the majority of audited ecosystem services use MISE SDK registration. Newer services use v2.x (`AddMiseWithDefaultModules`); older ones use v1.x (`AddMiseWithDefaultAuthentication`).
>
> **Version Note**: v1.x uses `AddMiseWithDefaultAuthentication` + `EnableTokenAcquisitionToCallDownstreamApi()`. v2.x uses `AddMiseWithDefaultModules` (no chaining needed for incoming S2S auth). The `MiseAuthenticationDefaults.AuthenticationScheme` is `"S2SAuthentication"` (namespace: `Microsoft.Identity.ServiceEssentials`).

### Package References

```xml
<PackageReference Include="Microsoft.Identity.ServiceEssentials.AspNetCore" Version="2.0.1" />
<PackageReference Include="Microsoft.Identity.Web.DownstreamApi" Version="3.0.0" />
```

### Program.cs Setup

> **Cross-reference consensus**: most audited references use MISE SDK registration. Newer v2.x services use `AddMiseWithDefaultModules`. Older v1.x services use `AddMiseWithDefaultAuthentication`.

```csharp
// v2.x pattern: AddMiseWithDefaultModules
builder.Services.AddAuthentication(MiseAuthenticationDefaults.AuthenticationScheme)
    .AddMiseWithDefaultModules(builder.Configuration);

// v1.x pattern: AddMiseWithDefaultAuthentication
// builder.Services.AddAuthentication(MiseAuthenticationDefaults.AuthenticationScheme)
//     .AddMiseWithDefaultAuthentication(builder.Configuration)
//     .EnableTokenAcquisitionToCallDownstreamApi();  // Chain for downstream API calls

// S2S Authentication Events (v1.x pattern)
services.Configure<S2SAuthenticationEvents>(events =>
{
    events.OnRequestValidated = context =>
    {
        // Custom claim enrichment after MISE validates the token
        return Task.CompletedTask;
    };
});

// Scope-based authorization policies
services.AddAuthorization(options =>
{
    options.AddPolicy("CaseRead", policy =>
        policy.RequireClaim("scope", "Cases.Read", "Cases.ReadWrite"));
    options.AddPolicy("CaseWrite", policy =>
        policy.RequireClaim("scope", "Cases.ReadWrite"));
});

// Downstream API registration
builder.Services.AddDownstreamApi("CaseManagement",
    builder.Configuration.GetSection("DownstreamApis:CaseManagement"));
```

### Wrong: Custom JWT Validation

```csharp
// WRONG: Custom JWT validation (don't reinvent)
services.AddAuthentication()
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            // Manual configuration...
        };
    });
```

---

## Configuration (appsettings.json)

> **Cross-reference consensus**: MISE config in `appsettings.json` is the most common approach. Some services use a separate `miseconfig.json`; others use `AzureAd` in appsettings. Consolidating into `appsettings.json` is the majority pattern.

```json
{
    "AzureAd": {
        "Instance": "https://login.microsoftonline.com/",
        "TenantId": "your-tenant-id",
        "ClientId": "your-client-id",
        "ClientCredentials": [{
            "SourceType": "SignedAssertionFromManagedIdentity",
            "ManagedIdentityClientId": "your-msi-client-id"
        }]
    },
    "DownstreamApis": {
        "CaseManagement": {
            "BaseUrl": "https://case-management.lens.microsoft.com",
            "Scopes": ["api://case-management-client-id/.default"],
            "RequestAppToken": true
        }
    },
    "Mise": {
        "ClaimsOnlyAuthZ": {
            "Enabled": true,
            "Policies": [{
                "Name": "AllowedCallers",
                "Profile": "SingleTenantWebApiApp",
                "Subject": {
                    "AnyOfAuthorizedClients": ["dfs-client-id", "leportal-client-id"]
                }
            }]
        }
    }
}
```

---

## PostConfigure: Dual Audience Format

MISE v2 tokens may contain audiences as bare GUIDs or `api://` URI format. Use `PostConfigure` to accept both:

```csharp
// Program.cs - after AddMiseWithDefaultModules
services.PostConfigure<JwtBearerOptions>(
    MiseAuthenticationDefaults.AuthenticationScheme,
    options =>
    {
        var clientId = configuration["AzureAd:ClientId"]!;
        options.TokenValidationParameters.ValidAudiences = new[]
        {
            clientId,           // Bare GUID: "00000000-0000-..."
            $"api://{clientId}" // URI format: "api://00000000-0000-..."
        };
    });
```

Without this, tokens using the `api://` audience format will be rejected with a 401.

---

## Middleware Pipeline Integration

PostAuthMiddleware sits at **step 8** of the ecosystem-aligned pipeline.

> **MISE v2.1.0 Update**: a consumer project discovered that `UseMise()` must come AFTER `UseAuthorization()`, not before. ClaimsOnlyAuthZ depends on ASP.NET authorization having already evaluated the principal. The table below reflects the corrected ordering for MISE v2.x.

```csharp
// Program.cs -- Auth-related middleware (steps 7-10 of the full pipeline)
app.UseAuthentication();                          // Step 7: Establishes ClaimsPrincipal
app.UseMiddleware<PostAuthMiddleware>();           // Step 8: Claims -> AuthContext
app.UseAuthorization();                           // Step 9: Evaluate policies
app.UseMise();                                    // Step 10: MISE v2 modules (AFTER authz)
```

| Step | Middleware | Why |
|------|-----------|-----|
| 7 | `UseAuthentication()` | Establishes `ClaimsPrincipal` from JWT |
| 8 | `PostAuthMiddleware` | Extracts claims into `AuthContext` |
| 9 | `UseAuthorization()` | Evaluates scope/role policies |
| 10 | `UseMise()` | MISE v2 modules (ClaimsOnlyAuthZ requires authz complete) |

**CRITICAL**: `UseMise()` before `UseAuthorization()` worked in MISE v1.x but breaks ClaimsOnlyAuthZ in v2.x.

**Key ordering rules**:
- Authentication before PostAuth -- claims must exist before extraction
- PostAuth before Authorization -- AuthContext must be populated before policy evaluation
- See `dotnet-security.md` for the complete 11-step middleware pipeline
- See `dotnet-appservices-pattern.md` for how AuthContext flows through AppServices

---

## PostAuthMiddleware / AuthContext Builder

> **Cross-reference consensus**: the PostAuthMiddleware -> AuthContextBuilder flow is confirmed in the majority of audited services (some handle auth differently and have no AppServices). The two-phase initialization (InitializeAppServicesMiddleware step 2 + PostAuthMiddleware step 8) is the established pattern.

Runs AFTER authentication, BEFORE authorization. Extracts claims from the authenticated `ClaimsPrincipal` and populates `AppServices.AuthContext`.

Some ecosystem services call this `PostAuthMiddleware`; others call it `AuthContextBuilderMiddleware`. Both serve the same purpose.

### Claims Extraction

```csharp
public class PostAuthMiddleware
{
    private readonly RequestDelegate next;

    public PostAuthMiddleware(RequestDelegate next)
    {
        this.next = next;
    }

    public async Task InvokeAsync(HttpContext context, IAppServices appServices)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var claims = context.User;

            appServices.AuthContext = new AuthContext
            {
                // App identity (client credentials flow)
                AppId = claims.FindFirstValue("appid") ?? claims.FindFirstValue("azp") ?? string.Empty,

                // Tenant identity
                TenantId = claims.FindFirstValue("tid") ?? string.Empty,

                // User identity (delegated flow)
                ObjectId = claims.FindFirstValue("oid") ?? string.Empty,

                // Roles and scopes
                Roles = claims.FindAll("roles").Select(c => c.Value).ToList(),
                Scopes = claims.FindFirstValue("scp")?.Split(' ') ?? Array.Empty<string>()
            };
        }

        await this.next(context);
    }
}
```

### AuthContext Model

```csharp
public class AuthContext
{
    public string AppId { get; set; } = string.Empty;
    public string TenantId { get; set; } = string.Empty;
    public string ObjectId { get; set; } = string.Empty;
    public IReadOnlyList<string> Roles { get; set; } = Array.Empty<string>();
    public IReadOnlyCollection<string> Scopes { get; set; } = Array.Empty<string>();

    // Convenience properties
    public bool IsAuthenticated => !string.IsNullOrEmpty(AppId);
    public bool IsUserContext => !string.IsNullOrEmpty(ObjectId);
    public string CurrentAppId => AppId;
}
```

---

## Extracting Caller Identity

```csharp
[Authorize]
[HttpPost]
public async Task<IActionResult> CreateSas([FromBody] SasRequest request, CancellationToken ct)
{
    var callerId = User.FindFirst("azp")?.Value ?? User.FindFirst("appid")?.Value;
    var callerTenantId = User.FindFirst("tid")?.Value;

    // Service throws typed HandlerException subclasses (e.g. SasGenerationException, SasNotAuthorizedException);
    // GlobalErrorHandlingMiddleware (registered by AddLensTelemetry) maps them to ProblemDetails responses.
    var sasResponse = await this.sasService.CreateSasAsync(request, callerId, ct);
    return Ok(sasResponse);
}
```

---

## Claim Validation & Null Safety

**CRITICAL**: Never use the null-forgiving operator (`!`) on nullable identity claims. Claims like `TenantId`, `CurrentAppId`, and `ObjectId` can be null when the token lacks the expected claim. Using `!` silences the compiler but produces a runtime NRE.

### Correct: Explicit Guard

```csharp
// Option 1: Helper method that throws a descriptive exception
var tenantId = appServices.AuthContext.GetRequiredTenantId();
var objectId = appServices.AuthContext.GetRequiredObjectId();

// Option 2: Null-coalescing throw
var appId = appServices.AuthContext.CurrentAppId
    ?? throw new UnauthorizedException("Missing appid/azp claim");

// Option 3: Guard clause
Guard.Against.NullOrWhiteSpace(authContext.TenantId, nameof(authContext.TenantId));
```

### Wrong: Null-Forgiving Operator

```csharp
// WRONG: Silences compiler, NRE at runtime if claim missing
var tenantId = appServices.AuthContext.TenantId!;
var appId = authContext.CurrentAppId!;

// WRONG: A null TenantId persists data without tenant isolation
await this.repository.CreateCaseAsync(new Case { TenantId = authContext.TenantId! });
```

**Source**: CMS PR#4895114 -- `CreateCaseAsync` was the only CRUD path missing `GetRequiredTenantId()`, allowing cases to be created without tenant isolation. All other handlers used the guard method.

---

## Calling Downstream APIs

```csharp
public class CaseValidationService
{
    private readonly IDownstreamApi downstreamApi;

    public async Task<bool> ValidateCaseAsync(string caseId, CancellationToken ct)
    {
        var response = await this.downstreamApi.CallApiForAppAsync(
            "CaseManagement",
            options =>
            {
                options.HttpMethod = HttpMethod.Post;
                options.RelativePath = $"api/cases/{caseId}/validate";
            }, ct);

        return response.IsSuccessStatusCode;
    }
}
```

**Why IDownstreamApi (not raw HttpClient)**:
- Automatic token acquisition/caching
- Automatic refresh
- CAE support
- Automatic 401 retry

---

## Managed Identity Configuration

### User-Assigned (Preferred)

```bicep
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lens-cms-${environment}'
  location: location
}

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentity.id}': {} }
  }
}
```

### Credential Provider

```csharp
public TokenCredential GetCredential()
{
    if (this.environment.IsProduction())
    {
        var clientId = this.config["Azure:ManagedIdentityClientId"];
        return !string.IsNullOrEmpty(clientId)
            ? new ManagedIdentityCredential(clientId)
            : new ManagedIdentityCredential();
    }

    return new ChainedTokenCredential(
        new AzureCliCredential(),
        new VisualStudioCredential());
}
```

---

## Role Assignments (Bicep)

```bicep
// Storage Blob Data Contributor
resource storageBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, principalId, 'Storage Blob Data Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets User
resource kvSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, principalId, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

---

## Entra ID App Roles vs Azure RBAC

Entra ID app roles and Azure RBAC are separate systems. Bicep/ARM deployments can only deploy ARM-level RBAC (`Microsoft.Authorization/roleAssignments`), NOT Entra ID app roles.

| System | Where It Lives | Deployed By |
|--------|---------------|-------------|
| Azure RBAC | ARM resources | Bicep / Azure deployment pipeline (`Microsoft.Authorization/roleAssignments`) |
| Entra ID App Roles | App registration (Entra ID) | Graph API (post-provisioning script) |

**Symptom**: E2E tests return 403 after first deploy to a new environment -- app roles are missing.

**Fix**: Run a post-provisioning script (e.g. `Assign-AppRoles.ps1`) after each deploy to a new environment. This script assigns roles via Graph API.

---

## Enforcement

| Rule | Severity |
|------|----------|
| Use `AddMiseWithDefaultModules` (v2.x) or `AddMiseWithDefaultAuthentication` (v1.x) | **REJECT** if custom JWT |
| Use scope-based authorization policies | **WARN** if role-only |
| Protected endpoints require `[Authorize]` | **REJECT** if missing |
| PostAuthMiddleware placed after `UseAuthentication` | **REJECT** if missing |
| `UseMise()` before `UseAuthorization()` (MISE v2.x) | **REJECT** |
| `AuthContext.Property!` (null-forgiving on auth claims) | **REJECT** |
| Nullable auth claim used without null check | **WARN** |
| `DefaultAzureCredential` in production code paths | **REJECT** |
| Placeholder GUID (all zeros) in auth configuration | **WARN** |
| Assuming Bicep deploys app roles | **REJECT** |
| Missing post-provisioning app role step | **WARN** |

---

## MISE v2 Explicit AuthZ Policies

**Source**: cross-repo PR-review finding across multiple ecosystem services (Feb 2026).

**CRITICAL**: MISE v2 handles **AuthN** (token validation) but **AuthZ must be explicit**. Removing legacy auth code without adding MISE v2 authorization policies leaves gaps.

When migrating to MISE v2, ensure these AuthZ boundaries are configured:

| Boundary | MISE v2 Mechanism | What It Prevents |
|----------|------------------|------------------|
| **Claims validation** | `RequireClaim("scope", ...)` policies | Unauthorized scope access |
| **Tenant validation** | `ValidTenantIds` in MISE config | Cross-tenant data access |
| **Token type check** | `Subject.AnyOfAuthorizedClients` | Unexpected caller apps |
| **AppId boundaries** | `AzureAd:ClientId` + audience validation | Wrong app receiving tokens |

```json
// appsettings.json -- Explicit AuthZ boundaries
{
  "Mise": {
    "ClaimsOnlyAuthZ": {
      "Enabled": true,
      "Policies": [{
        "Name": "AllowedCallers",
        "Profile": "SingleTenantWebApiApp",
        "Subject": {
          "AnyOfAuthorizedClients": ["known-client-id-1", "known-client-id-2"]
        }
      }]
    }
  },
  "AzureAd": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "ValidTenantIds": ["your-tenant-id"]
  }
}
```

**Reviewer expectation** (from cross-repo PR review):
> "A lot of Auth code is being removed, which is totally fine as MISE v2 is awesome, but we should have alternatives in place through MISE v2 like checking the user token for claims, whether it is a Torus token (i.e. specific tenant) etc."

| Pattern | Status |
|---------|--------|
| MISE v2 migration without explicit AuthZ policies | **REJECT** |
| Missing `ValidTenantIds` in MISE config | **WARN** |
| Placeholder GUIDs (all zeros) in `AnyOfAuthorizedClients` | **WARN** |
| No scope-based authorization policies after removing legacy auth | **REJECT** |

---

## Security event identity requirements

Any structured event recording a security-significant action (token issuance, SAS issuance, authorization decision, role grant/revoke, sensitive data access, audit record) MUST include all three caller-identity fields on **both success AND failure paths**. Failure events are frequently more valuable for security investigations — asymmetric definitions are a compliance gap.

Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 18 (lines 514-525); LENS-Common CLAUDE.md `OAuthClaims.GetClaim()` + `OAuthClaimTypes`.

### Required identity fields

| Property on the event | Source | How to populate |
|-----------------------|--------|-----------------|
| `CallerAppId` | Entra ID `appid` / `azp` claim | `appContext.AuthContext.SubjectClaims.CurrentAppId` |
| `CallerTenantId` | Entra ID `tid` claim | `appContext.AuthContext.SubjectClaims.TenantId` |
| `CallerObjectId` | Entra ID `oid` claim | `appContext.AuthContext.SubjectClaims.GetClaim(OAuthClaimTypes.ObjectId)` |

### Both success AND failure paths

```csharp
// ✓ CORRECT — failure path captures identity too; same shape as success path
public async Task IssueSasAsync(SasRequest request, CancellationToken ct)
{
    var subj = appContext.AuthContext.SubjectClaims;
    var common = new
    {
        CallerAppId = subj.CurrentAppId,
        CallerTenantId = subj.TenantId,
        CallerObjectId = subj.GetClaim(OAuthClaimTypes.ObjectId),
    };

    if (!authorizer.CanIssueFor(request.ResourceId, subj))
    {
        telemetryContext.StructuredLogger.LogEvent(new SasIssuanceDeniedEvent
        {
            CallerAppId = common.CallerAppId,
            CallerTenantId = common.CallerTenantId,
            CallerObjectId = common.CallerObjectId,
            ResourceId = request.ResourceId,
            DenyReason = "AuthorizationFailed",
            OccurredAt = DateTimeOffset.UtcNow,
        });
        throw new ForbiddenException("Insufficient privilege.");
    }

    var sas = await sasService.GenerateAsync(request, ct);

    telemetryContext.StructuredLogger.LogEvent(new SasIssuedEvent
    {
        CallerAppId = common.CallerAppId,
        CallerTenantId = common.CallerTenantId,
        CallerObjectId = common.CallerObjectId,
        ResourceId = request.ResourceId,
        PermissionsGranted = sas.Permissions,
        ExpiresAt = sas.ExpiresAt,
        OccurredAt = DateTimeOffset.UtcNow,
    });
}
```

### Anti-pattern — success-only identity

```csharp
// ✗ WRONG — failure event carries no identity; security investigation cannot determine who tried
telemetryContext.StructuredLogger.LogEvent(new SasIssuanceDeniedEvent
{
    ResourceId = request.ResourceId,
    DenyReason = "AuthorizationFailed",
    // CallerAppId / CallerTenantId / CallerObjectId omitted on failure
});
```

### `OAuthSecurityEvent` is NOT a substitute

`OAuthSecurityEvent` records *authentication* outcomes (token validated / rejected) — it does NOT record *authorization* decisions (permission grant / deny on a specific resource). Define your own service-specific events for authorization, token issuance, SAS issuance, and audit records. For events recording token or SAS issuance, also capture the permissions granted and the target resource — without those, the audit trail can't answer "what did this caller obtain access to?"

---

## Distributed Token Caching

For multi-instance deployments, consider [MISE's distributed OIDC cache](https://eng.ms/docs/products/identity-developer-platform-idp/microsoft-identity-service-essentials/authentication/distributed-oidc-cache) to avoid per-instance token resolution overhead.

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Custom JWT validation | Use `AddMiseWithDefaultModules` (v2.x) or `AddMiseWithDefaultAuthentication` (v1.x) |
| No authorization policies | Add scope-based policies |
| Missing `[Authorize]` attribute | Add authorization attributes |
| Accessing claims directly in handlers | Use `AppServices.AuthContext` |
| PostAuth before `UseAuthentication` | Claims not available yet |
| Missing PostAuthMiddleware | AuthContext empty for downstream code |
| `UseAuthorization()` before `UseAuthentication()` | Auth context not available |
| Missing PostAuthMiddleware between auth and authorization | AuthContext not populated for policies |
| `UseMise()` before `UseAuthorization()` in MISE v2.x | ClaimsOnlyAuthZ requires authz to run first |
| Null-forgiving operator on auth claims | Use `GetRequired*` methods or null-coalescing throw |
| MISE v2 migration without configuring AuthZ policies | Add explicit claims/tenant/token-type validation |
| Missing `ValidTenantIds` after removing legacy tenant check | Configure in MISE appsettings |
