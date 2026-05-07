---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-004 / lane-d)
wave: wave-004
lane: lane-d
topic: per-feature-ledger-authoring-M8-settings-persistence
date: 2026-05-07
status: complete
---

# Wave 4 / Lane D — per-feature ledgers for M8 (settings & persistence)

## Scope

M8 catalog drop into `docs/03-feature-catalog/M8-settings-persistence/`. Author RED-state ledgers for F-067..F-075 (9 features) per `foundational-plan.md` Feature catalog M8 row + Message 11 NEW additions. Time-budget ≤5 min wall-clock per `loop-cadence-discipline.md`.

Wave-2 lane-b authored M0+M1+M2 (22 ledgers); wave-3 lane-a authored M5 (12 ledgers); this lane is the M8 cluster (9 ledgers + README + this summary).

## What was created

| Group | Path | Count |
|---|---|---|
| M8 ledgers | `docs/03-feature-catalog/M8-settings-persistence/F-{067..075}-*.md` | 9 |
| Milestone README | `docs/03-feature-catalog/M8-settings-persistence/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-004/lane-d-summary.md` | 1 |
| **Total** | | **11** |

## Per-ledger frontmatter contract (matches wave-2 lane-b + wave-3 lane-a)

Every ledger carries:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-004 / lane-d)`
- `status: red`, `status-since: 2026-05-07`, `status-history: [...]`
- `feature-id: F-067..F-075`, `short-slug`
- `milestone: M8`
- `provenance.surfaces: [foundational-plan:M8, foundational-plan:Message-11, cp:..., kit:..., msft-learn:...]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by M8 implementation wave)
- `red-green-rule:` literal (matches lane brief verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked + v1.5 deferrals named
- `confidence: high`

## Per-ledger body sections

Every ledger has the 6 required body sections:
1. Behavior contract (3-6 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each with observable outcomes)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

Plus, on F-070, F-071, F-073, F-075: an "Open decisions" section explicitly linking to D-3 / D-5 in `docs/10-backlog/design-decisions-pending.md` with the working assumption + what changes if the decision closes otherwise.

## NEW features (no source surface)

5 of the 9 ledgers are NEW per user Message 11 — they have no clawpilot or canonical-e source surface and are emergent from the user's enumeration ("Bring-your-own MCP + encrypted local storage" + "Daily briefing + project workspace"):

- F-070 encrypted-local-storage
- F-071 encryption-key-mgmt (sourced from msft-learn DPAPI/Keychain/libsecret docs to give it platform contracts)
- F-072 encrypted-import-export
- F-073 project-workspace
- F-074 workspace-switcher-ui
- F-075 workspace-persistence

Each NEW ledger carries an explicit `> NEW per user Message 11` block in the body to make the provenance visible at-a-glance — the foundational-plan caught these in the M8 catalog row but their downstream ledgers had not yet existed.

## Provenance distribution

| Source family | Surfaces cited |
|---|---|
| foundational-plan | M8 catalog row F-067..F-075; Message 11 NEW features |
| `cp:` (clawpilot) | settings-shape (F-067), settings-ui (F-068), per-automation-rules (F-069); src/main/index.ts (F-074 chrome host) |
| `kit:` (MAD kit rules) | concurrency-safety.md (atomic writes — every ledger), single-owner-accountability.md (owner_alias on F-067, F-073, F-075), no-silent-deferrals.md (F-069 validation-failed-not-dropped), no-invented-constraints.md (F-073 no implicit caps), dangerous-operations-policy.md (F-068 telemetry consent, F-072 export consent, F-074 delete-workspace consent), stride-threat-model.md (F-070 Tampering / Info-Disclosure, F-071 Spoofing / Elevation, F-072 Info-Disclosure), degradation-fallback-policy.md (F-075 missing-workspace fallback), canonical-artifact-frontmatter.md (F-075 versioned JSON shape) |
| `msft-learn:` | DPAPI (Windows credential vault), macOS Keychain Services, libsecret (Linux Secret Service via D-Bus) — all in F-071 to give the IKeyProvider interface concrete platform contracts |

## Open decisions (referenced in ledgers)

Two design decisions remain OPEN, tracked in `docs/10-backlog/design-decisions-pending.md`:

- **D-3** (encryption key source default = OS keychain DPAPI/Keychain/libsecret) — referenced in F-071. Working assumption: OS keychain. If D-3 closes for BYOK or passphrase fallback, F-071's IKeyProvider interface accommodates without breaking F-070/F-072 contracts.
- **D-5** (workspace storage layout = single root `<state-dir>/workspaces/<workspace-id>/` subtree, vs separate `<state-dir>` per workspace) — referenced in F-073 + F-075. Working assumption: single root. If D-5 closes for separate roots, F-075 paths shift but persistence semantics (atomic write, version field, fallback) are unchanged.

Per `rules/no-silent-deferrals.md`, both are explicitly named in the relevant ledgers + this summary — NOT silently dropped, NOT silently assumed-closed.

## Anomalies / context gaps

- **F-NNN -> FR-XXX exact mapping deferred** per the wave-2 / wave-3 convention. `fr-coverage: []` in all 9 files; mapping happens via `/mad-spec` per-feature in the M8 implementation wave. canonical-e does not appear to have an FR family for at-rest encryption (F-070-F-072) or project workspaces (F-073-F-075), so those ledgers will likely cite kit-rule + msft-learn surfaces only when /mad-spec runs — flagged here for the spec author.
- **No live test files.** Per the brief, test-files frontmatter arrays stay empty until the M8 implementation wave lands the actual `tests/{unit,integration,browser}/F-NNN-*.test.ts` files.
- **F-068 settings-ui defers per-section sub-features to other milestones.** The 7 sections are owned by their respective M5/M6/M7 features (F-035/F-036/F-037/F-049/F-058/F-039/F-113); F-068 owns the chrome + Save/Cancel/dirty + telemetry-consent gate ONLY. This is captured in F-068's out-of-scope-notes + dependencies.
- **F-071 platform-specific test files** are split per platform (Windows-only DPAPI test) — wave-2/wave-3 ledgers used a single integration-test file convention; F-071 needed per-platform fixtures because the credential-vault APIs differ. Documented in F-071's wire-up table.

## Out of scope (per `rules/no-silent-deferrals.md`)

Tracked exhaustively in each ledger's `out-of-scope-notes` block + the M8 README's "Out of scope" section. Highlights:

- Cloud-synced settings + workspaces → v1.5
- HSM-backed keys + hardware tokens → M19 deferred (F-D-005)
- Per-field encryption → v1.5
- Recovery codes / printable backup phrase → v1.5
- Workspace templates + history + drag-reorder + icons → v1.5
- Per-workspace cost-budget caps → v1.5
- Multi-window per-workspace → v1.5
- Schema migration tooling for major-version bumps → M19 (F-D-004)
- Cross-machine workspace sync (live) → v1.5

Every v1.5 / M19 deferral is explicit, not silent.

## Confidence

HIGH (all 9 ledgers + README). The 4 base features (F-067, F-068, F-069 + the structure of F-067) have direct clawpilot precedent. The 5 NEW features (F-070..F-075) ground in well-known platform primitives (AES-256-GCM + Argon2id for F-070/F-072; DPAPI/Keychain/libsecret for F-071) and concrete UX patterns (overlay-based config scope for F-073/F-074/F-075). Open decisions D-3 + D-5 do NOT lower confidence because the working assumptions are explicit + the contracts hold either way the decisions close.

## Quality-gate checklist (QG1-QG9 for wave-004 lane-d)

- [x] QG1 — net-new — first M8 catalog drop; 11 artifacts net-new
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists foundational-plan + cp + kit + (where applicable) msft-learn surfaces; this summary cites foundational-plan.md M8 row + Message 11
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G15 (M8 settings + persistence as v1 lane), G18 (multi-agent fan-out applied to wave-4 lane decomposition)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec runs; references existing D-3 + D-5 from `design-decisions-pending.md` without inventing new constraints
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-004 has multiple lanes (A authored separately + this lane D)
- [ ] QG7 — Copilot CLI design review — N/A this lane (catalog drop; council/copilot fires at /mad-spec time per ledger or at milestone exit)
- [x] QG8 — Microsoft tools used — msft-learn surfaces cited in F-071 (DPAPI, Keychain, libsecret platform contracts)
- [x] QG9 — open questions captured — D-3 + D-5 explicitly referenced in F-070/F-071/F-073/F-075 + M8 README + this summary

## Loop-improvement proposal (QG5)

The 9-ledger M8 drop took ~5 min by hand-authoring with the wave-2/wave-3 template. Three patterns to lift:

1. **NEW-feature visibility marker.** Ledgers for surfaces with no source provenance (F-070..F-075) carry an explicit `> NEW per user Message N` block at the top of the body. This makes provenance visible at a glance without forcing a reader to cross-reference frontmatter `surfaces:` against a list of known sources. Recommend: future catalog drops adopt this whenever a ledger has no `cp:` or `ce:` surface.

2. **Open-decisions section pattern.** F-070/F-071/F-073/F-075 carry an "Open decisions" section linking to `design-decisions-pending.md` D-X with the working assumption stated explicitly. Treats decisions as visible-named gaps, not silent assumptions. Recommend: future ledgers that depend on an open decision adopt this section verbatim — it satisfies `rules/no-silent-deferrals.md` mechanically.

3. **Per-platform fixtures in test-file wire-up.** F-071's wire-up table has explicit Windows-only / cross-platform markers because the credential-vault APIs differ per OS. The wave-2/wave-3 single-fixture convention is fine for OS-portable code; per-platform code needs explicit fixture forking. Recommend: ledger template gain a `Platform:` column hint in wire-up tables when feature is platform-divergent.

## Next steps

- Wave-4 / Lane D's work is committed (one commit per ledger + README + summary). DO NOT push per non-negotiable rules — push is a separate user-initiated step.
- M9 (F-076..F-081 M365 integration), M6 (F-044..F-050 MCP & tools), M7 (F-051..F-066 skills+perms+auto) are the natural next catalog drops; M9 and M7 both feed back into M8 (M9's MSAL token cache is encrypted by F-070; M7's automations consume F-069 per-rule overrides).
- D-3 + D-5 closure (council-review) gates F-070/F-071/F-073/F-075 implementation start. Recommend opening a council channel sized for both decisions in the same review.
- M8 implementation wave begins after the M0+M1+M2 base + D-3+D-5 closure converge; F-008 storage layout (M0) is the hard prerequisite.
