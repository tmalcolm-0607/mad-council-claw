# Template — Council verdict.json

Canonical structure for `verdict.json` artifacts written by `/council-review`. The skill writes this file to `<channel-dir>/threads/<thread-id>/verdict.json`.

> **EXAMPLE — replace this when authoring**

```json
{
  "schema_version": 1,
  "thread_id": "<thread-id>",
  "channel": "<channel-name>",
  "verdict": "FIX | ACCEPT | ESCALATE | INVESTIGATE",
  "issued_utc": "2026-05-01T17:30:00Z",
  "issuer_alias": "<orchestrator-alias>",
  "issuer_session_id": "<session-id>",
  "run_id": "<run-id>",
  "mode": "auto | propose",
  "alias_set": "construct | court",
  "ensemble_enabled": false,
  "findings": [
    {
      "id": "finding-1",
      "severity": "CRITICAL | HIGH | MEDIUM | LOW | OBSERVATION",
      "category": "<role-specific category>",
      "evidence": "<file:line or message-id+quote>",
      "title": "<short title>",
      "description": "<full description>",
      "confidence": 0.85,
      "originating_roles": ["Advocate", "Skeptic", "Architect"],
      "demotion": null,
      "annotations": []
    }
  ],
  "role_summaries": {
    "advocate": {"completed": true, "finding_count": 3, "role_confidence": 0.88, "timed_out": false},
    "skeptic": {"completed": true, "finding_count": 5, "role_confidence": 0.78, "timed_out": false},
    "architect": {"completed": true, "finding_count": 2, "role_confidence": 0.84, "timed_out": false}
  },
  "filters_applied": [
    {"name": "YAGNI", "fired_count": 1, "findings_demoted": ["skeptic-03"]},
    {"name": "Pattern-verification", "fired_count": 0, "findings_demoted": []},
    {"name": "FETCH-BEFORE-CITE", "fired_count": 0, "findings_dropped": []}
  ],
  "verdict_reasoning": "<which threshold/trigger fired - 1-3 sentences>",
  "verdict_confidence": 0.85,
  "suggested_next_action": "<e.g. 'fix CRITICAL findings in a follow-up thread' | 'escalate to human' | 'proceed'>"
}
```

## Severity-to-verdict rubric

Per `council-review` Step 8:

| Condition | Verdict |
|-----------|---------|
| ≥1 CRITICAL finding | **FIX** |
| ≥3 HIGH findings | **FIX** |
| Any role role_confidence < 0.5 | eligible for **ESCALATE** |
| 0 CRITICAL, <3 HIGH, ≥1 MEDIUM, all role_confidence ≥ 0.85 | **ACCEPT** |
| 0 CRITICAL, <3 HIGH, ≥1 MEDIUM, some role_confidence 0.5-0.85 | **ACCEPT with caveats** |
| Any role `evidence_incomplete: true` | **INVESTIGATE** |

## Mechanical ESCALATE triggers

- 3 roles disagree on severity of same finding (one CRITICAL, another MEDIUM, another LOW)
- All 3 roles report `role_confidence < 0.5`
- ≥1 role timed out AND remaining roles borderline (confidence 0.5-0.85)
- `--ensemble` enabled AND Skeptic ensemble all-disagree

If multiple conditions: FIX > ESCALATE > INVESTIGATE > ACCEPT.

## Atomic-write requirement

Write to `<thread-dir>/verdict.json.tmp` then `Move-Item -Force` to `<thread-dir>/verdict.json`. Per `rules/concurrency-safety.md` § Atomic write for mutable files.
