# Orchestrator steering — 2026-05-07

**Source:** audit-driven session 967a44fb (cwd=`C:/Users/tonym/Repos/MAD - Clean`) running parallel to the wave-execution session (`64bf21c6`) that has been picking from `current-wave.md` + `implementation-todo.md` and committing through wave-15/16/17.

**Audit synthesis:** `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/mad-council-claw-audit-2026-05-07.md`

This file is the **out-of-band steering channel**: the user works in session 967a44fb and authors backlog updates here; the executing session 64bf21c6 reads this file each iter to learn priorities and unlocks that landed off-wave.

## What's new in the backlog (2026-05-07 silent-deferral surfacing)

Authored across 4 user-scoped batches; all RED + uncommitted-or-recently-committed:

| ID | Slug | Milestone | Priority | Soft-blocks | Why it surfaced |
|---|---|---|---|---|---|
| **F-205** | kit-bootstrap | M0 | **HIGH** | F-206..F-210; M19 reopen verdict | Mechanical "copy MAD kit primitives into mad-council-claw" was assumed by foundational plan ("engine inherits, doesn't fork" — `mad-kit-inventory.md:881`) but never captured as F-NNN. Surfaced per `no-silent-deferrals.md`. |
| F-206 | ws-relay-manager | M9 | high | — (depends-on F-205, F-D-008) | m-relay-main lift (relay.ts:84-235). |
| F-207 | bot-connector-rest-jwt | M9 | high | — | m-relay-main lift (bot.ts:33-321). |
| F-208 | msi-fic-token-mint | M9 | high | — | m-relay-main lift (bot.ts:125-175). |
| F-209 | adaptive-card-permission-lifecycle | M9 | high | — | m-relay-main lift (relay.ts:73-74,95-101,339-418,554-566 + cards.ts:19-93). |
| F-210 | conversation-ref-atomic-persist | M9 | high | — | m-relay-main lift (relay.ts:262-331). |
| F-D-018 | activity-protocol-teams-outlook | M19 | (deferred — REOPEN-PENDING) | — | RESERVED ID, ledger authored from scratch this batch. |

Reopen-request package: `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`. Per `M19-deferred/README.md:51-57`, `status: deferred` stays on F-D-008/F-D-010/F-D-018 until `/council-review` verdict at HIGH ≥80%. Verdict gates on `/council-review` skill availability post-F-205 execution.

## Recommended next-iter pickup order

For the next wave's lane allocation:

1. **F-205 first.** Highest unblock: it enables `/council-review` (which gates the M19 reopen verdict) AND it's the hard `depends-on` for F-206..F-210 transition. Ledger has full implementation directive at `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` § "Implementation directive".
2. **Test authoring for F-205:** `tests/node/F-205-kit-bootstrap.test.ts` per ledger red-green-rule. Should mechanically verify the 8 acceptance items (a)-(h).
3. **/council-review on M19 reopen package** once /council-review is available. If HIGH ≥80%, transitions F-D-008/F-D-010/F-D-018 status from `deferred` → RED, target milestone selected (M9 expansion vs new M-Teams).
4. **F-206..F-210 transitions** unblock once F-205 GREEN AND F-D-008 reopen verdict is HIGH.

## How to execute F-205 (concrete invocation)

```powershell
# Dry-run first (read-only; produces a plan):
pwsh -NoProfile -File "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1" `
  -TargetRepo "C:/Users/tonym/Repos/mad-council-claw" `
  -Tier critical `
  -DryRun

# Review dry-run output. Then execute:
pwsh -NoProfile -File "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1" `
  -TargetRepo "C:/Users/tonym/Repos/mad-council-claw" `
  -Tier critical
```

**Pre-execution checklist** (per F-205 § Implementation directive):
- [ ] No uncommitted drift in `.claude/`, `.mad/`, root `CLAUDE.md` of mad-council-claw (the script writes to these paths)
- [ ] `pwsh` ≥7 available
- [ ] Dry-run output reviewed
- [ ] User notified

**Known dry-run findings** (orchestrator validated 2026-05-07):
- 464 file copies planned
- 32 LENS-prefix files filtered (Ev2-*, Ado-*, Diagnose-LensDcs*, lens-*)
- 1 path-rewrite (KitSourceRoot → TargetRepo in settings.json)
- 1 missing source: `.claude/skills/loop` (Claude Code builtin; script may need patching to either skip or include the bundled path — minor follow-up).

## Three new skills now in MAD-Clean kit (will be copied by F-205 execution)

- `skill-sanitize` — scan user-supplied skill content (frontmatter, descriptions, instructions) for model-specific delimiter tokens and length-cap violations before runtime ingestion. Source: `m-main/common/skill-sanitization.ts`.
- `mcp-permission-validate` — validate MCP server registrations + URLs against allowlist, scheme rules, and threat-model policy before they enter settings.json or runtime ingestion. Source: `m-main/common/permission-servers.ts` + `mcp-url-validation.ts`.
- `copilot-cli-bridge` — canonical wrapper for cross-model dispatch via Copilot CLI; the entry point inheriting skills invoke when running `--copilot` mode (multi-model security/architectural review). Source: `m-main/src/services/copilot.ts` + `lens-multi-model-review-pattern.md`.

## What this file does NOT do

- Does NOT claim a wave for F-205 / F-206..F-210 / reopen-request execution. Wave-claim is the executing session's call.
- Does NOT bypass council-review verdict gate. Reopen package is request-only; verdict gates the actual transition.
- Does NOT pre-empt other lane work. The executing session may have other priorities; this file is a steering input, not a directive.

## Out-of-band steering convention going forward

- 967a44fb session updates this file when it adds new backlog items or wants to surface priorities.
- 64bf21c6 (and successor sessions) read this file at iter start.
- Each entry is dated; readers should consider entries older than 14 days stale unless the underlying ledger is still RED.
