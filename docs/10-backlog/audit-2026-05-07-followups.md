# Audit followups — 2026-05-07

> Source: `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/mad-council-claw-audit-2026-05-07.md`
> 4-lane code-investigator audit run from the parent kit (MAD - Clean) on 2026-05-07. This file pulls the audit's actionable findings into a tracked, in-repo backlog so wave-19+ can pick them up without re-reading the parent-kit report.

## Ground rules

- This file is **append-only** for follow-up rows; the original audit synthesis lives in MAD - Clean and is read-only.
- Each row owns a confidence label (HIGH / MEDIUM / LOW) per `verification-protocol.md`.
- Per `no-silent-deferrals.md`: removing a row requires user acknowledgement.
- Per `scope-discipline.md`: every row is either fix-now or carries an explicit unblock condition.

## Active followups

### A1 — Decision 1: Re-open M19 deferrals (F-D-008, F-D-010, F-D-018)

**Confidence:** HIGH (audit explicit recommendation; user surfaced Teams + Clawpilot wanted)
**Status:** PARTIALLY ADDRESSED — F-D-018 ledger drafted from RESERVED; reopen-request package authored; council-review verdict pending /council-review skill availability (gated on F-205 kit-bootstrap)
**Source:** audit § "Decision 1 — Re-open M19 deferrals"; `M19-deferred/README.md:51-57` re-open protocol
**Unblock condition:** F-205 GREEN → /council-review skill installed → council-review verdict authored at `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`

### A2 — Decision 2: Bootstrap mad-council-claw kit

**Confidence:** HIGH (unblocks every later step)
**Status:** RED — F-205 ledger authored (M0-bootstrap), Bootstrap-CouncilClawKit.ps1 + 3 m-main-derived skills authored in MAD - Clean kit; not yet executed in mad-council-claw
**Source:** audit § "Decision 2 — Bootstrap mad-council-claw kit", "In-project readiness — concrete"
**Unblock condition:** wave-N picks up F-205, runs `tests/node/F-205-kit-bootstrap.test.ts` RED→GREEN, then post-impl council-review for LOCKED transition

### A3 — Decision 3: m-relay-main lift surface ledgers (F-206..F-210)

**Confidence:** HIGH (5 lift-eligible surfaces never tracked pre-2026-05-07)
**Status:** RED — all 5 ledgers authored (F-206 ws-relay-manager, F-207 bot-connector-rest-jwt, F-208 msi-fic-token-mint, F-209 adaptive-card-permission-lifecycle, F-210 conversation-ref-atomic-persist); each soft-blocked on F-205 + F-D-008 reopen
**Source:** audit § "Decision 3", Lane C inventory `agentId a762840e5a17233e0`
**Unblock condition:** F-205 GREEN AND F-D-008 reopen verdict → wave plans schedule F-206..F-210 RED→GREEN

### A4 — m-relay-main reference repo invisibility

**Confidence:** HIGH
**Status:** PARTIALLY ADDRESSED — F-206..F-210 ledgers cite m-relay-main; broader glossary update pending
**Source:** audit § "Gaps from m-main / m-relay-main NOT in plan" (a)
**Unblock condition:** add m-relay-main to `docs/01-requirements/glossary.md` reference-repo list (one-line edit)

### A5 — Validation/testing roadmap gap (no evals/, no metrics/, no CI workflows, no Playwright)

**Confidence:** HIGH (foundational-plan.md:454 calls for evals/ in M-1 bootstrap; never landed)
**Status:** RED — F-127 three-tier-eval-harness flagged "load-bearing per 'evals first' discipline" but no ledger
**Source:** audit § "Validation/testing roadmap gap"
**Unblock condition:** F-127 ledger authored AND wave plans schedule eval-harness scaffold; aligns with F-205 (kit's `prescriptive-content-review.md` Gap 3 + 12 coverage-oracle templates provide scaffolding)

### A6 — Verifications still owed (script presence in MAD - Clean kit)

**Confidence:** MEDIUM (Lane D Glob result truncated; some scripts may be absent)
**Status:** OPEN — referenced in CLAUDE.md / rules but not confirmed on disk
**Source:** audit § "Verifications still owed" — names the 10 scripts in question
**Unblock condition:** before any kit bootstrap run (F-205 execution): `Glob "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/*.ps1"` and either confirm or author missing scripts. Affected: `Check-LoopStopConditions.ps1`, `Validate-CouncilVerdict.ps1`, `Verify-CanonicalSkillFrontmatter.ps1`, `Track-SkillMetrics.ps1`, `Detect-ContentType.ps1`, `Detect-ScopeClaimDrift.ps1`, `Detect-ContractDrift.ps1`, `Pull-ProductionGrounding.ps1`, `Invoke-CopilotMultiModel.ps1`, `Start-InternalMcp.ps1`.

### A7 — `current-wave.md` stale (says wave-11; actual is wave-17/18)

**Confidence:** HIGH
**Status:** ADDRESSED — wave-18 lane-D appended a "wave-history" line naming current lanes; wave-12+ progression noted in out-of-band-steering section
**Source:** audit § "Current wave + active work?"
**Unblock condition:** none (closed by this wave's lane D update)

### A8a — foundational-plan.md missing `## Verification Spec` section (Phase 0.5 plan-gate)

**Confidence:** HIGH (PostToolUse:Edit hook fired during wave-18 lane-D edit)
**Status:** OPEN
**Source:** `verification-spec-completeness` plan-gate warning fired 2026-05-07 against `docs/01-requirements/foundational-plan.md`. Phase 0.5 of the kit's plan-authoring discipline mandates a `## Verification Spec` section enumerating verification criteria. The plan was authored pre-Phase-0.5; the gate landed after.
**Unblock condition:** wave-N spawns a code-implementer (or invokes `/mad-plan` if available post-F-205) to author the missing section against the existing 19-milestone catalog. Out of scope for cleanup waves; needs a dedicated lane.

### A8 — Items the audit explicitly cannot auto-apply (questions for user)

**Confidence:** N/A (open-question class)
**Status:** OPEN — surface to user when other backlog clears
**Source:** audit § "Items I should challenge but cannot auto-apply"
**Items:**
1. **Web UX/UI** — currently NOT in scope (Electron + CLI only). Add `M-Web` milestone or stay Electron-only?
2. **Teams-channel scope beyond F-D-008** — `m-relay-main/manifest.json:28` is `personal`-only. Reuse 1:1 for v1, or aim for team scope from day 1?
3. **`prepare` semantics** — m-main's "Prepare" is the Horizon daily-briefing toggle; user may have meant "fix the prepare section" of council-claw's onboarding, not workspace scaffolding. Which `prepare`?

**Unblock condition:** present at next interview gate (L3) per `foundational-plan.md` § "Aging + escalation"

## Closed followups

(none yet — wave-18 cleanup pass authored this file as the first row of tracked audit followups)

## Cross-references

- Original audit: `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/mad-council-claw-audit-2026-05-07.md` (READ-ONLY)
- Reopen-request package: `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`
- Orchestrator-steering: `docs/11-loop-state/orchestrator-steering-2026-05-07.md`
- F-205 ledger: `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md`
- F-206..F-210 ledgers: `docs/03-feature-catalog/M9-m365/F-{206..210}-*.md`
