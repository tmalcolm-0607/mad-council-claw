# 06 — Agent team outputs

Per-wave, per-lane subagent output files. Every wave's lanes commit their findings here. Indexed by wave number.

## Convention

```
docs/06-agent-team-outputs/wave-NNN/
  lane-a-<topic>.md
  lane-b-<topic>.md
  lane-c-<topic>.md
  lane-d-<topic>.md
```

Per Goal G13 (Message 18): "We can spin up many subagent or agent teams for this work each loop. We should never just have a single agent going."

Per Methodology Rule MR1: default 3-4 parallel Task agents per iter on disjoint lanes (per kit's `agent-teams.md`).

Per MR10: findings written to disk per lane (not returned through chat) so orchestrator context stays clean.

## Sub-directories

- `wave-001/` — first wave. Lane Zero = repo bootstrap (this lane). Lanes A-D = research lanes (frontier 2026 / Microsoft 2026 / clawpilot+openclaw / MAD-kit+canonical-e). Lane Zero's report lives at `docs/11-loop-state/wave-history/wave-001-lane-zero.md`; the research lanes' outputs land here.
