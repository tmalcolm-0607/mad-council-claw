---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-114
short-slug: readme-quickstart
milestone: M17
provenance:
  surfaces:
    - cp:README.md
    - cp:docs/quickstart
    - kit:rules/no-silent-deferrals.md
    - foundational-plan.md M17 docs section
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
  LOCKED if GREEN AND reviews/F-114-readme-quickstart-review.md exists with verdict: ACCEPT.
depends-on: [F-104, F-109]
out-of-scope-notes: |
  Marketing / landing-page README is OUT — README is engineering-focused install
  + first-launch + smoke-test for v1. Multi-language READMEs (i18n) are v1.5.
  Animated GIFs / video walkthroughs are OUT for v1 (text + screenshots only).
  Per-platform deep-dive is split into M17 architecture-docs (F-115); README
  cross-links there. Self-hosted backend setup walkthrough is v1.5.
confidence: high
---

# F-114 — README + quickstart

## Behavior contract

The repo MUST ship a top-level `README.md` that gets a new user from "downloaded the installer" to "engine running and a first MAD.Council channel opened" in under 10 minutes. Required sections in order: (1) one-paragraph what-it-is, (2) install (per-platform: macOS DMG / Windows NSIS / Linux AppImage / CLI npm — links to F-104 + F-109 release artifacts), (3) first-launch checklist (auth via M9, default telemetry mode per F-113, audit-log location), (4) 5-minute quickstart (open a council channel, post a message, run /council-review, see verdict), (5) where to go next (cross-links to F-115 architecture, F-116 skill authoring, F-117 MCP server adding, F-118 automation cookbook). Every external link MUST resolve at the time of release (CI link-check). Every code block MUST be copy-pasteable as-is. Per `rules/no-silent-deferrals.md`, sections that are intentionally minimal (e.g. "no enterprise SSO setup in v1") name the absence explicitly with a pointer to v1.5.

## Acceptance scenarios

1. **Given** a fresh GitHub visitor with zero prior context, **When** they read the README top-to-bottom and follow the 5-minute quickstart on macOS, **Then** they have the engine installed, are signed into Microsoft 365 (per F-076), and have run `/council-open` + `/council-post` + `/council-review` against a newly-created channel — measured wall-clock under 10 minutes (timed by an internal usability harness).
2. **Given** a CI run on `main`, **When** the link-check job runs against `README.md`, **Then** every external URL returns 200 (or 301 to a 200) and every relative repo path resolves to an existing file; broken links fail the build.
3. **Given** a user on a non-AAD-joined Linux box without WAM, **When** they follow the quickstart, **Then** the README explicitly directs them to the MSAL fallback path (per F-076) with no implicit "WAM required" assumption — the absence of WAM is named, not silently assumed.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/docs/readme-quickstart-wallclock.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/integration/docs/readme-link-check.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/docs/readme-explicit-fallback-paths.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-104 (electron-builder release artifacts; install section links to them), F-109 (CLI binary; quickstart references npm install path)
- **Soft:** F-076 (MSAL auth referenced in first-launch), F-113 (telemetry default explained), F-115 / F-116 / F-117 / F-118 (cross-links to deeper docs)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:README.md | clawpilot's README structure as a starting shape (engineering-focused, install-first) |
| cp:docs/quickstart | clawpilot quickstart pattern; engine adapts to the council-centric flow |
| kit:rules/no-silent-deferrals.md | minimal sections name absences explicitly with v1.5 pointers — no silent omissions |
| foundational-plan.md M17 docs section | scope boundary: README + 4 deeper docs; cross-link discipline |

## Implementation notes

(empty — populated when implementation begins)
