# Security Review Checklist — Recurring Pitfalls

This checklist is **injected into every multi-model review** as mandatory context. It encodes recurring security pitfall *themes* that ship to production again and again across enterprise web services: misconfigurations that survive review, defense-in-depth layers that fall open under empty configuration, and code-level patterns that look benign but leak secrets, identities, or capability.

When reviewing a diff, scan it against every section. If a pattern matches and the PR does not explicitly mitigate it, raise a finding citing the section name (e.g. `[S2] Authorization fail-open`).

**Default severities**

| Class | Default | Notes |
|---|---|---|
| AuthN/AuthZ bypass, secret leakage, RCE, IDOR returning credentials | CRITICAL | Block the PR |
| Crypto misuse, IDOR (non-credential), SSRF with token re-attach, IaC public exposure | HIGH | Request changes |
| PII leakage, info disclosure via errors, WAF in Detection mode | HIGH | Request changes |
| Frontend SPA hazards, supply chain, dev tooling | MEDIUM | Request changes unless mitigated |
| Latent / dead-code fail-open paths | MEDIUM | Note + require fix or removal |

---

## S1. Unauthenticated endpoints

State-changing or sensitive routes must require authentication. An anonymous-allowed annotation on a controller/action is a finding unless the route is explicitly a public health probe with no body and no side effects.

**Flag if you see:**
- `[AllowAnonymous]` (.NET), `@PreAuthorize("permitAll()")` (Spring), `app.use(unless({path:[…]}))` (Express), `permission_classes = [AllowAny]` (DRF), or any framework-equivalent on an action that writes to a database, queues a message, issues a credential (signed URL / SAS / token), mutates a feature flag, or proxies to a downstream service.
- A controller without an `[Authorize]` / `@Authenticated` attribute (and no class-level inheritance) on routes other than `/health/live` or `/health/ready`.
- Minimal-API / route handlers added without `.RequireAuthorization()` / authentication middleware.
- `/metadata`, `/diagnostics`, `/endpoints`, `/swagger`, `/docs`, `/internal/*`, or any "internal" route reachable without auth.

---

## S2. Authorization fail-open

Two recurring failure modes regardless of authorization framework: **enforcement disabled** (logging-only / audit-only / dry-run mode in production), and **allow-lists treated as allow-all when empty**.

**Flag if you see:**
- `EnforcementMode: AuditMode` / `LogOnly` / `dryRun: true` / `mode: "report"` / `Action: "Count"` in any non-`Dev*` environment config.
- Allow-lists for application IDs, groups, roles, tenants, or scopes set to `[]` or omitted entirely in production configs.
- Authorization handler logic that returns success when the configured list is null/empty (`if (!allowed.Any()) return Success();` / `if not allowed: return True`).
- A controller where some actions enforce a policy (e.g. `[Authorize(Policy = "Admin")]` on `Delete`) and other actions on the same controller do not (e.g. `Add`, `List`, `Resolve`).
- A handler that omits a tenant-isolation / org-scoping check that every other method in the same class performs.
- First-party / "common" application IDs (e.g. cloud CLIs, identity-provider PowerShell modules, Postman) present in a production allow-list — these are not specific to your customers.
- Demo / test / sandbox identities (test certificate thumbprints, `*-test-*` principals, dev tenant entries) present in a production allow-list / authorization table.

---

## S3. IDOR / missing object-level ownership checks

Authentication is not authorization. Every read/write of a resource must verify the caller owns or has been granted access to *that specific resource*.

**Flag if you see:**
- A handler that accepts a client-supplied resource path / ID (`blobPath`, `documentId`, `caseId`, `userId`, `accountId`, `mailboxId`) and passes it to a downstream service using **app-only** / service credentials without first verifying the caller has access to *that* resource.
- A `GET /…/content` or `/…/download` endpoint that returns blob/file content based purely on a path/ID parameter.
- A password-reset / credential-rotation endpoint that returns the new credential and is keyed only on a target ID supplied by the caller.
- Audit/identity fields written from the client request body: `ApproverName`, `ApprovalDateTime`, `RequestedBy`, `OnBehalfOf`, `CreatedBy`. These must come from the validated identity (`ClaimsPrincipal` / authenticated user context), never from the body.
- State-changing operation behind a `GET` (no CSRF / intent verification) or without a resource-ownership check.

---

## S4. Client-spoofable identity & rate-limit keys

Anything in a request header that an attacker controls cannot identify the caller or partition a security/abuse-control bucket.

**Flag if you see:**
- `X-Forwarded-For`, `X-Real-IP`, or `RemoteIpAddress` used as a rate-limit key, abuse cache key, or authorization input without a forward-proxy trust list constraining which proxies can set them (`ForwardedHeadersOptions.KnownProxies/KnownNetworks`, `trust proxy` in Express, equivalent reverse-proxy config).
- Any custom `X-*` header (`X-Caller-Id`, `X-Client-Id`, `X-User-Email`, `X-Tenant-Id`) used to look up identity, partition rate-limits, or grant authorization. Custom headers are attacker-controlled.
- `Request.Host` / `req.headers.host` used to decide `IsSandbox`, `IsDev`, allow-bypass, or to gate auth. The Host header is client-supplied unless the host name is validated against a strict allow-list.
- Cert-based identity accepted from an HTTP header (`X-Forwarded-Client-Cert`, `X-ARR-ClientCert`, `ssl-client-cert`) without re-running chain + revocation validation server-side. See also S13.

---

## S5. Dev/sandbox shortcuts reachable in production

"Bypass auth in dev" branches must be reachable only in dev. The bar is: cannot be reached by toggling an env var, cannot be reached by a header, cannot be reached by a config flag flippable in production.

**Flag if you see:**
- `if (env.IsDevelopment()) { /* skip auth, return early, return secret */ }` or framework-equivalents (Spring `@Profile("dev")`, Django `if settings.DEBUG`, Node `if process.env.NODE_ENV !== 'production'`) where the env var could plausibly be toggled in production.
- A "filesystem fallback" or "local file" branch in a download/attachment endpoint that is conditionally compiled or env-gated but still present in the production binary.
- Conditional-compilation symbols (`#if DEBUG`, `#ifdef DEV`) protecting auth bypasses — these still ship in `Debug` builds and accidental Debug deployments happen.
- A `RecordReplay`, `Mock`, `Stub`, or `Test` mode toggled by a config flag, header, or env var that disables auth, signature verification, or downstream credential validation.
- Sandbox / test identities present in production configs (see S2).

---

## S6. Frontend SPA hazards

Client-side guards are **defense in depth**, never the security boundary. The server must enforce. But the client must also not regress.

**Flag if you see:**
- An `AuthGuard` / `RequireAuth` / `ProtectedRoute` component whose default render path returns `children` (or `<Outlet/>`) when the auth state is unknown/loading. Default must be a loader or redirect, never a pass-through.
- `localStorage.setItem('token', …)` / `…('access_token', …)` / `…('bearer', …)` / `sessionStorage.setItem(…)`. Tokens go in HTTP-only cookies or in-memory state — never `localStorage`/`sessionStorage`.
- `<iframe src={blobUrl}>` without `sandbox="allow-…"` (and the `allow-same-origin` token explicitly omitted unless required) when the iframe renders user/attacker-controlled content.
- File-upload UIs that validate type/extension only on the client (`accept=".pdf"` or a JS extension check) without server-side magic-byte / content-type validation.
- Routing that exposes a "protected" page when a `useEffect` redirect hasn't fired yet — the protected component renders for one frame, leaking content to a logged-out user.

---

## S7. Secret leakage in logs, telemetry, exception text, source control

A secret leaked into a log aggregator, telemetry sink, exception message, or committed file is permanently compromised. Rotation is the only remediation, and it isn't always possible.

**Flag if you see:**
- A logger / telemetry / metric call that emits a request body, full URL (signed URLs / SAS tokens / pre-signed URLs live in URLs), `Authorization` header, `WWW-Authenticate`, certificate thumbprint, password, OTP, refresh token, or any short-lived credential. Watch for `_logger.Log…(…, request.Body, …)`, `logger.error(err, message)` where `message` is the raw payload.
- A data class / `record` / `dataclass` that contains a secret field (e.g. `SasUri`, `Password`, `ConnectionString`, `BearerToken`, `RefreshToken`) and is not redacted in its auto-generated `ToString()` / `__repr__`. These will dump the secret when interpolated into a log message.
- A `SanitizeValue` / `Redact` / `Scrub` helper that is a pass-through (returns input unchanged, has a `// TODO` comment, or is `internal static T Sanitize<T>(T v) => v;`).
- A structured event whose `Payload`, `Body`, `RequestBody`, `ResponseBody`, or `Headers` field is the raw value with no field-level allow-list.
- An exception filter or middleware that logs `ex.ToString()` / `ex.Message` / `err.stack` for an exception built from request data without sanitization.
- A test fixture, `appsettings.*.json`, `*.local.json`, `.env`, JMeter `.jmx` (`requestHeaders=true`), or demo/results artifact containing a real `sig=`, `code=`, `client_secret=`, `Bearer …`, or private key.
- The `Authorization` header logged because of a parsing branch (`if (!header.Contains(" ")) _logger.Log(…, header)`).

---

## S8. PII / EUII in logs and metric dimensions

Email addresses, government IDs, customer identifiers, IP addresses, and end-user identifiers are PII / EUII. Most observability sinks are **not** approved as PII stores, especially as **metric dimensions** (which are indefinitely retained and indexed).

**Flag if you see:**
- `_logger.LogInformation(…, email)`, `logger.error("Resending code to {email}", …)` — the value is a real user/customer email or ID. Even at the equivalent of `Information` level.
- OpenTelemetry / Prometheus / StatsD `Meter`/`Histogram`/`Counter` `.Add(…, new("clientIp", ip), new("userId", id))` — these become time-series dimensions, retained indefinitely.
- Per-request context items (`RequestContext.Items["…Email"]`, `RequestRequestor`, `…TargetIdentifier`) flowing into the structured-event property bag without redaction.
- An OTP / verification code logged at any level for any reason (`"Generated code {code} for {email}"`).
- PII inside an exception message that is then logged (see S7 also).

**Carve-outs (forthcoming):**

LENS has approved compliant logging sinks for some EUII fields. The canonical list is forthcoming — when it lands, replace this block with the explicit allow-list (sink name, fields, retention). Until then, **flag every instance** and tag the finding with a request for confirmation that the sink is compliant and the field is on the approved list. Do not silently allow PII through.

---

## S9. Debug / diagnostics enabled in production

Detailed errors, API documentation, dev exception pages, debug log levels, and internal-URL diagnostics are reconnaissance gold for an attacker.

**Flag if you see:**
- `app.UseDeveloperExceptionPage()` (.NET), `app.use(errorhandler())` (Express), `DEBUG = True` (Django), `spring-boot-devtools` reachable in production — no env guard, or guard bypassable per S5.
- API-doc UIs (`UseSwagger()`, `swagger-ui-express`, `springfox`, `redoc`) mapped before the auth middleware, or mapped at all in a production pipeline.
- Verbose error / detailed-errors flags (`ASPNETCORE_DETAILEDERRORS=true`, `Logging:LogLevel:Default=Debug`, `LOG_LEVEL=trace`) in any production config.
- `/health/<dependency>`, `/ready`, `/diagnostics`, `/internal/*` returning the message of a downstream exception, raw response body of a downstream call, or internal URLs.
- A global exception handler / problem-details factory returning `ex.Message` for a non-domain-error exception.
- Middleware that reflects `ex.StackTrace` / `ex.InnerException.Message` / `err.stack` to unauthenticated callers.

---

## S10. IaC: deployment-output secret leakage and over-privileged identities

Deployment outputs are written to deployment history (ARM / Terraform state in shared backends / CloudFormation stack outputs) and visible to anyone with read access to the resource group / backend / stack. IaC is also where most over-privileged role assignments enter the system.

**Flag if you see:**
- An IaC `param` / `variable` that holds a SAS URL, signed URL, package URL, connection string, or any secret and is **not** marked as a secret (`@secure()` in Bicep, `sensitive = true` in Terraform, `NoEcho: true` in CloudFormation). Common offenders: `param packageUrl`, `param zipPackageUri`, `var deploymentToken`.
- An IaC `output` that emits a connection string, instrumentation key, account key, primary master key, or any credential. Outputs are not secret — they are persisted in deployment metadata.
- **HIGH** — A managed-secrets resource (Key Vault / Secrets Manager / Vault) with `softDeleteRetentionInDays` unset or `< 90`. LENS standard is 90-day soft-delete.
- **MEDIUM (defense-in-depth)** — A managed-secrets resource with `enablePurgeProtection` missing or `false`. Even with 90-day soft-delete, a tenant-admin compromise can issue a purge inside the retention window. Flag, but not blocking on its own.
- A signing certificate / KMS key policy with `keyProperties.exportable: true` / `Origin: External` for material that should be HSM-backed.
- A Key Vault deployed with `sku.name: 'standard'` (or analogue) in any non-dev config — LENS standard is **Premium AKV (HSM-backed)**. The `keyProperties.exportable` check above is moot if the SKU isn't HSM-backed in the first place.
- A storage / blob resource with `publicNetworkAccess: 'Enabled'` / public-read ACLs / `BlockPublicAccess` disabled in any non-dev config.
- A web tier / function with default IP restrictions (`defaultAction: 'Allow'`, no `ipSecurityRestrictions`) or `allowedHosts: '*'`.
- A role assignment granting a write/admin role (`Storage Blob Data Contributor`, `KeyVault Administrator`, `Contributor`, `iam:*`, `s3:*`) to a principal whose comment / name implies "Reader" / "dashboard" / "monitoring".
- Hardcoded production subscription / account IDs, FQDNs, public IPs, principal object IDs, or test passwords in `*.bicep`, `*.tf`, `*.yaml`, `*.json`, README/docs.

---

## S11. Network / WAF misconfiguration

WAF in Detection mode does not block attacks. Allowing wide service tags / large CIDR blocks defeats the perimeter.

**Flag if you see:**
- A WAF policy (Azure App Gateway / Front Door, AWS WAFv2, Cloudflare, NGINX ModSecurity) with `mode: 'Detection'` / `Action: 'Count'` / `default_action: 'count'` in a non-dev config. OWASP, bot, and rate-limit Block actions are no-ops in Detection.
- A WAF policy with `requestBodyCheck: 'Disabled'` — body-borne payloads are unfiltered.
- An NSG / Security Group / firewall rule with source `AzureCloud` / `Internet` / `0.0.0.0/0` / `*` to ports `*` or wide port ranges (e.g. `65200-65535`) on a non-management subnet.
- An outbound rule allowing `Internet` on `443` / `80` without an FQDN-restricted firewall / proxy in front of it ("egress not constrained to intended FQDNs").
- A network-perimeter / VPC endpoint policy with inbound `AzureCloud` / `*` and outbound `*` — perimeter is effectively disabled.
- WAF / load-balancer path rule allowing `/swagger`, `/api-docs`, `/metrics` without auth (see S9).

---

## S12. Cryptographic misuse

Algorithms that were "fine in 2010". Modes that leak structure. Comparisons that leak timing. Auth gates that fail open.

**Flag if you see:**
- `MD5.HashData(…)`, `MD5.Create()`, `SHA1.HashData(…)`, `crypto.createHash('md5')`, `hashlib.md5(…)`, or any default branch / fallback that resolves to MD5/SHA1 ("if `ChecksumType == null` use MD5"). Use SHA-256 or better.
- RSA-PKCS#1 v1.5 / `rsa1_5` for **wrap/unwrap** or **encryption** (Bleichenbacher); allow only OAEP with a hash >= SHA-256 (`RSA-OAEP-256`). PKCS#1 v1.5 for *signature* is also discouraged in favor of RSA-PSS.
- Always-Encrypted / encrypted-column with `EncryptionType = Deterministic` for a column holding a secret/PII (passwords, government IDs, emails). Use `Randomized`.
- `byte[].SequenceEqual(…)`, `string.Equals(…)`, `==`, `===` on HMAC tags, signatures, MACs, or auth tokens. Use a constant-time compare (`CryptographicOperations.FixedTimeEquals`, `crypto.timingSafeEqual`, `hmac.compare_digest`).
- An auth gate that reads a secret env var (e.g. an encryption key, heartbeat key, JWT signing key) and falls back to a derived/predictable value when the env var is unset (`?? string.Empty`, `?? "default"`, `?? Environment.MachineName`).
- A signature-verification code path that loads the verification public key from the same payload / blob / store as the signed allow-list (the attacker can swap the key with the data).
- A `verificationKey` / `signerCert` field deserialized from request body / config and passed straight to `VerifyData(…)` without chain validation or thumbprint pinning.

---

## S13. Certificate / TLS validation disabled or weakened

Globally disabling certificate validation in any client poisons every subsequent HTTPS call from that process.

**Flag if you see:**
- `ServerCertificateValidationCallback = (s, c, ch, e) => true` / `ServerCertificateCustomValidationCallback = …`, PowerShell `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}`, Node `rejectUnauthorized: false`, Python `requests.get(…, verify=False)`, Go `tls.Config{InsecureSkipVerify: true}`, Java `TrustManager` accepting all. Even in test/diagnostic scripts — these are often process-wide settings.
- `HttpClientHandler.ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator` (.NET).
- `HttpClient` / `OkHttpClient` / `requests.Session` constructed with a custom handler with no validation in any non-test code path.
- `verifyClientCertIssuerDN: false` / `verifyClientRevocation: 'None'` on a load balancer; `ValidateCertificateChain: false`, `RequireRevocation: false` in backend client-cert middleware.
- Client-cert identity accepted from `X-ARR-ClientCert` / `X-Forwarded-Client-Cert` without re-running chain + revocation validation server-side.
- Signature verification accepting a signer certificate supplied with the message ("attacker-supplied signer certificate") without anchoring to a pinned thumbprint or trusted CA.

---

## S14. Injection (path / command / SSRF)

Untrusted data in a path, in a shell argv, or in a URL the server fetches.

**Flag if you see:**
- A path constructed with `Path.Combine(rootDir, userInput)` / `os.path.join(root, userInput)` / `path.join(root, userInput)` and **no** containment check (`Path.GetFullPath(…).StartsWith(rootDir)`, `os.path.realpath(…).startswith(root)`, `path.resolve(…)` + prefix check). Reject `..`, `%2e%2e`, absolute paths, UNC paths.
- A `dev fallback` branch of a download endpoint that reads from the local filesystem using a request-supplied path — even if env-gated (see S5).
- Node `child_process` shell-form spawns built by string interpolation of a user/file-supplied value (template literals or string concatenation feeding a single-string command). Any spawn whose first argument is a single command string rather than `(file, args[])` is suspect.
- `Process.Start("cmd.exe", "/c " + arg)`, `bash -c "$ARGS"`, `system(…)`, `os.system(…)`, `Runtime.exec(String)` (Java), `Invoke-Expression $cmd`, `& $cmd $args` (PowerShell) where any input is not strictly validated. Use array-form argv, not interpolation.
- A deployment / orchestration script that builds an `arguments` string by concatenation and passes it to a shell, especially when failures are swallowed (`|| true`, `2>$null`, `set +e`, `try { … } catch {}` around the call).
- An OData / REST client following a server-supplied `@odata.nextLink` / `nextLink` / `Location` header without verifying the host matches the original endpoint, while re-attaching the bearer token to the new request (token exfil + SSRF).
- An HTTP client following redirects across schemes/hosts with `AllowAutoRedirect = true` / `redirect: 'follow'` and the auth header set on the handler (header replays on the redirect target).
- `fetch(userInputUrl)` / `HttpClient.GetAsync(userInputUrl)` / `requests.get(userInputUrl)` where `userInputUrl` originates from a client request and there is no allow-list of hosts/schemes (classic SSRF).

---

## S15. Supply chain, dev tooling, branch policy

The integrity of what ships is decided long before deploy.

**Flag if you see:**
- A new dependency whose name shadows a public npm/PyPI/NuGet/Maven package and whose version does **not** exist on the public registry — dependency-confusion bait. Verify with `npm view <pkg> versions`, `nuget list <pkg>`, `pip index versions <pkg>`.
- A new dependency with a non-vetted, low-download, single-maintainer package (typo-squatting risk) added without justification.
- Agent / IDE allow-list files (`.claude/settings.json`, `.cursor/…`, `.copilotignore`) granting `find:*`, `bash:*`, `Bash(*)`, wildcard MCP / tool patterns (`mcp__*__*`), `Bash(rm:*)`, or any rule that admits `-exec` arbitrary commands.
- Pre-commit / pre-push gates (credential scan, secret scan, lint) running in a subshell where the parent script discards the exit code (`(scan) || true`, `set +e` around the call, `exit 0` at end).
- Branch-protection / merge-policy with `resetOnSourcePush: false` combined with `creatorVoteCounts: true` (Azure DevOps), or "Allow specified actors to bypass required pull requests" / "Allow force pushes" enabled (GitHub) — a creator can self-approve, push more code, and the approval persists.
- A token-constraint / claims-restriction / scope-narrowing code block that is commented out, `[Obsolete]`, or `// TODO re-enable`.
- A README / docs / runbook instructing operators to "rubber-stamp" approvals based on hostname/source pattern alone (lockbox / JIT approval anti-pattern).

---

## Cross-cutting reviewer instructions

When you produce findings:

1. **Always cite the section** — start each security finding with `[S#]` so the synthesis step can group by category.
2. **Distinguish "active" from "latent"** — a fail-open path that is currently dead (empty allow-list never reached because of upstream config) is still a finding, but tag it `LATENT`. A fail-open path that is reachable today is `ACTIVE`.
3. **Map to the correct severity** using the table at the top. Do not downgrade a CRITICAL because it is "only" in a config file — config files ship.
4. **Do not flag style issues as security** — naming, doc comments, formatting are code-quality findings, not security findings. Security findings are S1–S15 only.

If a diff touches none of S1–S15, that is a valid outcome — say so explicitly: "Security review: no S1–S15 patterns triggered." Do not invent findings to fill the category.
