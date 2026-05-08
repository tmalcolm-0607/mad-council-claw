# Environment tiers for MAD channels

MAD channel data is **not** uniformly trusted. A channel on a developer's laptop running exploratory evals carries a different risk profile than one in CI running release-gate verdicts, which in turn differs from one in production running A2A-federated councils against 1P services. This doc establishes three formal tiers and the per-tier guardrails that every skill MUST enforce.

**Source:** internal engineering standards docs (service-environment guidance — test / PPE / Prod model with per-tier security bars). Adopted via **ADOPT-004**.

## The three tiers

| Tier | Maps to | Channel storage | Typical caller | Trust model |
|---|---|---|---|---|
| **`local`** | a test env | `~/claude-data/channels/` on developer workstation | Developer running `/council-*` interactively | Isolated; no cross-tenant data; failures visible to one human |
| **`ci`** | a PPE env | Ephemeral container filesystem under CI working dir; torn down post-run | CI runner (GitHub Actions / Azure Pipelines) executing `evals/run-evals.ps1` | Shared runtime but isolated per-job; failures block merges but don't affect end users |
| **`prod`** | a Prod env | Durable filesystem backing an A2A bridge / managed runtime | Automated orchestrator calling into the MAD council to resolve a live decision | Customer-facing; failures are incidents; requires lockbox-equivalent approval for destructive acts |

Channels declare their tier once at creation via `channel.json:environment_tier` (enum `local | ci | prod`). Skills read the tier on every invocation and apply the gates below.

## Per-tier gates

### `local`

- All skills enabled.
- No AskUserQuestion for read-only ops.
- `rules/dangerous-operations-policy.md` confirmations still apply for destructive acts but may be auto-approved via `--force` when the invoker is also `owner_alias`.
- Rate limits per `operations/rate-limits.md` use the relaxed developer budget.
- A2A bridge disabled by default (`settings.a2a_enabled=false`); can be enabled per-channel for local federated testing.

### `ci`

- All skills enabled.
- AskUserQuestion prompts REJECT by policy — CI has no interactive channel. Skills MUST degrade to exit-code + log per `rules/degradation-fallback-policy.md`; any skill that blocks on confirmation in CI is a defect.
- `rules/dangerous-operations-policy.md`: destructive acts refuse to run unless `--ci-preauth` is passed along with a literal preview hash that matches the expected action, per the same doc's §6 machine-confirm pattern.
- Rate limits apply the CI budget (stricter than `local`; looser than `prod`).
- A2A bridge: in `ci`, only permitted against `evals/fixtures/a2a-mock/` — never real endpoints.
- `council-retro` required at end of every CI job; retros with `outcome = fail` break the CI gate.

### `prod`

- **Destructive acts require ownership.** Non-`owner_alias` invocation of any `rules/dangerous-operations-policy.md` category triggers `OWNER_REQUIRED` exit code even if the skill otherwise has write access. See `rules/single-owner-accountability.md`.
- **Destructive acts additionally require two-stage approval (ADOPT-034).** Archival, ownership transfer to a new alias, channel deletion, bulk resolve all require a second consenting session distinct from the owner's. See `rules/dangerous-operations-policy.md §Two-stage approval for prod destructive acts`.
- **Ownership transfers require verdict.** Implicit owner reassignment forbidden (same rule).
- **Session-id mismatch is fatal.** In `local`/`ci`, mismatch triggers warn + circuit-breaker; in `prod`, mismatch triggers immediate reject + lockout of the mismatching session for the channel's remaining lifetime + alert via `council_post.session_mismatch_total` counter (per `metrics/safety-metrics.md`).
- **A2A bridge requires auth on every hop** — anonymous Agent Cards rejected.
- **Bulk operations over N > 10** require a preview + explicit AskUserQuestion confirmation from the `owner_alias` session, even with `--force`.
- **`council-retro` is mandatory** after any `FIX` or `FAIL` verdict; `retro.outcome_assessment` is consumed by `metrics/reliability-metrics.md`.
- **All messages signed** (Phase-4 deliverable; until then, `prod` channels MUST NOT be bridged to untrusted organisations).
- Rate limits apply the Prod budget (strictest).

## Cross-tier data flow

| From → To | Allowed? | Mechanism |
|---|---|---|
| `local` → `ci` | Yes, as read-only fixture import | `evals/fixtures/` vendoring; never runtime read of a `local` channel from CI. |
| `local` → `prod` | No | Dev data is not production-safe; require a formal promotion step with PII scrub + owner-transfer verdict. |
| `ci` → `prod` | No | CI is ephemeral; promotion requires a dedicated Phase-1 deliverable (`operations/migration-strategy.md §CI→Prod`). |
| `prod` → `ci` | Yes, with redaction | Used to reproduce a prod incident locally; MUST pass through a redaction step per `operations/privacy-data-governance.md §Redaction`. |
| `prod` → `local` | Yes, with redaction + explicit developer acknowledgement | Incident triage use case; the developer sees a banner that reads "You are viewing redacted prod data — do not re-upload." |

## Schema enforcement

`schemas/channel.schema.json` MUST carry `environment_tier: { enum: ["local", "ci", "prod"] }` as a required field. Channels created before this enum lands default to `local` on read-with-migration; write-back MUST upgrade the schema atomically.

## What's shared, what's isolated (ADOPT-035)

Derived from internal engineering standards docs (`environments.md`) — PPE and Prod share identity (first-party app registration, centralized telemetry account, service tags) but isolate cloud subscriptions and infrastructure. MAD's analogue across tiers:

| Concern | `local` | `ci` | `prod` | Shared or isolated? |
|---|---|---|---|---|
| `rules/*.md` content | same | same | same | **Shared** — one source of truth, all tiers read the same files |
| `wiki/patterns/*.md` content | same | same | same | **Shared** |
| `schemas/*.schema.json` | same | same | same | **Shared** — tier MAY tighten at skill level, never at schema level |
| Channel state (`~/claude-data/channels/<name>/`) | dev workstation | ephemeral CI FS | durable prod FS | **Isolated** — no cross-tier reads at runtime |
| `owner_alias` scope | per-channel | per-channel | per-channel | **Isolated per-channel** (and per-tier, since channel state is isolated) |
| `operations/rollout-log.md` | N/A | shared | shared | **Shared** — a kill-switch flip applies across `ci` + `prod` |
| `operations/kill-switches/*.json` | read-only | read-only | read-only | **Shared** — single source, multi-tier consumption |
| `metrics/*` counter emission | none | emitted | emitted | **Shared counter names, isolated samples** — `council_post.session_mismatch_total` is the same counter everywhere but each channel's samples live in its own tier's storage |
| `consent-log.jsonl` | per-channel | per-channel | per-channel | **Isolated** |

**Invariant:** rules and patterns are shared to prevent per-tier divergence (a prod-only rule modification is a red flag — flag at review). State is isolated to prevent accidental cross-tier data leakage. `prod` → `local` import is allowed only via the redaction pipeline per `operations/privacy-data-governance.md`.

## How skills detect tier

```powershell
# Pattern every SKILL.md references
$channel = Read-Channel -Path $ChannelPath
$tier = $channel.environment_tier ?? 'local'   # defensive default

switch ($tier) {
    'local' { # relaxed }
    'ci'    { # non-interactive — reject AskUserQuestion }
    'prod'  { # owner-gated, session-strict }
    default { throw "UNKNOWN_ENVIRONMENT_TIER: $tier" }
}
```

No skill may infer the tier from filesystem location or environment variable — the channel itself is authoritative. Lying about tier (e.g., editing `channel.json` to downgrade `prod` → `local` to bypass gates) is a tampering attack and is tested in `evals/layer-4-adversarial.md`.

## Related

- `schemas/channel.schema.json` — `environment_tier` enum.
- `rules/dangerous-operations-policy.md` — per-tier consent rules.
- `rules/single-owner-accountability.md` — `prod` ownership gate.
- `rules/degradation-fallback-policy.md` — `ci` non-interactive behaviour.
- `operations/migration-strategy.md` — cross-tier promotion.
- `operations/privacy-data-governance.md` — prod-to-local redaction.

## Open questions

- **Staging tier?** the ecosystem has test / PPE / Prod (three); this doc collapses to `local | ci | prod`. A `staging` tier between `ci` and `prod` may be warranted if MAD ever gets a pre-production soak environment. Leave as a Phase-4 discussion — add the enum value only when a concrete use case forces it (YAGNI per `wiki/patterns/yagni-filter.md`).
