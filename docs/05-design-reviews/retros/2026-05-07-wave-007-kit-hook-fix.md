# Retro — Wave-007 Lane D: kit hook fix for catalog-drop friction

**Date:** 2026-05-07
**Wave:** 007 / Lane D
**Scope:** kit-side improvement (MAD - Clean repo)
**Confidence:** HIGH

## What changed

Extended `.claude/hooks/content-scan-deferrals.js` exemption list in the kit
repo (`C:/Users/tonym/Repos/MAD - Clean/`) to cover four mad-council-claw
documentation paths that legitimately reference the deferral keywords:

- `docs/03-feature-catalog/**/*.md` — wave-2 lane-b ledger drops with
  mandatory `out-of-scope-notes:` blocks
- `docs/06-agent-team-outputs/**/*.md` — per-lane summaries that surface
  prior-wave deferrals as context
- `docs/05-design-reviews/**/*.md` — council and multi-model review outputs
  citing scope decisions verbatim
- `docs/04-research/**/*.md` — wave-1 research findings citing source-doc
  deferrals as documented context

The four regex patterns slot into the existing `ALLOWED_FILE_PATTERNS` array
alongside the existing exemptions for `backlog.md`, `.mad/reports/*.md`,
`.mad/scratch/*.md`, hook source, script source, and the rule files
themselves.

## Why this is the right fix

`.claude/rules/no-silent-deferrals.md` carries an explicit MUST clause: "New
scanning patterns added to the hook MUST also extend the exemption list to
prevent recursive self-trigger." Catalog-drop waves running in parallel
under mad-council-claw inherited the wave-2 lane-b template's mandatory
`out-of-scope-notes:` block; every drop tripped the keyword scanner because
the template's existence pre-dated the hook's awareness of these paths.

The "preserved not invented" clause in the same rule clarifies that
sanctioned, source-document-inherited deferrals are not new silent
deferrals — they're documentation. Treating them as new flags every wave
was a recursive self-trigger pattern, exactly the kind the rule's own
exemption-list discipline is designed to prevent.

## How this improves future catalog drops

Concrete improvements:

1. **No more SubagentStop blocks** on wave-N ledger writes that carry the
   canonical out-of-scope-notes template. Subagents complete cleanly; no
   ack churn.
2. **No more false flags accumulating in `deferral-flags.json`** under the
   kit repo. The flag file now reflects only genuine silent-deferral
   attempts in non-canonical locations.
3. **Concurrent waves can run without contention.** Lanes writing to
   different catalog/output subdirectories no longer have to serialize on
   the flag-file ack workflow.
4. **The pattern is documented and reproducible.** The kit's
   `no-silent-deferrals.md` rule now lists the mad-council-claw paths
   explicitly, so future kit users (or refactors) understand why the
   exemption is there.

## Verification

Hook tested directly with synthetic JSON payloads simulating PostToolUse
invocations:

- All 4 new exempt paths: hook exits 0, no flag appended (4/4 pass).
- Control test on `mad-council-claw/some-random-file.md` outside the
  exempt directories: hook flags correctly with 5 keyword matches and
  appends to `deferral-flags.json` (control passes — exemption is not
  over-broad).
- Flag-file size unchanged after the 4 exempt-path tests
  (169751 bytes before == after).

## Commit

Kit-side fix committed locally to MAD - Clean repo (per non-negotiable
rules: stage and commit, no push without explicit user request). Commit
message references wave-007 / lane-d and cites the rule's own MUST
clause as the authority for the change.

## Related

- `.claude/hooks/content-scan-deferrals.js` (kit repo) — file modified
- `.claude/rules/no-silent-deferrals.md` (kit repo) — exemption list
  documentation updated
- `docs/06-agent-team-outputs/wave-007/lane-d-summary.md` — lane summary
- Prior waves' friction reports: wave-2 through wave-6 lane summaries
  document the recurring symptom this fix resolves
