---
name: mcp-permission-validate
description: Validate MCP server registrations + URLs against allowlist, scheme rules, and threat-model policy before they enter settings.json or runtime ingestion.
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
disable-model-invocation: false
version: 1.0.0
inherits-rules:
  - rules/mcp-tiering.md
  - rules/dangerous-operations-policy.md
  - rules/prompt-injection-policy.md
  - rules/stride-threat-model.md
  - rules/skill-standards.md
  - rules/verification-protocol.md
  - rules/lens-multi-model-review-pattern.md
references:
  - m-main/common/permission-servers.ts
  - m-main/common/mcp-url-validation.ts
  - m-main/common/extensions-catalog/index.ts
  - .claude/rules/mcp-tiering.md
  - .claude/rules/dangerous-operations-policy.md
tier-target: A
tier-exempt: [evals, templates]
---

# Skill — `mcp-permission-validate`

Validate proposed MCP (Model Context Protocol) server registrations against the kit's permission policy substrate (`mcp-tiering.md` + `dangerous-operations-policy.md` + `stride-threat-model.md`) before they land in `settings.json` or get loaded by the runtime. The implementation primitives (allowlists, URL validators, capability classifiers) are sourced from `m-main/common/permission-servers.ts` and `m-main/common/mcp-url-validation.ts`; this skill is the kit-side glue that applies them at the right policy boundaries.

## When to use

| Scenario | Why validate |
|---|---|
| Consumer adds a new MCP server entry to `settings.json` | Pre-runtime gate against URL scheme, allowlist, and tier-policy violations |
| Consumer copies `settings.json` from a reference repo or shared config | Cross-source drift; allowlist may diverge between kits |
| Bulk migration: `mad-council-claw` ingests a kit's full settings.json | Verify each MCP entry passes URL/scheme/tier policy before commit |
| Skill body declares `mcp:` reference to a custom server | Validate the referenced server exists in the per-kit allowlist |
| `claude-md-refresh` workflow updates the MCP tier table | Cross-check claimed tiers against `mcp-tiering.md` substrate |

**Do NOT use** for skills' own `allowed-tools` validation — that's `skill-audit` Dimension 1 territory. This skill validates **MCP server registrations**, not skill tool surfaces.

## Inputs

| Input | Type | Required | Detail |
|---|---|---|---|
| `target` | path | yes | Either `settings.json` (or `.claude/settings.local.json`) OR a directory whose root is checked for both files |
| `--mode` | enum | no | One of `register | audit | drift-check`. Default: `audit`. |
| `--allowlist-file` | path | no | Override the default allowlist (the kit's `mcp-tiering.md` server-tier table). Useful for stricter consumer policies. |
| `--strict-https` | flag | no | Reject all `http://` URLs including localhost. Default: localhost over `http://` is allowed per `m-main/common/mcp-url-validation.ts:36-43`. |

### Mode semantics

| Mode | Behavior |
|---|---|
| `register` | Single new MCP entry → run all checks → emit accept/reject decision. Used by an interactive workflow. |
| `audit` | Read entire `mcpServers` object → check each entry → emit findings table. Default mode for `claude-md-refresh` and one-off audits. |
| `drift-check` | Compare claimed tier in `mcp-tiering.md` against settings.json registration → emit drift findings. Used by `/skill-audit`. |

## Outputs

A scan report with this shape (every finding row carries explicit `file` + `line` + `setting-path` evidence per `verification-protocol.md` Rule 1 FETCH BEFORE CITE):

| File | Line | Setting-path | Server | URL/Command | Tier | Validation result | Action |
|---|---|---|---|---|---|---|---|
| settings.json | 12 | mcpServers/filesystem/command | filesystem | (local command) | cli | ok | None |
| settings.json | 18 | mcpServers/github/command | github | (local command) | cli | ok | None |
| settings.json | 24 | mcpServers/my-custom/url | my-custom | https://api.example.com | unknown | NOT IN ALLOWLIST | BLOCKING — add to allowlist or remove |
| settings.json | 31 | mcpServers/local-test/url | local-test | http://10.0.0.5:8080 | (proposed) | http:// non-localhost rejected | BLOCKING — use https or move to localhost |
| settings.json | 37 | mcpServers/sequential-thinking/command | sequential-thinking | (local command) | cli | ok | None |
| settings.json | 43 | mcpServers/broken-url/url | broken-url | not-a-url | (n/a) | Invalid URL format | BLOCKING — fix URL |

`File` is the absolute path to the settings.json being audited; `Line` is the 1-indexed source line where the offending entry is declared (the validator parses settings.json with line tracking so each entry's source location is preserved); `Setting-path` is the JSON-pointer-style path to the offending value — together file:line + setting-path satisfy the `skill-standards.md` Dim 2 Output Contract requirement that every finding carry unambiguous evidence.

Per `mcp-tiering.md`, the kit's canonical tier table is the source of truth for `cli` vs `context-tier` classification.

## Workflow

### Step 0 — Preflight

1. Resolve `target` to absolute path; reject if neither `settings.json` nor `.claude/settings.local.json` is found.
2. Load the kit's MCP allowlist:
   - Primary: `mcp-tiering.md` server-tier table (rows: `playwright`, `postgres`, `github`, `memory`, `filesystem`, `fetch`, `sequential-thinking`).
   - Plus: `m-main/common/permission-servers.ts:16-21` (`PERMISSION_SERVERS` registry: `filesystem`, `playwright`, `shell`, `workiq`).
   - Plus: per-kit overrides if `--allowlist-file` was passed.
3. Load the URL validator from `m-main/common/mcp-url-validation.ts:20-46`.

### Step 1 — Read settings.json `mcpServers` block

For each entry in `settings.json:mcpServers.<name>`:

1. Record `name`, `type` (local|remote), `command` or `url`, `args`, `tools`.
2. If `type: remote` (URL-based): pass through to URL validator (Step 2).
3. If `type: local` (command-based): pass through to command-source validator (Step 3).
4. Look up `name` in the allowlist (Step 0 result).

### Step 2 — URL validation (per `m-main/common/mcp-url-validation.ts:20-46`)

Apply each rule in order:

| Rule | Source | Reject reason |
|---|---|---|
| Must be parseable by `new URL()` | `mcp-url-validation.ts:22-24` | "Invalid URL format." |
| Scheme must be `http:` or `https:` | `mcp-url-validation.ts:28-34` | `"<scheme>://" URLs are not allowed. Use https:// (or http://localhost for local servers).` |
| `http://` is only allowed for `localhost`, `127.0.0.1`, `[::1]` | `mcp-url-validation.ts:36-43` (`LOCALHOST_HOSTNAMES` set) | "http:// is only allowed for localhost. Use https:// for remote servers." |

When `--strict-https` is set, rule 3 is replaced by: "http:// is rejected unconditionally; localhost MCP servers must run https with self-signed cert." Use only for high-stakes deployments where localhost trust is not assumed (multi-user dev boxes).

Result: emit `{ok: true, isLocalhost: bool}` or `{ok: false, reason: "<reason>"}` per `m-main/common/mcp-url-validation.ts:6` (`McpUrlValidation` type).

### Step 3 — Command-source validation (local servers)

For `type: local`:

1. The `command` field MUST be a known package manager invocation (`npx`, `uvx`, `pip`, `pipx`, `npm`, `node`, `python`, `pwsh`, `powershell.exe`) OR a path to an executable in a kit-known location.
2. The first `args[0]` MUST resolve to a known package or local file. Do NOT auto-install.
3. The args MUST NOT contain shell metacharacters (`|`, `;`, `&&`, `&`, `$()`, backticks) — the runtime spawns the command directly; metacharacter injection in args is a Tampering vector per `stride-threat-model.md` § Tampering.
4. If the package is from `npx @namespace/package`, verify the namespace is in the kit's npm-namespace allowlist (e.g., `@playwright`, `@modelcontextprotocol`, etc.). Reject unknown namespaces with severity SHOULD-FIX (user can override with documentation).

### Step 4 — Tier-policy check

Per `mcp-tiering.md`:

1. Look up the registered server in the kit's tier table.
2. If the table classifies it as `cli`-tier: warn if it's loaded into context (i.e., schema is loaded at session start). Per `mcp-tiering.md` paragraph 5, schema loading happens regardless of CLI-tier classification — the tier is a call-time guard only.
3. If the server is `context-tier` (max 5 servers): check that the total count of `context-tier` MCPs in settings.json is ≤5. Emit BLOCKING if exceeded.
4. If the server is unknown to the tier table: emit MUST-FIX "tier classification missing — add to mcp-tiering.md before commit."

### Step 5 — STRIDE delta

Per `stride-threat-model.md`, every new MCP registration is a privilege-elevation surface. Apply the per-feature threat-model requirement:

| Category | New MCP entry expands? | Mitigation |
|---|---|---|
| Spoofing | Possibly (if URL points to a domain the user doesn't control) | URL validator + allowlist check |
| Tampering | Possibly (if command args contain shell metacharacters) | Step 3 rule 3 |
| Repudiation | No | — |
| Information Disclosure | Yes (MCP can read filesystem/network) | Allowlist + tier classification + tool-list audit |
| DoS | Possibly (a misconfigured remote MCP can hang the runtime) | URL validator (timeouts handled at runtime, not at registration) |
| Elevation of Privilege | **Yes** (this is the primary risk) | Allowlist gate + tier classification + `dangerous-operations-policy.md` § Least-privilege default |

If any row says "Yes" with no documented mitigation: emit BLOCKING.

### Step 6 — Tools-list audit

For each MCP server, audit the `tools` array:

1. `tools: ["*"]` (wildcard) is REJECTED per `dangerous-operations-policy.md` § Least-privilege default rule 1 (wildcard `allowed-tools` is rejected at review — same principle applies to MCP tool exposure).
2. Each named tool MUST exist in the server's documented capability surface. The skill cannot verify this at registration time without invoking the server (static validation only — runtime concern); flag as INFO "tool capability not statically verifiable; runtime will reject unknown tools."
3. If a server exposes a known privileged tool (e.g., `filesystem.write_file`, `shell.execute`) AND the consumer kit's policy is `untrusted-content` (per `prompt-injection-policy.md` Scope), emit SHOULD-FIX recommending tier downgrade to `cli`.

### Step 7 — Drift check (mode = drift-check)

Compare `settings.json:mcpServers.<name>` against `mcp-tiering.md` per-row:
1. Missing in settings.json but present in tier table: emit "registered in policy but not in runtime — add or remove from policy table."
2. Present in settings.json but missing from tier table: emit "registered at runtime but no tier classification — required for least-privilege audit."
3. Tier in settings.json metadata (if present) disagrees with tier-table value: emit "tier drift — reconcile."

### Step 8 — Synthesize report

Emit:

```markdown
# mcp-permission-validate report — <ISO timestamp> — mode=<mode>

## Summary
- Servers checked: N
- BLOCKING: B
- MUST-FIX: M
- SHOULD-FIX: S
- INFO: I

## Findings
| # | Severity | File | Line | Setting-path | Server | Field | Rule | Detail |
|---|---|---|---|---|---|---|---|---|
... one row per finding; `File` is the absolute settings.json path; `Line` is the source line number where the offending entry is declared (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE — every finding cites file:line evidence); `Setting-path` is the JSON-pointer-style path to the offending value (e.g. `mcpServers/my-custom/url`) — equivalent to file:line for the JSON target so consumers can navigate directly to the violation ...

## STRIDE delta
| Category | Expands? | Mitigation |
... 6 rows per `stride-threat-model.md` ...

## Recommended actions
- BLOCKING > 0: do not commit settings.json; fix or remove offending entries
- MUST-FIX > 0: tier classifications missing; update mcp-tiering.md before commit
- SHOULD-FIX > 0: review for least-privilege downgrades
- INFO > 0: documentation gaps; consider before next QSR
```

When ALL categories produce zero findings: state explicitly "No findings — all MCP entries pass allowlist, URL, tier, and STRIDE checks."

### Step 9 — `register` mode consent gate

When `--mode register`: per `dangerous-operations-policy.md` § Operation categories, registering a new MCP is **NOT** in the canonical category list, but it functions as an **External Tool Install** (modifies the runtime's tool surface). Emit consent prompt:

```
About to register MCP server:
  Name:    <name>
  Type:    <local|remote>
  URL/Cmd: <url-or-command>
  Tier:    <claimed-tier>
  Tools:   <count>
  Allowlist: <ok|missing>
  STRIDE:    <ok|expanded>
Proceed? (yes/no)
```

On `no` or timeout: refuse registration, log to `<channel>/consent-log.jsonl` if a channel is active.

### Step 10 — Exit codes

| Code | Meaning |
|---|---|
| 0 | All checks pass; no findings |
| 1 | Findings exist; mode=audit/drift-check; no destructive action taken |
| 2 | mode=register; entry passed all checks AND user confirmed |
| 3 | mode=register; user refused OR consent timeout |
| 4 | Read failure / preflight rejection |
| 5 | BLOCKING findings; explicit failure (CI mode) |

## `--copilot` mode

This skill does NOT implement `--copilot` mode by default. The validation logic is deterministic (allowlist lookup, URL parser, regex match) — cross-model agreement adds no signal.

**Exception**: when proposing a NEW entry to the kit's MCP allowlist (i.e., the operator wants to whitelist a previously unknown MCP server in `mcp-tiering.md`), `--copilot` MAY be invoked per `lens-multi-model-review-pattern.md` (high blast-radius per `prescriptive-content-review.md` Gap 5: editing a kit-wide allowlist affects every consumer downstream). In that case, follow the inherited contract from `lens-multi-model-review-pattern.md`: orchestrator spawns Task subagent → subagent invokes the dispatcher → cross-model agreement table on whether the proposed allowlist entry is safe → both-flag-CRITICAL → hard block.

The synthesis lens for that escalation: "Does this MCP server's claimed capability surface match its actual tool exposure, and does that exposure violate the consumer kit's threat model?"

`tier-target: A` with `tier-exempt: [evals, templates]` per `skill-standards.md` § Pure-utility exemption:

- **Dim 4 (evals) exempt** — mcp-permission-validate is a pure-utility validator; the eval shape IS this SKILL.md's mechanical contract (the URL validator rules from `m-main/common/mcp-url-validation.ts:20-46` + the allowlist from `m-main/common/permission-servers.ts:16-21` + the tier table from `mcp-tiering.md`). Upstream test files `m-main/common/permission-servers.test.ts` and `m-main/common/mcp-url-validation.test.ts` carry the canonical assertion shapes; duplicating fixtures here would re-test the upstream primitives, not this skill's orchestration glue. The `Eval discipline` section below documents fixtures that WOULD apply for future Tier-S authoring; until then the upstream coverage is the floor.
- **Dim 5 (templates) exempt** — output is a structured findings table not authored artifacts; no template needed. The report shape (Step 8) is inline in this SKILL.md as a literal markdown template; consumers render the table from the inline shape.

The remaining 4 dimensions are present in full: frontmatter (Dim 1), Best Practices section (Dim 2), Standards section (Dim 3), and Dim 6 conditionally (the `--copilot` exception path above for allowlist edits).

## Eval discipline

When this skill ships with evals (Dimension 4 of `skill-standards.md`), fixtures live at `.claude/skills/mcp-permission-validate/evals/`:

- `evals/fixtures/clean.json` — synthetic settings.json with three known-good MCP entries; expected zero findings.
- `evals/fixtures/unknown-server.json` — entry not in allowlist; expected one BLOCKING finding.
- `evals/fixtures/http-non-localhost.json` — entry with `http://10.0.0.5/`; expected one BLOCKING URL finding.
- `evals/fixtures/wildcard-tools.json` — entry with `tools: ["*"]`; expected one BLOCKING tools-list finding.
- `evals/fixtures/shell-metachar.json` — local entry whose args contain `&&`; expected one BLOCKING command-source finding.
- `evals/fixtures/tier-drift.json` — server registered in settings.json but missing from `mcp-tiering.md`; expected one MUST-FIX finding (drift-check mode).
- `evals/fixtures/context-tier-overflow.json` — six servers all classified `context-tier`; expected one BLOCKING tier-policy finding.

Reference: `m-main/common/permission-servers.test.ts` and `m-main/common/mcp-url-validation.test.ts` for upstream assertion shapes.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Auto-add unknown servers to the allowlist on first use | Bypasses STRIDE elevation-of-privilege gate | Emit BLOCKING; require explicit allowlist update + re-run |
| Treat `http://192.168.x.x` as localhost | LAN-private isn't loopback; threat model differs | Use `m-main/common/mcp-url-validation.ts:9` (`LOCALHOST_HOSTNAMES = {localhost, 127.0.0.1, [::1]}`) literally |
| Validate at runtime instead of at registration | Errors surface late, after the server is loaded | Validate at PreToolUse:Write of settings.json (kit-side hook) AND on explicit user invocation |
| Trust `tools: ["*"]` because the server "is well-known" | Wildcard breaks least-privilege per `dangerous-operations-policy.md` § Least-privilege default | Reject unconditionally; require explicit tool list |
| Parse URLs with regex | URL parsing has 100+ edge cases (auth, IPv6, percent-encoding) | Use `new URL()` per `m-main/common/mcp-url-validation.ts:22-24` |
| Apply `--strict-https` as default | Breaks legitimate localhost MCP usage | Localhost over `http://` is allowed by design; opt-in only |
| Skip STRIDE delta for "obvious" servers like filesystem | Filesystem MCPs ARE the highest-risk class (information disclosure + tampering surface) | Run all 6 STRIDE rows per `stride-threat-model.md` |
| Hard-code the allowlist instead of reading `mcp-tiering.md` | Allowlist drift between scanner and policy | Tier table in `mcp-tiering.md` is source of truth; cite at scan time |
| Treat `mcp-tiering.md` and `m-main/common/permission-servers.ts` as competing sources | They cover different concerns: tiering = call-time guard; permission-servers = capability registry | Both are read; precedence is `mcp-tiering.md` > `permission-servers.ts` for tier classification |

## Best Practices

This skill inherits the kit-wide best practices from `.claude/rules/skill-standards.md` § Dimension 2:

- **FETCH BEFORE CITE** — read source files before claiming behavior; never reference a function or contract without opening it (per `rules/verification-protocol.md`). The URL validator behavior is sourced from `m-main/common/mcp-url-validation.ts:20-46`; the permission-server registry from `m-main/common/permission-servers.ts:16-21`. Cite file:line on all claims.
- **Anti-hallucination** — when a category produces no findings, state "No findings" explicitly. Do not pad the STRIDE delta with reassurance prose for categories that genuinely don't expand.
- **Output Contract** — every finding carries: severity tag (BLOCKING / MUST-FIX / SHOULD-FIX / INFO) + server name + field (URL / command / tools / tier) + cited rule + recommended action.
- **Confidence floor** — BLOCKING findings on URL/scheme/allowlist are deterministic (regex/lookup match). STRIDE findings emit at confidence ≥70 (MUST-FIX) when a category expands without documented mitigation; ≥50 (SHOULD-FIX) when mitigation is documented but partial.
- **Existing-thread dedup** — re-scanning the same settings.json suppresses findings already acknowledged via `// noqa: mcp-permission-validate: <reason>` directive in a sidecar `.mad/scratch/mcp-permission-validate-suppressions.jsonl` file.
- **WorkIQ context** — N/A; this skill operates on local config with no external work-item linkage.
- **Auto-fan-out** — when a single settings.json has 5+ unknown-server findings, the file is likely a different-kit migration; READ the source kit's `mcp-tiering.md` (if present) before classifying each as BLOCKING — there may be legitimate cross-kit servers that should be added to this kit's allowlist.

Skill-specific best practices:

- **Allowlist is the gate**: `mcp-tiering.md` server-tier table + `m-main/common/permission-servers.ts:PERMISSION_SERVERS` are the union allowlist. Anything outside requires explicit user opt-in via `--allowlist-file` override.
- **Localhost-over-http is allowed by design** (per `m-main/common/mcp-url-validation.ts:36-43`); resist requests to make `--strict-https` the default — it breaks legitimate dev-loop MCP usage.
- **Wildcard tools list is unconditionally rejected** (per `dangerous-operations-policy.md` § Least-privilege default rule 1). Do not soften.
- **STRIDE rows are mandatory output**: per `stride-threat-model.md` § Per-feature threat-model requirement, every MCP registration emits 6 STRIDE rows. Skipping rows because "obviously not applicable" is the failure mode the rule exists to prevent.
- **Drift-check is the QSR audit path**: `--mode drift-check` is the canonical input to `operations/quarterly-review.md §Rules/policy drift`; runs of this mode produce the audit-trail evidence for tier-classification health.
- **No execution of MCP server code**: the skill is purely static validation. Even when `--mode register` is set, the skill does NOT spawn the proposed command to verify it works — that's runtime concern.

## Standards

This skill inherits these load-bearing rules:
- `.claude/rules/non-negotiable-rules.md` — verb-bound permission fences (no destructive ops without consent; wildcard `allowed-tools` always rejected)
- `.claude/rules/verification-protocol.md` — FETCH BEFORE CITE (cite m-main file:line on every behavioral claim)
- `.claude/rules/mcp-tiering.md` — server tier table is the source of truth for context-tier vs cli-tier classification; this skill enforces against it
- `.claude/rules/dangerous-operations-policy.md` — § Least-privilege default (wildcard tools rejected); § External Tool Install consent gate for `--mode register`
- `.claude/rules/prompt-injection-policy.md` — substrate; an MCP server is a privilege surface that COULD be a Rule-1 attack vector if compromised
- `.claude/rules/stride-threat-model.md` — every new MCP registration emits a 6-row STRIDE delta; § Per-feature threat-model requirement
- `.claude/rules/skill-standards.md` — 6-dimension compliance (Dimensions 1, 2, 3 mandatory; Dimensions 4, 5 recommended; Dimension 6 conditional on allowlist edits)

Naming:
- `mcpServers.<name>` is the canonical settings.json shape (same as the m-main `.copilot/mcp-config.json` structure verified at `m-main/.copilot/mcp-config.json:2`).
- Tier classification names `context-tier` and `cli-tier` are sourced from `mcp-tiering.md` paragraph 4-5 ("Context-tier: <5 tools, frequent use, loaded into context. Max 5 servers." / "CLI-tier: >10 tools or infrequent.").
- Severity tags `BLOCKING / MUST-FIX / SHOULD-FIX / INFO` follow the kit-wide `pr-review/templates/review-findings.md` shape.

## References

- `m-main/common/permission-servers.ts:16-21` — `PERMISSION_SERVERS` registry; canonical built-in capability list (`filesystem`, `playwright`, `shell`, `workiq`).
- `m-main/common/permission-servers.ts:42-61` — `buildDisabledDisplayNameSet()`; pattern for collapsing user-disabled and tenant-disabled servers; reused as the structural template for `--allowlist-file` override merging.
- `m-main/common/permission-servers.ts:64` — `MCP_SERVER_CONFIG_KEYS` set; canonical "is this an MCP tool provider" classifier.
- `m-main/common/permission-servers.ts:81-115` — `SAFE_COMMAND_CATEGORIES`; reference for what counts as a read-only shell prefix (used by Step 3 rule 1 source classification).
- `m-main/common/mcp-url-validation.ts:6` — `McpUrlValidation` type; canonical result shape.
- `m-main/common/mcp-url-validation.ts:9` — `LOCALHOST_HOSTNAMES`; literal allowlist (`localhost`, `127.0.0.1`, `[::1]`).
- `m-main/common/mcp-url-validation.ts:20-46` — `validateMcpUrl()`; the URL validation Rule 1, 2, 3 reference.
- `m-main/common/extensions-catalog/index.ts:5-7` — `EXTENSIONS_CATALOG`; the upstream pattern for combining skill + MCP-server entries into a single ingestion catalog. Inform downstream `claude-md-refresh` integration.
- `m-main/.copilot/mcp-config.json:2` — canonical `mcpServers` shape verified against upstream config.
- `.claude/rules/mcp-tiering.md` — tier table source of truth.
- `.claude/rules/dangerous-operations-policy.md` § Least-privilege default rule 1, § External Tool Install — consent + wildcard rejection.
- `.claude/rules/stride-threat-model.md` § Per-feature threat-model requirement — 6-row STRIDE delta contract.
