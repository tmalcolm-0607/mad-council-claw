---
artifact-class: milestone-overview
generated-by: hand-authored (wave-007 / lane-b)
status: red
milestone: M18
short-slug: marketplace
features: F-119..F-121
authored: 2026-05-06
---

# M18 — Marketplace local-v1

The local skill marketplace. v1 is filesystem-only: the user's workspace registry is the catalog; install-from-path is the action; a search/browse UI surfaces installed + available bundles. No network calls, no accounts, no votes/downloads — those live in the M19 deferred catalog (F-D-001 cloud marketplace, F-D-002 votes/reviews/downloads, F-D-003 ring distribution). M18's value is making the kit's bundled-skill substrate (F-051..F-053) navigable by a non-power-user without forcing engineering knowledge of the on-disk layout.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-119 | local-skill-marketplace | List-installed + install-from-path + uninstall over `<workspace>/skills-registry/`; pure filesystem; no network |
| F-120 | skill-metadata | Marketplace-display fields (name/description/version/author/tags/license/installed-at) extending F-051 frontmatter |
| F-121 | skill-search-browse-ui | Settings → Skills → Marketplace pane; search/browse/inspect/toggle/install; client-side substring filter |

## Dependency DAG

```
M0 (F-008 storage)         ──→ F-119 (registry path under workspace)
M5 (F-032 desktop window)  ──→ F-121 (UI mounts inside the shell)
M7 (F-051 SKILL.md)        ──→ F-119 (validates bundles), F-120 (metadata extends frontmatter)
M7 (F-052 toggle)          ──→ F-119 (active boundary), F-121 (toggle from row)
M7 (F-053 custom-load)     ──→ F-119 (registers newly installed skill)
M8 (F-074 workspace)       ──→ F-119 (scopes the registry)
M2 (F-015 audit)           ──→ F-119 (install/uninstall entries)

F-119 (marketplace)        ──→ F-120 (writes installed-at), F-121 (data source + actions)
F-120 (metadata)           ──→ F-121 (every row renders metadata)
```

## Milestone exit criteria

- All 3 ledgers GREEN
- Listing installed skills returns deterministic output for a fixed workspace state
- install-from-path validates F-051 frontmatter BEFORE any filesystem write — malformed bundles never land partial-installed
- Metadata reader is a pure function over parsed YAML; no fabricated defaults per `rules/no-invented-constraints.md`
- Search/browse UI renders all installed + available bundles; substring filter is deterministic; full SKILL.md body renders in detail panel without truncation per FETCH-BEFORE-CITE
- Activate / deactivate from the UI flips F-052 toggle and emits the corresponding audit-chain entry per F-015
- No network calls anywhere in M18 — verifiable by network-isolation integration test

## Out of scope (tracked elsewhere)

- Cloud-hosted marketplace (registry server, account auth, paid skills) — M19 / F-D-001
- Skill votes / reviews / download counters — M19 / F-D-002
- Ring-based distribution (alpha / beta / stable channels) — M19 / F-D-003
- Author identity verification (signed manifests, Entra-bound publisher IDs) — overlaps F-D-006 / F-D-007
- Skill compatibility-matrix enforcement (engine-version range gates) — post-v1; v1 records but does not enforce
- Localized metadata + search (non-English) — overlaps F-D-014 i18n
- Mobile / small-screen layout — overlaps F-D-015 mobile companion
- Voice-driven browsing — overlaps M13 multimodal
- Recommendations / "you might also like" — post-v1
- Fuzzy / typo-tolerant search — post-v1; v1 is case-insensitive substring

## Provenance

`kit:foundational-plan.md M18 row + Message 11 marketplace ask`, `kit:.claude/skills/*` (kit's bundled-skill substrate), `kit:rules/{skill-standards, canonical-artifact-frontmatter, no-silent-deferrals, no-invented-constraints, dangerous-operations-policy, verification-protocol}.md`, `cp:src/components` (clawpilot's React patterns for the search/browse UI shape). Per-ledger `provenance.surfaces`.
