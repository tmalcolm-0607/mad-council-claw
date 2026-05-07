---
artifact-class: milestone-overview
generated-by: hand-authored (wave-007 / lane-b)
status: deferred
milestone: M19
short-slug: deferred
features: F-D-001..F-D-015
authored: 2026-05-06
---

# M19 — Deferred

The explicit deferred catalog. Every item here was named in the foundational plan as v1.5+ scope (or surfaced during v1 catalog finalization as an explicit non-goal). M19 exists to make those deferrals **mechanically visible** per `rules/no-silent-deferrals.md` — silent additions are easy to revert; silent deferrals erase user intent. Each ledger names a clear re-open trigger so the item does NOT lurk as ambient backlog.

**Status discipline:** every M19 ledger is `status: deferred`. Items NEVER transition through RED unless the user explicitly re-opens them and a council-review verdict ratifies the transition with a target milestone + ledger expansion. They are NOT failing tests. They are NOT in-progress work. They are documented gaps with named conditions for opening.

This README enumerates F-D-001..F-D-015 (the 15 items named in the foundational-plan M19 row). Three additional items (F-D-016 in-meeting-live-assistant, F-D-017 foundry-hosted-agent-deployment, F-D-018 activity-protocol-teams-outlook) were surfaced from frontier research and are tracked separately in `new-from-research.md` per the catalog index — they will land here in a follow-up wave when authored.

## Features

| ID | Slug | One-liner | Re-open hinge |
|---|---|---|---|
| F-D-001 | cloud-marketplace | Cloud-hosted skill registry + accounts + install-from-cloud | Identity story (F-D-006/007) lands first |
| F-D-002 | skill-votes-reviews-downloads | Aggregate community signals on cloud catalog | F-D-001 lands; abuse-resistance design exists |
| F-D-003 | ring-distribution | Per-skill alpha/beta/stable rings | F-D-001 + telemetry signal sufficient |
| F-D-004 | archive-encryption | Confidentiality envelope on F-026 idle archive | Multi-user shared-machine OR compliance trigger |
| F-D-005 | schema-migration | Engine-driven version-skew migration | First breaking-shape change shipped |
| F-D-006 | identity-crypto-spawn-signing | Per-spawn cryptographic proof (ce:FR-IDENTITY-002) | Multi-process / cross-machine deploy OR adversarial replay forensics |
| F-D-007 | identity-entra-binding | Entra-principal-bound agent_id (ce:FR-IDENTITY-003) | Cross-tenant artifact exchange becomes real |
| F-D-008 | teams-adapter | Outbound Teams (post / DM / briefing-channel) | User asks for Teams write OR F-D-010 / F-D-018 re-open |
| F-D-009 | outlook-adapter | Outbound Outlook (sendMail / RSVP / drafts) | Email-destination ask OR F-D-018 re-open |
| F-D-010 | bot-framework-direct | Engine-as-bot via Bot Framework | Hosting story + STRIDE design lands |
| F-D-011 | agent365-central-sink | Federated telemetry / cost / governance export | Agent365 API stable + F-D-007 binding present |
| F-D-012 | byok-per-tenant-routing | Customer-supplied keys + per-tenant model routing | Real customer asks for own-key OR data-residency req |
| F-D-013 | agent-action-sandboxing | OS-level sandbox per skill | Marketplace adoption (F-D-001) OR security incident |
| F-D-014 | i18n | Localization across all surfaces | Non-en-US user OR launch-market expansion |
| F-D-015 | mobile-companion | iOS / Android / PWA companion | Remote transport (F-D-001/008/010/018) lands first |

## Categorization

Three implicit clusters drive most of the dependency structure between deferred items:

1. **Marketplace federation** — F-D-001, F-D-002, F-D-003. v1's local marketplace (M18) is the substrate; these federate it across users, signals, and rings.
2. **Identity federation** — F-D-006, F-D-007, F-D-011, F-D-012. v1's per-agent identity (F-002) is engine-local; these add cryptographic + Entra-bound verifiability + central observability.
3. **Outbound surface federation** — F-D-008, F-D-009, F-D-010, F-D-015, plus the not-yet-authored F-D-017 / F-D-018. v1 reads M365 surfaces via WorkIQ; these let the engine write back and / or be remotely addressable.

F-D-004 (archive-encryption), F-D-005 (schema-migration), F-D-013 (sandboxing), and F-D-014 (i18n) sit outside the three clusters as standalone hardening / compliance items.

## Re-open mechanics

A single user request is sufficient to begin the re-open conversation, but the actual transition out of `status: deferred` requires:

1. The user explicitly requests re-open (verbal or written).
2. The named re-open trigger conditions for that ledger are met.
3. A council-review verdict (per `rules/review-gate-protocol.md`) ratifies the transition with HIGH confidence (≥80%).
4. The target milestone is identified (which M-NNN does this land in?) and a scope-expanded ledger is authored before the status flips to RED.

The asymmetry intentionally matches `rules/no-silent-deferrals.md` — adding scope is easy to revert; pulling deferred work in early should require a documented decision so the v1 timeline is not silently re-shaped.

## Out of scope (yes, even for the deferred catalog)

- **Synthesizing re-open triggers from inferred user behavior.** Re-open requires explicit user request, not "I noticed you said something that sounded like you wanted X."
- **Demoting v1 features to M19.** If something currently in M0..M18 looks like it should be deferred, that's a scope-reduction decision, not an M19 catalog item — it goes through `rules/no-silent-deferrals.md` discussion, not by silent re-classification.
- **Pre-investing implementation effort against deferred items.** Skill / hook / template scaffolding for an M19 item is itself v1.5+ scope.

## Provenance

`kit:foundational-plan.md M19 row F-D-001..F-D-015`, `kit:rules/no-silent-deferrals.md`. Per-ledger `provenance.surfaces`.
