# Manual Grading — author your own verdicts until Phase 2

Bridge between Phase-1 (coordination works) and Phase-2 (Council automates grading). Until `/council-review` + `/council-verdict` land, you author `verdict.json` files by hand following `schemas/verdict.schema.json`.

**Why bother manually?** Three reasons:

1. **Audit trail.** A channel without a verdict has no "we decided X because Y" record. Future-you reading the history loses context.
2. **Calibration seed.** Every hand-authored verdict is training/evaluation data for Phase-2 automation. If the automated Council disagrees with a hand-authored verdict, we have a concrete disagreement to learn from.
3. **Discipline.** Forcing yourself to write `rationale ≥ 20 chars + findings with file:line evidence` is the same habit `wiki/patterns/evidence-beats-assertion.md` asks for. Good practice warms the knife.

---

## When to author a verdict

- Any channel closing during dogfood — write a verdict before `/council-leave`.
- Any feature shipped solo that deserves an "ACCEPT" record.
- Any abandoned work that deserves an "INVESTIGATE" or "ESCALATE" — future-you needs to know this was deliberately parked.

Not every thread needs a verdict. Chat-type threads (`type: fyi`, `type: status`) don't need grading. Task-type threads do.

---

## Required fields

Per `schemas/verdict.schema.json` the minimum shape is:

```json
{
  "thread_id": "<id>",
  "verdict": "FIX | ACCEPT | ESCALATE | INVESTIGATE",
  "issued_utc": "2026-04-18T21:30:00Z",
  "issuer": {
    "alias": "<your-alias>",
    "session_id": "<sess-id>",
    "mode": "manual"
  },
  "rationale": "≥20 chars; why this verdict",
  "roles_run": [
    {
      "role": "advocate",
      "confidence": 0.9,
      "model": "self-review"
    }
  ],
  "findings": [
    {
      "role": "skeptic",
      "severity": "MEDIUM",
      "summary": "short description",
      "evidence": "MAD/scripts/example.ps1:42"
    }
  ],
  "run_id": "<guid>",
  "override_count": 0
}
```

All of these are required by the schema; `Test-Json -Schema` will reject any omission.

## Severity rubric

Match `wiki/patterns/multi-role-review.md §Severity`:

| Severity | When to use |
|---|---|
| **CRITICAL** | Data loss, security regression, breaks other channels. Rare for solo work. |
| **HIGH** | Misleads the implementer (documentation lie), visible user-facing bug, pattern violation that would block merge on a team. |
| **MEDIUM** | Quality / consistency concern; should be fixed but not blocking. |
| **LOW** | Nit, cosmetic. |
| **OBSERVATION** | Not a finding — an observation without file:line evidence. Demoted. |

## Evidence standard

Every finding MUST include evidence: either `file:line` or `file:line-range` or a quoted phrase from a doc. If you can't cite, it's an OBSERVATION, not a finding. Per `wiki/patterns/evidence-beats-assertion.md`.

## Verdict type decision tree

```
Did the work ship with known issues that blockers would catch?  ──► FIX
    │ no
    ▼
Is there a clear outcome (done, merged, shipped) with no blocking issues? ──► ACCEPT
    │ no / unsure
    ▼
Am I confident enough to decide?                                ──► INVESTIGATE
    │ no
    ▼
Beyond my ability to judge (needs legal / security / domain expert) ──► ESCALATE
```

---

## Authoring workflow

1. Pick a channel + thread you want to grade.
2. Open the thread dir: `~/claude-data/channels/<channel>/threads/<thread-id>/`.
3. Decide verdict type.
4. Gather findings — re-read the thread's messages; what HIGH / MEDIUM points stand out?
5. For each finding, add `file:line` evidence pointing at the actual code or doc.
6. Write rationale (≥20 chars; the "why" for the verdict).
7. Generate a run_id: `[guid]::NewGuid().ToString()` in pwsh.
8. Save as `threads/<thread-id>/verdict.json`.
9. Validate:
   ```powershell
   pwsh MAD/scripts/validate-schemas.ps1 -Path ~/claude-data/channels/<channel>/threads/<id>/
   ```
   Expect: `valid=1, invalid=0`.
10. Post a `type: resolve` message to the thread that summarizes the verdict in one line; update thread.json status to `resolved`.

## Example — a "shipped-cleanly ACCEPT"

For the `phase-1b-day1` thread from `mad-self-hosting`:

```json
{
  "thread_id": "phase-1b-day1",
  "verdict": "ACCEPT",
  "issued_utc": "2026-04-18T21:30:00Z",
  "issuer": {
    "alias": "tonym",
    "session_id": "sess-tonym-20260418",
    "mode": "manual"
  },
  "rationale": "Day-1 deliverables shipped cleanly: check-mad-links (6 Pester tests green), validate-schemas (8 tests green), 3 frontmatter fixes, 3 Council stubs. Sandbox warns dropped 4->1. No regressions.",
  "roles_run": [
    { "role": "advocate",  "confidence": 0.9, "model": "self-review" },
    { "role": "architect", "confidence": 0.85, "model": "self-review" }
  ],
  "findings": [
    {
      "role": "skeptic",
      "severity": "OBSERVATION",
      "summary": "StrictMode-sensitive test description (fixed in-iter)",
      "evidence": "MAD/scripts/check-mad-links.Tests.ps1:58",
      "confidence": 0.8
    }
  ],
  "run_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "override_count": 0
}
```

## Example — an "INVESTIGATE" (deferred)

For a thread where you parked the work:

```json
{
  "thread_id": "phase-2-ensemble-harness",
  "verdict": "INVESTIGATE",
  "issued_utc": "2026-04-18T22:00:00Z",
  "issuer": {
    "alias": "tonym",
    "session_id": "sess-tonym-20260418",
    "mode": "manual"
  },
  "rationale": "Phase-2 mock-model harness for 3-role ensemble needs benchmarking against real model runs before committing to the orchestration shape. Not a blocker for Phase-1b, but should not ship until measured.",
  "roles_run": [
    { "role": "architect", "confidence": 0.5, "model": "self-review" }
  ],
  "findings": [
    {
      "role": "architect",
      "severity": "HIGH",
      "summary": "No empirical latency data for parallel 3-role dispatch",
      "evidence": "MAD/skills/council-review/plan.md:47",
      "confidence": 0.7
    }
  ],
  "run_id": "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj",
  "override_count": 0
}
```

---

## Verification that a verdict is schema-valid

```powershell
pwsh MAD/scripts/validate-schemas.ps1 `
  -Path ~/claude-data/channels/mad-self-hosting/threads/phase-1b-day1/
```

Expect output: `validate-schemas: 1 scanned, 1 valid, 0 invalid, 0 skipped.`

Any `invalid` means the verdict.json doesn't match `verdict.schema.json`. Re-read the error, fix, re-run.

---

## When Phase 2 lands

The hand-authored verdicts at `~/claude-data/channels/mad-self-hosting/threads/*/verdict.json` become the golden set. The automated `/council-review` runs against each thread and produces its own verdict. We then compare:

- Same verdict type? → calibration working.
- Different verdict type? → investigate (was my manual verdict wrong, or is the automation overconfident?).
- Finding overlap? → confidence in both human + Council.

This is exactly the `operations/validation-strategy.md §L2c golden-set` pattern. You're seeding the golden set one channel at a time as you dogfood.

---

## Related

- `schemas/verdict.schema.json` — the schema the verdict must match.
- `wiki/patterns/evidence-beats-assertion.md` — file:line evidence discipline.
- `wiki/patterns/multi-role-review.md` — severity rubric + role framing.
- `operations/validation-strategy.md §L2` — where golden-set lives.
- `plans/phase-2-council.md` — when the manual step becomes automated.
