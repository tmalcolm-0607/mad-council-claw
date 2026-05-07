---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-004 / lane-a)
wave: wave-004
lane: lane-a
topic: per-feature-ledger-authoring-M6-mcp-tools
date: 2026-05-06
status: complete
---

# Wave 4 / Lane A — per-feature ledgers for M6 (MCP & tool execution)

## Scope

Catalog drop for M6 MCP & tool execution. Author 7 RED-state ledgers + a milestone README, matching the wave-2 lane-b + wave-3 lane-a format used for M0-M5. Span: F-044..F-050 (7 features).

This closes the M0-M6 catalog seed for the four planes: bootstrap (M0), backend (M1), governance (M2), proactive (M3), CLI (M4), desktop (M5), and now tools (M6). M7+ (Skills + Permissions + Automations) is out of this lane's scope.

## What was created

| Group | Path | Count |
|---|---|---|
| M6 ledgers | `docs/03-feature-catalog/M6-mcp-tools/F-{044..050}-*.md` | 7 |
| Milestone README | `docs/03-feature-catalog/M6-mcp-tools/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-004/lane-a-summary.md` | 1 |
| **Total** | | **9** |

## Per-ledger frontmatter contract (matches wave-2 lane-b + wave-3 lane-a)

Every ledger carries:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-004 / lane-a)`
- `status: red`, `status-since: 2026-05-06`, `status-history: [...]`
- `feature-id: F-NNN`, `short-slug`, `milestone: M6`
- `provenance.surfaces: [ce:..., cp:..., kit:...]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by M6 implementation wave)
- `red-green-rule:` literal (matches wave-3 lane-a verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked
- `confidence: high`

## Per-ledger body sections

Every ledger has the 6 required body sections from the canonical format:
1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Provenance distribution

| Source family | Surfaces cited (across 7 ledgers + README) |
|---|---|
| Canonical-e (`ce:`) | `US-6` (Skills/MCP allowlist + version pinning user story, P2), `FR-AUDIT-001` (hash-chained audit log), `FR-QUOTA-001` (per-spawn tool count quota), `FR-COST-003` (failure-pattern halt on 3 consecutive `tool_error`), `tool_calls_exhausted` (run-end reason), `QUOTA_EXCEEDED_TOOL_CALLS` (failure mode tag) |
| Clawpilot (`cp:`) | `electron/mcp-store.ts`, `electron/mcp-tools.ts`, `electron/mcp-crypto.ts`, `electron/mcp-disabled.ts`, `electron/ipc/mcp-ipc.ts`, `electron/ipc/mcp-oauth-ipc.ts`, `electron/tool-discovery.ts`, `bundled-mcp/filesystem-server.mjs`, `sidecar/node-runner.{cs,exe}`, `common/mcp-url-validation.ts`, `common/tool-registry.ts`, `common/format-tool-description.ts`, `src/features/extensions/{AddMcpDialog,McpServersTab,parseCatalogContent}.tsx` |
| MAD kit (`kit:`) | `rules/{degradation-fallback-policy,dangerous-operations-policy,concurrency-safety,verification-protocol,prompt-injection-policy,mcp-tiering,single-owner-accountability}.md` |
| Wave-1 Lane C synth | `lessons-learned.md` (default-deny at every capability boundary; bounded retries with explicit timeouts; sidecar pattern for Windows console-flash; cleanup is bounded) |

## Anomalies / context gaps

- **Commit-bundling race with Lane C (recorded for transparency, not for re-do).** The 7 ledgers + M6 README were authored, staged via `git add`, and intended as a single chain-of-thought commit (matching wave-3 lane-a precedent commit `70d9518`). Between `git add` and `git commit`, Lane C's parallel `git add -A` (or `git add docs/`) absorbed the staged M6 files into their `b458c01 research(msft-2026): agent-365-sdk-typescript deep-dive` commit. The M6 file content is correct and on `main`; only the commit-message attribution is off. Per `minimum-change.md` and `scope-discipline.md`, NOT amending Lane C's commit (destructive + Lane C's own SOURCE/WAVE attribution is correct for their research file). This summary commit (and this paragraph) carries the load-bearing Wave 4 Lane A WHY/SOURCE/CONFIDENCE/WAVE attribution. Future-loop hardening idea: parallel lanes operating on the same repo SHOULD use `git add <pathspec>` + `git commit -m` chained in a single shell invocation (since cwd resets between Bash tool calls), or sequence commits via a lane-coordination mutex. Captured as the lane's primary loop-improvement signal below.
- **F-NNN -> FR-XXX exact mapping deferred.** Per `wave-2 lane-b` precedent the `fr-coverage: []` field is empty; `/mad-spec` per-feature fills it. Mapping will be done in the M6 implementation wave.
- **No live test files.** Per the wave-2 lane-b precedent, `test-files` arrays stay empty until the M6 implementation wave lands actual `tests/{unit,integration,e2e}/F-NNN-*.test.ts` files.
- **F-046 has no exact 1:1 canonical-e FR.** Reconnect+health is a derived requirement from `ce:US-6` + `kit:rules/degradation-fallback-policy.md` Rule 4 (respect retry limits) + `wave-1 lane-c lessons-learned.md` (bounded retries). HIGH confidence — reconnect-with-circuit-break is a non-negotiable for any tool-substrate per the cross-cutting rules.
- **F-125 (mcp-tool-cap-per-workspace, NEW frontier candidate, M7) not authored here.** It belongs to M7 (Skills + Permissions + Automations); referenced in `out-of-scope-notes` of F-044, F-049, and the M6 README, awaiting M7 wave authorship.
- **F-122 (a2a-endpoint-exposure, NEW frontier candidate) not authored here.** Cross-machine MCP-equivalent surface; deferred per its M19 placement; referenced in F-046 + F-049 + M6 README `out-of-scope-notes`.
- **PII redaction (F-017) interaction with audit (F-047).** F-047 names redaction as a precondition to args-sha256; the actual redaction primitive lives in F-017 (M2). HIGH confidence on the ordering — "redact then hash" preserves audit-chain integrity even when args contain PII.

## Out of scope (per `rules/no-silent-deferrals.md`)

- M7 Skills + Permissions + Automations ledgers (F-051..F-066) — different lane.
- M7 NEW frontier candidates F-125 (mcp-tool-cap-per-workspace) — explicitly enumerated in the M6 README + ledger out-of-scope notes; lands in M7 wave.
- M19 deferred BYO-MCP-related items (F-D-005 BYOK, F-D-007 cross-machine, F-D-012 sandboxing) — explicitly enumerated in F-049 out-of-scope notes.
- Test plans (`/testplan` per-feature) — runs at /mad-spec time per wave-2 lane-b precedent.
- Live trace timeline UI for tool-call sequences (M11+M12) — referenced in F-047 + F-048 out-of-scope notes.
- Multi-model adversarial review of audit log integrity (M10) — referenced in F-047 out-of-scope notes.

## Confidence

HIGH (all 7 ledgers + README). Source material — `foundational-plan.md` Architecture § Tool plane + Feature catalog table row M6 + canonical-e-inventory.md `ce:US-6` + clawpilot MCP wiring inventory (~14 distinct file surfaces) + wave-1 lane-c lessons-learned + `kit:rules/degradation-fallback-policy.md` + `kit:rules/concurrency-safety.md` + `kit:rules/dangerous-operations-policy.md` — is consistent. Behavior contracts are present-tense imperative, acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes, dependencies trace cleanly through the milestone DAG with hard dependencies on F-001/F-007/F-008 (M0) and soft dependencies on F-015..F-022 (M2 governance triad).

## Quality-gate checklist (QG1-QG9 for wave-004 lane-a)

- [x] QG1 — net-new — first M6 catalog drop; 7 ledgers + 1 milestone README + this summary are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists ce/cp/kit surfaces; this summary cites foundational-plan.md + canonical-e-inventory.md + clawpilot-features-inventory.md + wave-1 lane-c lessons-learned.md
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G7 (M1 backend abstraction's tool plane), G18 (multi-agent fan-out — wave structure)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec; references existing M19 deferred items + NEW frontier candidates F-125 + F-122 (no new backlog rows added by this lane)
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-004 plan splits into multiple lanes; this is lane A
- [ ] QG7 — Copilot CLI design review — N/A this lane (cadence: per QG7 every N=3 waves; wave-3 already ran the Copilot review)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + canonical-e + clawpilot synthesis read-only); WorkIQ MCP would be relevant for tool-explosion lessons but those are already captured in wave-1
- [x] QG9 — open questions captured — see "Anomalies / context gaps" above

## Loop-improvement proposal (QG5)

The 7-ledger M6 drop continues the wave-3 lane-a template-first pattern. Three refinements surfaced:

0. **Parallel-lane commit-staging race (PRIMARY).** When N lanes operate concurrently on the same git repo via the Bash tool, the index is shared but cwd-state is not. A `git add` in one Bash call and a `git commit` in a follow-up Bash call leave a window during which a sibling lane's `git add -A` / `git add docs/` absorbs the first lane's staged paths into the sibling's commit. This happened in this run (Lane A's M6 ledgers landed in Lane C's research commit `b458c01`). Mitigations, in order of strength: (a) chain `git add <pathspec> && git commit -m "..."` in a single Bash invocation (load-bearing — restores atomicity); (b) prefer `git add <pathspec>` over `git add -A` / `git add docs/` to limit blast radius; (c) lane-coordination mutex (filesystem lock or wait-for-clean-index) before each commit. Recommend hardening the wave-orchestration brief to include rule (a) verbatim.

1. **MCP wiring already maps cleanly to F-NNN granularity in clawpilot.** The clawpilot inventory section "3. MCP wiring" lists 13 distinct surfaces (`mcp-store`, `mcp-tools`, `mcp-crypto`, `mcp-disabled`, `mcp-ipc`, `mcp-oauth-ipc`, `mcp-url-validation`, `tool-registry`, `format-tool-description`, `tool-discovery`, `node-runner.exe`, `bundled-mcp/filesystem-server.mjs`, `AddMcpDialog`, `McpServersTab`). 7 features cluster these into bridge / lifecycle / health / audit / streaming / BYO / persistence — a clean 1.6:1 surface-to-feature ratio. This pattern is generalizable: the foundational plan's milestone tables already encode the right granularity. Recommend: future catalog drops keep the `<count> features per milestone` from the plan rather than re-decomposing.

2. **Cross-cutting kit rules form a stable backbone for tool-plane ledgers.** Six kit rules (`degradation-fallback-policy`, `dangerous-operations-policy`, `concurrency-safety`, `verification-protocol`, `prompt-injection-policy`, `mcp-tiering`, `single-owner-accountability`) appear across 5/7 of the M6 ledgers. This isn't accidental — the tool plane is exactly where these rules apply most concretely (external content trust, default-deny capability, atomic state, retry limits). Recommend: when authoring future ledgers in the tool/governance/automation planes, the kit-rules backbone is a pre-flight check — if a ledger doesn't cite at least 2 of these, the contract is probably under-specified.

## Next steps

- M7 lane (Skills + Permissions + Automations, F-051..F-066, ~16 features) is the next catalog batch; will reuse F-049's BYO discipline + F-058's perms-engine to gate F-047 tool-call audit before dispatch.
- F-125 (mcp-tool-cap-per-workspace NEW frontier) lands in the M7 wave; F-122 (a2a-endpoint-exposure NEW) lands when its target milestone (M19 deferred) is authored.
- Implementation wave for M0+M2+M6 can begin once M6 README + ledgers are committed AND the M0-bootstrap tests start landing — F-044..F-050 implementation has soft dependencies on F-015 (hash-chain) + F-017 (PII redaction) + F-022 (tool-quota) which themselves want their tests landing first.
