# Design decisions pending

Per `foundational-plan.md` — the prior session enumerated D-1..D-8 design decisions awaiting closure. Each requires deliberate review (likely council-review) before implementation work depends on it.

## Schema

```
| ID | Decision | Options under consideration | Source | Date opened | Confidence (HIGH if well-scoped; MEDIUM if depends on research) | Suggested closure path |
```

## Entries (seed from foundational-plan.md)

> NOTE: D-1..D-8 are placeholder slots — the actual decisions to be filled by reviewing the prior session's per-item-review.md and architecture artifacts. Wave 2 / Lane D will surface and refine these.

| ID | Decision | Options | Source | Date opened | Confidence | Suggested closure path |
|---|---|---|---|---|---|---|
| D-1 | Backend SDK provider abstraction shape | (a) thin adapter only, (b) full event normalization layer, (c) opaque pass-through | foundational-plan.md M1 | 2026-05-06 | MEDIUM | council-review at end of wave that drafts F-009..F-013 ledgers |
| D-2 | Where the "soul boundary" enforcement lives | (a) in IBackendProvider, (b) in orchestration plane, (c) in tool plane via permission gates | foundational-plan.md M11 | 2026-05-06 | MEDIUM | council-review during M11 design wave |
| D-3 | MCP tool-cap default value | per-workspace cap of 10 (per WorkIQ tool-explosion lesson); is 10 right? | foundational-plan.md F-125 | 2026-05-06 | MEDIUM | research wave to ground in Microsoft 2026 internal data |
| D-4 | Multi-tier model routing default policy | when does Haiku get used vs Opus? rules-based vs ML-routed? | foundational-plan.md F-124 | 2026-05-06 | LOW | research wave (frontier 2026) before deciding |
| D-5 | Storage encryption: BYOK vs system-managed default | which is the v1 default? | foundational-plan.md M8 | 2026-05-06 | MEDIUM | user input + threat-model review |
| D-6 | Headless CLI subcommand surface | which subcommands are v1 vs deferred? | foundational-plan.md M4 | 2026-05-06 | MEDIUM | catalog wave + user input |
| D-7 | Replay scrubber UI shape | timeline-only vs timeline + diff overlay vs timeline + intervention markers | foundational-plan.md M12 | 2026-05-06 | LOW | UX design wave |
| D-8 | Daily briefing destination(s) | email, Teams DM, OneNote, all three? per-user preference? | foundational-plan.md F-103 | 2026-05-06 | LOW | research wave + user input |

## Confidence rationale

- HIGH would mean the option set is well-defined AND we have evidence enough to pick. None of D-1..D-8 are at HIGH yet.
- MEDIUM = option set is well-defined but evidence is incomplete. Can be promoted to HIGH after a research wave.
- LOW = option set itself isn't yet enumerated. Needs a research wave first.
