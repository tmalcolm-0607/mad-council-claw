# Pattern: Preflight Dependency Checks

**Canonical name:** Preflight Checks. Variants: *sanity check*, *smoke test*, *health probe*, *startup verification*.

**One-line definition:** Before any state-mutating operation runs, verify each declared dependency with a fast, read-only probe. Report pass/fail/degrade per dependency and only proceed if required dependencies pass.

## When to use

- Skills that have external dependencies (MCP servers, CLI tools, filesystem paths, environment variables).
- First-run / first-use operations where a missing dependency would be painful to discover late.
- Long-running operations whose first step has no side effects but whose later steps do — verify the whole chain upfront.
- Any `/council-open` or `/council-join`-class command (one-shot entry points).

## When NOT to use

- High-frequency inner-loop calls — preflight overhead adds up. Probe once at session start, not every call.
- Operations that are themselves preflights — infinite regress.
- Operations where the dependency check IS the operation.

## Core mechanics

```
1. Declare dependencies (name, check command, required/recommended/optional, on-failure action)
2. Probe each dependency in parallel (they're independent read-only checks)
3. Render a preflight report to the user
4. If any Required: Yes dependency failed → STOP with clear error
5. If any Required: Recommended/Optional failed → WARN, continue with degraded mode
6. If all pass → proceed to operation
```

The key is that step 1 is **declarative**, not ad hoc. A skill with 6 dependencies has a 6-row table, not 6 scattered "if available" checks throughout the code.

## Canonical format

Lifted verbatim from `plugins/zen-agents/agents/system-design-author.md`:

```markdown
| Dependency | Check Command | Required | On Failure |
|------------|---------------|----------|------------|
| **PowerShell 7+** | `$PSVersionTable.PSVersion.Major -ge 7` | Yes | Stop; provide install link |
| **Node.js v18+** | `node --version` | For diagrams | Warn; diagram generation unavailable |
| **npm** | `npm --version` | For diagrams | Warn; cannot install mermaid-cli |
| **@mermaid-js/mermaid-cli** | `npx mmdc --version` | For diagrams | Warn; will auto-install with user consent |
| **Vendor Docs MCP** (e.g. Microsoft Learn, AWS Docs) | Attempt test MCP call | Recommended | Warn; design decisions can't be validated |
| **WorkIQ MCP** | Attempt test MCP call | Optional | Warn; skip organizational context |
```

The four columns are non-negotiable. Each has a specific role:

- **Dependency**: human-readable name.
- **Check Command**: the actual probe. Must be fast (<2s) and read-only.
- **Required**: `Yes` / `Recommended` / `Optional` / or a conditional like "For diagrams."
- **On Failure**: the action. `Stop`, `Warn`, `Warn + auto-install with consent`, etc.

## Output format

Render a preflight report to the user. Canonical style:

```
Preflight Checks for /council-open es-training:

  ✅ ~/claude-data/channels/ writable
  ✅ CronCreate tool available
  ⚠️ Clock skew 4m 12s behind UTC — archive timers may be slightly off
  ✅ A2A bridge reachable at https://localhost:8222
  ❌ MAD workflow unavailable — plugins/dotnet-dev-kit not found

  Result: 3/5 OK, 1 warning, 1 failure.

  MAD integration will be disabled for this channel.
  Proceed with channel creation (without MAD)? (yes/no)
```

Icons: ✅ pass · ⚠️ warn · ❌ fail. The icons are not cosmetic — they're scannable.

## Common implementations

### Marketplace: zen-agents/system-design-author (canonical)

Six-row table, pre-flight runs once per session at first invocation. Warns on missing optional deps (Node.js, mermaid-cli, WorkIQ MCP). Stops on missing required (PowerShell 7+). Offers consent-gated auto-install for mermaid-cli.

- **Pros**: Comprehensive; user sees what's available at the start, not mid-operation.
- **Cons**: Noisy on first run in environments that don't need diagrams.

### Marketplace: zen-agents/peer-reviewer

Narrower preflight (Git, PowerShell 7+, ADO MCP, Azure CLI). Stops if ADO MCP unavailable.

### Marketplace: retro-ai

Checks for ICM MCP + Kusto MCP + WorkIQ MCP. Falls back to pasted-content mode if all MCPs are down.

### Linux `startup.d` / systemd pre-start ExecStartPre

System-level analog. A failed ExecStartPre aborts the service start. Same principle: verify the environment before the workload.

### Docker HEALTHCHECK + Kubernetes liveness/readiness probes

Runtime analog. Health probes run continuously; preflight runs once at entry. Different cadence, same intent.

## Pros

- **Fail-fast**: user learns about a missing dependency in 2 seconds, not 20 minutes into an operation.
- **Explicit degradation**: the warning tells the user exactly what's limited.
- **Deterministic failures**: "PowerShell not found" is a clear message; "mysterious error on step 14" is not.
- **Documentation as code**: the preflight table IS the skill's dependency documentation.
- **Consent-gated auto-install**: preflight surfaces the "need to install X" at a moment when asking is appropriate.

## Cons

- **First-run cost**: 2-5 seconds of preflight before any work starts. Feels slow on the first call.
- **Overhead for frequent operations**: if preflight runs every call, it dominates latency. Mitigate with "once per session" caching.
- **Stale results**: if a dependency comes up after preflight runs, the skill stays in degraded mode. Refresh requires a new session or explicit `--refresh-preflight`.
- **False warns**: a network blip during the probe can cause a false "unavailable" — user needs a way to re-probe.

## Do / Don't

**Do**:

- **Run preflight once per session** (not per call). Cache results.
- **Parallelize probes** — independent dependencies, no serialization required.
- **Make each probe <2 seconds** — otherwise preflight overhead becomes a UX problem.
- **Use read-only probes** — never modify state in a preflight.
- **Provide an explicit install command in the failure message** — "Install from https://nodejs.org" or "Run `dotnet tool install -g mermaid-cli`."
- **Declare required vs recommended vs optional** — not every missing dep is a hard stop.
- **Emit a consent prompt for auto-install** — never silently install.
- **Render with icons** — ✅⚠️❌ — scannable at a glance.
- **Include in Context Gaps** (`degradation-fallback-policy.md` Rule 3) — a warn-level preflight result is a context gap.

**Don't**:

- **Don't check every dep on every call** — session-cache the preflight result.
- **Don't silent-fail in degraded mode** — the user must see the warning.
- **Don't block on optional deps** — their whole point is optional.
- **Don't probe with the real operation** — e.g., probing A2A by actually sending a task. Use a lighter probe like HTTP HEAD.
- **Don't conflate preflight with runtime health** — preflight is one-time at entry; runtime health is continuous monitoring (different pattern: circuit breakers).
- **Don't probe dependencies that aren't actually used** — false dependencies bloat preflight and confuse users.

## Interaction with other patterns

- **+ `circuit-breakers.md`**: preflight handles "unavailable at start"; breakers handle "went down mid-operation." Complementary.
- **+ `degradation-fallback-policy.md`**: preflight warnings are Context Gaps for the Rule-3 report.
- **+ `dangerous-operations-policy.md`**: auto-install found during preflight is a Package-Install operation → consent prompt.
- **+ `per-operation-retry-tables.md`**: preflight probes themselves have a retry table (typically zero-retry; a failed probe is a failed probe).

## MAD.Council specifics

All `/council-open` and `/council-join` invocations run preflight per `mad.council.a2a.md` §10.3:

| Dependency | Check | Required | On Failure |
|---|---|---|---|
| `~/claude-data/` writable | Test-Path + write test | Yes | Stop with explicit path-permission error |
| CronCreate tool available | ToolSearch `select:CronCreate` | Yes (for polling mode) | Warn; offer manual-check mode |
| Clock within 60s of UTC | `Get-Date` vs HTTP Date header | Recommended | Warn; timestamps skewed |
| A2A bridge reachable | HTTP HEAD to `a2a_endpoint_url` if declared | Optional | Warn; local-only mode |
| MAD prerequisites | Check for `plugins/dotnet-dev-kit` | Optional | Warn; MAD layer disabled |

Results are rendered per §10.3 format and require explicit user consent before any state creation.

## References

- `plugins/zen-agents/agents/system-design-author.md` "Preflight Checks (Run on First Invocation)" — canonical source.
- `plugins/zen-agents/agents/peer-reviewer.md` — variant for PR review context.
- `plugins/retro-ai/skills/retro-ai/SKILL.md` — variant for multi-MCP context.
- systemd ExecStartPre documentation — https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Kubernetes liveness/readiness probes — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes
- `mad.council.a2a.md` §10.3 — spec section.
- CHECKLIST pattern #64 — preflight dependency check table source.
