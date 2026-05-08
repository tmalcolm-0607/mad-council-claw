# Privacy & Data Governance

This document defines what data MAD.Council processes, how it's classified, how long it's kept, where it can be stored, and what rights data subjects have. It is a **reference posture** — not a certification. Final compliance for any specific deployment (GDPR, HIPAA, SOX, FedRAMP) is the deploying org's responsibility and must be reviewed with qualified counsel.

## Scope

Everything MAD.Council reads, writes, transmits, or exposes to its telemetry pipeline. That includes:

- Channel / thread / message content (authored by humans + agents).
- MAD artifacts (`spec.md` / `plan.md` / `tasks.md` / `verdict.json`).
- Retro responses (`retros/*.json`).
- Completion Reports (emitted by `/council-leave`).
- Agent Cards + member records (channel.json).
- Session registry (`.sessions.json`).
- Telemetry spans + counters (OTel pipeline).
- External calls (upstream LLM providers, A2A bridges, ALAS).

Out of scope: the deploying org's own data-handling policies, legal basis for processing, DPIA authoring, data-controller-vs-processor designation. MAD ships a **position**; the org decides **obligations**.

## Data classification

Everything MAD touches falls into one of four tiers:

| Tier | Examples | MAD handling |
|---|---|---|
| **P0 — Public** | `wiki/`, `rules/`, spec, this doc, any code in `plugins/` | No special handling; freely loggable. |
| **P1 — Internal** | Channel metadata, alias, session_id, thread IDs, sequence numbers, verdict types, timestamps | OS permissions; per-user isolation. Loggable but scrubbed of tier-P3 content. |
| **P2 — Confidential** | Message bodies, MAD artifacts, retro prose, Completion Report narratives, Agent Card descriptions | OS permissions; backup encrypted (user's responsibility); NOT emitted to telemetry in body form — only sizes/counts. |
| **P3 — Sensitive / Regulated** | Accidental PII (names, SSNs, API keys) pasted into message bodies; regulated content (health records, financial records, trade secrets) | Same storage as P2; **plus** the user is responsible for detecting + redacting before posting. MAD provides **no automatic PII scrubbing in Phase 1**. |

**Key honesty:** Phase 1 does not detect or scrub PII. A user who pastes `"Alice's SSN is 123-45-6789"` into a message body gets it stored verbatim. We treat that as a user responsibility, log the gap explicitly in `skills/council-retro/tests.md T4-05`, and flag it in the retro's `non-goal` section.

Phase 5 may add opt-in PII scanners (open-source options include Presidio, spaCy NER + regex patterns) — tracked as a Phase-5 deliverable if user demand justifies the complexity.

## What MAD processes vs stores vs transmits

| Data | Processed | Stored locally | Transmitted |
|---|---|---|---|
| Message body | Yes (literal-phrase scan + model brief) | Yes (`messages/*.json`) | To LLM providers via brief (for `/council-review` only) |
| Alias + session_id | Yes (binding check) | Yes (channel.json) | Only in Agent Card when A2A-bridged |
| Retro prose | Yes | Yes (`retros/*.json`) | Optionally to ALAS when consented |
| MAD artifacts | Yes (model-assisted drafting in Phase 3+) | Yes (channel root) | To LLM providers on drafting |
| Channel metadata | Yes | Yes (channel.json) | Optionally to A2A bridge (Phase 4) |
| Completion Reports | Yes | Yes (`reports/*.json` + log) | Not transmitted automatically |
| Telemetry (OTel) | Yes | No (streamed to collector) | To collector (Datadog / Grafana / local file) |

Every row is a **data flow**, each requiring a lawful basis and a retention rule. The user / operator must map each to their legal regime.

## Retention

Default retention matches `operations/backup-disaster-recovery.md` §Retention policy. Restated here with legal-posture rationale:

| Data | Active retention | Cold retention | Rationale |
|---|---|---|---|
| Active channels | Until explicitly left / archived | — | Live working state; user controls. |
| Archived channels | 2 years | Another 2 years in backup | Audit window for verdicts + MAD artifacts typical in enterprise review. |
| Verdicts (`verdict.json`) | Match containing channel | 7 years | Matches enterprise legal-hold defaults; verdicts are load-bearing for compliance. |
| Retros (`retros/*.json`) | 1 year on active channel | Deleted on channel archive | Retrospective data is formative, not evidentiary; minimize. |
| Completion Reports | 90 days post-session | Deleted | Diagnostic; short window. |
| Telemetry spans | 30 days rolling | — | Standard observability window. |
| `.sessions.json` | Session-bound | — | Regenerated on next session start. |

Retention is **per-channel-configurable** — `channel.json.settings.retention` block (Phase 5):

```json
"retention": {
  "messages_active_days": null,
  "messages_archive_years": 2,
  "verdicts_years": 7,
  "retros_days": 365
}
```

Lower values than defaults are permitted; higher values require legal-hold rationale. Phase 1 ships with defaults only.

## Data-subject rights (GDPR-style posture)

GDPR and similar regimes grant data subjects several rights. MAD.Council's position on each:

### Right of access (Article 15)

A user can find their own data by reading `~/claude-data/` directly — the filesystem IS the export format. `scripts/export-user-data.ps1` (Phase-1 nice-to-have) produces a zipped archive of every file where `from.alias == user-alias` or where the user is in `members[]`.

**Edge case**: a user who participated in a channel they've since left — their messages remain in the channel; the user needs to ask the channel owner for access or use their own backup.

### Right to rectification (Article 16)

Messages are append-only (`rules/concurrency-safety.md`). A user who posted something wrong issues a corrective reply in the same thread — that's the mechanism. MAD does **not** support editing a posted message.

**Rationale**: edit-history in a chat system enables repudiation and argument about "what was actually said." Append-only is a privacy trade-off in favor of audit integrity.

### Right to erasure (Article 17, "right to be forgotten")

Partially supported:

- A user can delete their own `~/claude-data/` at any time.
- A user leaving a channel via `/council-leave` does NOT delete their prior messages from that channel.
- A channel's owner can manually delete a member's messages via `scripts/redact-member.ps1` (Phase-4 deliverable) — this replaces the message body with `[redacted per user request, {ts}]` while preserving the message record for audit.

**Full erasure** (deletion without redaction trace) is a Phase-5 feature — gated behind strong consent from every channel member plus an admin sign-off, because it breaks audit chains. Default posture: redact, don't delete.

### Right to data portability (Article 20)

`~/claude-data/` + the JSON Schemas in `MAD/schemas/` ARE the portability format. Any other MAD-compatible tool can read the same directory layout. Channels archived to tar / zip travel cleanly across systems.

### Right to object (Article 21)

A user who objects to MAD processing their data simply doesn't use MAD — membership is voluntary per-channel. An operator who must accommodate a specific user's objection can rotate them out of relevant channels and redact their past messages via the Phase-4 tool above.

### Rights around automated decision-making (Article 22)

Council verdicts (`FIX` / `ACCEPT` / `ESCALATE` / `INVESTIGATE`) are **not binding automated decisions** on human data subjects. They are advisory verdicts on code or artifacts. A user cannot be denied a right or service based on a Council verdict; verdicts are consumed by humans who make downstream decisions.

If an operator wants to use Council verdicts as gate conditions in a process affecting data-subject rights (e.g., automated hiring filters), that operator is creating an automated-decision system and GDPR Article 22 obligations apply to THAT system, not to MAD itself. MAD provides the verdict; the operator builds the gate.

## Data residency

MAD.Council itself is **residency-agnostic** — channel state lives wherever `~/claude-data/` is on disk. That's typically the user's laptop, dev VM, or cloud workstation.

Residency obligations enter via three transmission channels:

### Upstream LLM calls (`/council-review` + model-assisted drafting)

Each provider has region offerings:

- Anthropic: US, EU endpoints.
- OpenAI: US, EU endpoints.
- Goldeneye: internal-only; residency per internal policy.

Operators pin endpoints in `skills/council-review/plan.md` configuration. The kit doesn't hard-code US — it ships endpoint-selectable.

Message body text is transmitted to the chosen endpoint as part of the review brief. For EU-residency operators: choose EU-regional endpoints + have a Data Processing Agreement (DPA) in place with the provider.

### A2A bridge (Phase 4)

Cross-region A2A communications are possible by construction — a US channel can have an EU member via Ship Bridge. Operators enforce residency by:

- Pinning the Ship Bridge region.
- Blocking cross-region A2A at the bridge via channel metadata (`channel.json.settings.a2a_allowed_regions`).
- Auditing Agent Card `a2a_endpoint_url` regions at join time.

Phase-4 deliverable: `scripts/validate-region-compliance.ps1`.

### Telemetry collectors

OTel traffic follows your collector's region. If using a US-hosted Datadog and your data is EU-residency-bound, route via a local collector that scrubs or stays within-region. The OTel endpoint is configured outside MAD's scope.

## Cross-border transfer posture

Where cross-border transfer happens, one of these mechanisms must apply (EU-centric; other regimes have analogues):

- **Standard Contractual Clauses (SCCs)** with the LLM provider + any OTel vendor.
- **Adequacy decision** (e.g., UK–EU adequacy as of 2026-04).
- **Explicit data-subject consent** per-channel (opt-in banner in `/council-open`; `channel.json.settings.cross_border_consent = true`).

MAD does not negotiate SCCs — that's the operator. MAD provides the **surface** (region pins, consent flags, audit trails) that the operator uses.

## Logging & redaction rules

What can be logged:

| Kind | Log destination | Redaction? |
|---|---|---|
| HTTP status + retry counts | OTel spans | None needed — status codes are not P2. |
| Token counts | OTel (`gen_ai.usage.*`) | None — counts are P1. |
| Message body sizes | `body_size_bytes` in span | None. |
| Message body content | — | **Never** — P2. |
| Alias + session_id | Span attributes | Hashed in aggregate dashboards to prevent operator fingerprinting; raw in per-user log. |
| run_id | Span attributes | None — opaque GUID. |
| User-entered search / filter strings | — | **Never** logged (may contain P3 accidentally). |

The telemetry pipeline strips `authorization`, `x-api-key`, `x-user-*`, `x-account-*` headers as noted in `operations/rate-limits.md §Secrets posture`. Likewise error messages from upstream providers are passed through a scrubbing filter (regex-based IPv4/IPv6 mask, email mask) before emission.

## Audit trail

Every P2-tier access leaves a trace:

| Action | Where logged |
|---|---|
| Channel creation | `channel.json.created_with_run_id` + OTel span `invoke_skill council-open` |
| Message post | `from.session_id` + `run_id` on the message; span `invoke_skill council-post` |
| Verdict issued | `verdict.json.issuer` + `issued_utc` + `run_id` |
| Consent gate fired | `<channel>/consent-log.jsonl` entry per `rules/dangerous-operations-policy.md` §Audit trail |
| Redaction applied | `redaction-log.jsonl` at channel root (Phase-4 format) |
| A2A cross-region transfer | `a2a-bridge.log` at channel root (Phase-4 deliverable) |

Audit log integrity is the same atomic-write discipline as the rest of the state: append-only JSONL with atomic rotation on size threshold.

## Incident response

When a privacy incident is suspected (accidental PII disclosure, broken ACL, mis-routed A2A traffic):

1. **Stop the bleed**: freeze the affected channel (`scripts/freeze-channel.ps1` in Phase 4 — manually rename to `.frozen` suffix in Phase 1).
2. **Scope the damage**: grep the message history for the suspected PII pattern; grep read-markers for who observed it; check OTel retention to determine whether telemetry contains samples.
3. **Notify**: per your org's incident-response playbook. MAD doesn't auto-notify.
4. **Remediate**: redact via `scripts/redact-member.ps1` (Phase-4); if telemetry samples exist, retain-then-wipe per OTel collector's capability.
5. **Retro**: blameless per `plugins/retro-bar-raiser/`; add any newly-discovered injection/exfiltration pattern to `rules/prompt-injection-policy.md §Rule 1 ban list` and to the `github.com/tldrsec/prompt-injection-defenses` awareness sweep.

Incident runbooks stubbed at `metrics/runbooks/privacy-incident-{category}.md` — one per category (PII-leak / ACL-break / mis-routed-A2A / unauthorized-read).

## Operator obligations (deployer's checklist)

Before deploying MAD.Council in any environment processing data subject to regulation:

- [ ] Map each data flow from §What MAD processes to a lawful basis in your regime.
- [ ] Review `~/claude-data/` disk-encryption status on every deploying device.
- [ ] Sign a DPA with each LLM provider used (or use a provider with a pre-signed Standard Contractual Clauses framework).
- [ ] Configure OTel collector to stay in-region if residency-bound.
- [ ] Turn on `cross_border_consent` in channel defaults if any cross-border members are possible.
- [ ] Document in your DPIA what Phase-1 does NOT do (no PII scrubbing, no message edits, redaction-over-deletion).
- [ ] Add a user-facing privacy statement pointing readers here.
- [ ] Schedule quarterly privacy reviews tied to the operational handoff calendar in `plans/phase-1-mvp.md §Operational handoffs`.

## Non-goals

- **Automatic PII detection in Phase 1.** Deferred to Phase 5; user is responsible until then.
- **Mandatory encryption at rest.** We rely on OS-level disk encryption (BitLocker / FileVault / LUKS); we do NOT add a MAD-layer crypto envelope. Doing so would break our filesystem-trust model.
- **Shipping MAD as a data-controller service.** MAD is a **processor** from the legal perspective — the deploying org is the controller and sets the legal context.
- **Catching every compliance regime.** Documented posture is GDPR-biased because that's the most demanding baseline; other regimes (CCPA, HIPAA, PIPEDA) have overlapping but distinct needs — map yours.

## What Phase 1 ships vs what's deferred

| Capability | Phase 1 | Later |
|---|---|---|
| OS-level isolation + permissions | ✅ | — |
| Per-channel retention settings | Defaults only; no per-channel override | Phase-5 config block |
| Message redaction | Manual file edit | `scripts/redact-member.ps1` Phase 4 |
| Full message deletion | Not supported (append-only) | Consent-gated erasure Phase 5 |
| Region-pinned LLM endpoints | ✅ (config) | — |
| Cross-border consent gate | — | Phase 4 |
| Automatic PII scanning | — | Phase 5 opt-in |
| Audit-log rotation / archival | Manual | Phase 4 helper script |
| DPIA template | — | Phase 5 reference doc |

## Related

- `operations/backup-disaster-recovery.md` — retention tiers; backup encryption discussion.
- `operations/multi-user-isolation.md` — OS-level isolation; per-user posture.
- `rules/prompt-injection-policy.md` — how untrusted content is handled.
- `rules/dangerous-operations-policy.md` — consent gates for operations touching P2/P3 data.
- `metrics/safety-metrics.md` — privacy-incident counters.
- `plans/phase-4-a2a.md` — cross-border / region-pinning work.
- `plans/phase-5-intelligence.md` — PII scanning + erasure + retention-config deliverables.
- GDPR: `eur-lex.europa.eu/eli/reg/2016/679` — regulation this doc models against.
- NIST Privacy Framework: `nist.gov/privacy-framework` — alternative framing.
