# Wave-007 / Lane D — Kit hook fix (mad-council-claw catalog path exemptions)

**Lane:** D (kit-side improvement)
**Repo affected:** `C:/Users/tonym/Repos/MAD - Clean/` (kit) — NOT mad-council-claw source
**Time:** ≤5 min budget; actual ≈4 min
**Confidence:** HIGH
**Source signal:** wave-006 lane-a follow-up + `.claude/rules/no-silent-deferrals.md` MUST clause

## Summary

Extended the kit's `content-scan-deferrals.js` PostToolUse hook to exempt
four mad-council-claw documentation paths from the deferral-keyword scanner.
The wave-2 lane-b ledger template's mandatory `out-of-scope-notes:` block
legitimately references the deferral keywords (per the rule's "preserved
not invented" clause); every parallel catalog-drop wave was tripping the
scanner and blocking SubagentStop until the flag was acknowledged.

## Steps executed

1. Read kit hook source to identify the existing `ALLOWED_FILE_PATTERNS`
   array structure.
2. Added 4 regex patterns covering `docs/03-feature-catalog/**/*.md`,
   `docs/06-agent-team-outputs/**/*.md`, `docs/05-design-reviews/**/*.md`,
   `docs/04-research/**/*.md`. Patterns use `[\\/]` separators for
   cross-platform path matching.
3. Updated `.claude/rules/no-silent-deferrals.md` § Mechanical detection to
   document the new exemptions and explain the "preserved not invented"
   inheritance.
4. Tested the hook with synthetic JSON payloads:
   - 4/4 new exempt paths: hook exits 0, no flag appended.
   - Control test on a non-exempt path: hook still flags correctly with
     all 5 keyword matches and appends to `deferral-flags.json`.
   - Flag-file size unchanged after the exempt-path tests; control test's
     additive flag was reverted by restoring from a pre-test backup.
5. Wrote retro doc to `mad-council-claw/docs/05-design-reviews/retros/`.
6. Wrote this lane summary.

## Outcomes

- **Kit hook modified:** lines added to `ALLOWED_FILE_PATTERNS` array (4
  new regex patterns + a 9-line block comment explaining the rationale and
  citing the MUST clause).
- **Kit rule documentation updated:** exemption list in
  `no-silent-deferrals.md` § Mechanical detection now lists the 4 new path
  patterns and explains why they're exempt.
- **Verification:** synthetic PostToolUse payloads confirmed correct
  exempt/non-exempt behavior (5/5 test cases pass).
- **Backup created and restored:** `deferral-flags.json` sized 169751 bytes
  before and after the test suite — control test's additive flag was
  cleanly reverted by restoring the pre-test backup.

## Anomalies

None encountered. The hook structure already had explicit comments
documenting the pattern for adding new exemptions; the change slotted in
cleanly. Other test fixtures (3 directories) already existed under
`mad-council-claw/docs/`; the test was non-destructive (no real test files
written, only synthetic JSON payloads piped through `node`).

## Commits

- **MAD - Clean repo:** 1 commit (kit hook + rule doc); local-only, NOT
  pushed per non-negotiable rule "YOU MUST NOT run `git push` without
  explicit user request."
- **mad-council-claw repo:** 2 documents (this lane summary + retro
  doc); committed and push status reported in final summary.

## Metrics

- duration: ≈4m
- tool_uses: ≈14 (Read, Edit, Bash for tests, Write for retro/summary)
- tokens: low (mostly small file ops + synthetic JSON tests)
- artifacts: 2 (retro doc + lane summary in mad-council-claw); 2 file
  modifications in kit (hook source + rule doc); 1 kit commit
