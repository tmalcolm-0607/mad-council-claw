---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-121
short-slug: skill-search-browse-ui
milestone: M18
provenance:
  surfaces:
    - kit:foundational-plan.md M18 row
    - cp:src/components (clawpilot's React component patterns for list/search UI)
    - kit:rules/skill-standards.md
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-121-skill-search-browse-ui-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-119, F-120]
out-of-scope-notes: |
  Search ranking by popularity / vote / download count is OUT — F-D-002 deferred (those signals
  do not exist in v1). Cloud-hosted catalog search is OUT — F-D-001 deferred. Fuzzy matching
  beyond simple substring + prefix is post-v1; v1 search is case-insensitive substring across
  name + description + tags. Skill recommendations / "you might also like" are post-v1. Voice-
  driven browsing is post-v1 (overlaps with M13 multimodal). Mobile / responsive small-screen
  layout is post-v1 (overlaps with F-D-015 mobile companion). Localized search (non-English
  query) is OUT — overlaps with F-D-014 i18n.
confidence: high
---

# F-121 — Skill search / browse UI

## Behavior contract

The desktop shell MUST present a **skill search and browse UI** rendering the local marketplace's installed and available bundles. The UI is a Settings → Skills → Marketplace pane (mounted under the F-032 desktop shell window) showing a list of every skill known to F-119's marketplace, surfacing each item's F-120 metadata (name, description, version, author, tags, status: active / installed-not-active / available-on-disk). The user can: (a) **search** — case-insensitive substring match across name + description + tags, filtering the list deterministically; (b) **browse** — sort by name (alphabetical) or installed-at (newest first); (c) **inspect** — click a row to open a detail panel showing full metadata + a verbatim render of the skill's SKILL.md body; (d) **toggle** — activate / deactivate via F-052; (e) **install** — invoke F-119's install-from-path picker. No network calls. No external assets — every glyph and string ships with the bundle.

## Acceptance scenarios

1. **Given** the workspace has 12 known skills (5 active, 4 installed-not-active, 3 available-on-disk), **When** the user opens the marketplace pane, **Then** the list shows all 12 with each item's status badge correct and counts in the pane header (`5 active · 4 installed · 3 available`); render is deterministic given the same workspace state.
2. **Given** the user types `cosmos` into the search box, **When** the filter applies, **Then** only skills whose name OR description OR tags contain the substring `cosmos` (case-insensitive) remain visible; the visible count updates; clearing the search restores the full list — no skill silently dropped per `rules/no-silent-deferrals.md`.
3. **Given** the user selects a skill row whose SKILL.md body is 1,847 lines long, **When** the detail panel opens, **Then** the full body renders without truncation; the panel cites the bundle's source path so the user can `Read` the file directly per `rules/verification-protocol.md` FETCH-BEFORE-CITE.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/marketplace/marketplace-pane-renders.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/marketplace/marketplace-search-substring-filter.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/marketplace/marketplace-detail-panel-no-truncation.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (desktop shell window — UI mounts inside it), F-119 (marketplace's list-installed + install-from-path are the data + action sources), F-120 (metadata is what each row renders)
- **Soft:** F-052 (toggle from the row), F-053 (custom-load triggered post-install), F-068 (settings UI is the parent container the marketplace pane mounts under)
- **Independent:** F-D-001 (cloud marketplace UI — v1.5 successor)

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M18 row | "Search/browse UI: F-121" |
| cp:src/components | Clawpilot's React patterns for filtered-list + detail-panel UI shape |
| kit:rules/skill-standards.md | Frontmatter contract that defines what fields the UI surfaces |

## Implementation notes

(empty — populated when implementation begins; search MUST run client-side over already-loaded metadata; no debounced server fetch — the data is local)
